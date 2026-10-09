"""Exercise the actual administrator expressions without an Authentik server."""

import json
from pathlib import Path
import re
from textwrap import dedent, indent
from types import SimpleNamespace
import unittest
from unittest.mock import patch


LOCALS = (
    Path(__file__).resolve().parents[1]
    / "regional/config/admins/locals.tofu"
).read_text()
VALUES = {
    "local.attribute_key": "agentgateway-admins-membership",
    "var.configuration.group_name": "agentgateway-admins",
    "var.configuration.google_group": "Pneuma Sandbox Administrators",
    "var.configuration.group_attribute": "groups",
    "lower(var.configuration.email_domain)": "example.com",
}


def expression(name):
    match = re.search(
        rf"  {name} = (?:join[^\n]*\[)?<<-EOT\n(.*?)\n  EOT", LOCALS, re.S
    )
    if match is None:
        raise AssertionError(f"Expression not found: {name}")
    result = dedent(match[1])
    for key, value in VALUES.items():
        result = result.replace("${jsonencode(" + key + ")}", json.dumps(value))
    result = result.replace("${var.configuration.refresh_seconds}", "14400")
    if name == "application_expression":
        result += "\n" + expression("membership_expression")
    if "${" in result:
        raise AssertionError(f"Unresolved interpolation in {name}")
    return result


def evaluate(name, **context):
    namespace = dict(context)
    if "request" in context:
        namespace["http_request"] = context["request"].http_request
    exec("def run():\n" + indent(expression(name), "    "), namespace)
    return namespace["run"]()


def user(member=False, checked_at=1000):
    result = SimpleNamespace(
        email="brett@example.com",
        is_authenticated=True,
        attributes={
            "agentgateway-admins-membership": {
                "member": member,
                "checked_at": checked_at,
            }
        },
    )
    result.ak_groups = SimpleNamespace(
        filter=lambda **query: SimpleNamespace(
            exists=lambda: member and query == {"name": "agentgateway-admins"}
        )
    )
    return result


def request(account=None, path="/outpost.goauthentik.io/auth/envoy", grant=None):
    account = account or user()
    return SimpleNamespace(
        user=account,
        http_request=SimpleNamespace(path=path, user=account),
        context={} if grant is None else {"oauth_grant_type": grant},
    )


class AdminExpressionsTest(unittest.TestCase):
    def test_first_oauth_login_can_reach_source_stage(self):
        self.assertTrue(
            evaluate(
                "application_expression",
                request=request(path="/application/o/authorize/", grant="authorization_code"),
            )
        )
        self.assertFalse(evaluate("application_expression", request=request()))

    @patch("time.time", return_value=1100)
    def test_post_source_denies_nonmembers_and_accepts_members(self, _clock):
        self.assertTrue(evaluate("nonmember_expression", request=request(user(False))))
        self.assertFalse(evaluate("nonmember_expression", request=request(user(True))))

    @patch("time.time", return_value=15400)
    def test_exact_four_hour_boundary_denies(self, _clock):
        self.assertFalse(evaluate("membership_expression", request=request(user(True))))
        self.assertTrue(evaluate("nonmember_expression", request=request(user(True))))

    @patch("time.time", return_value=1100)
    def test_noninteractive_grants_are_denied(self, _clock):
        for grant in ("password", "client_credentials", "refresh_token"):
            self.assertFalse(
                evaluate(
                    "application_expression",
                    request=request(user(True), "/application/o/token/", grant),
                )
            )

    @patch("time.time", return_value=1100)
    def test_google_group_is_allowlisted_and_baseline_membership_is_not_replaced(self, _clock):
        properties = {
            "email": "brett@example.com",
            "groups": ["Pneuma Sandbox Administrators", "authentik Admins", "all"],
        }
        result = evaluate(
            "source_expression",
            request=request(),
            properties=properties,
        )
        self.assertEqual(properties["groups"], [])
        self.assertEqual(result["groups"], ["agentgateway-admins"])
        self.assertTrue(result["attributes"]["agentgateway-admins-membership"]["member"])

    def test_wrong_environment_group_does_not_grant_access(self):
        result = evaluate(
            "source_expression",
            request=request(),
            properties={"email": "brett@example.com", "groups": ["Pneuma Production Administrators"]},
        )
        self.assertEqual(result["groups"], [])
        self.assertFalse(result["attributes"]["agentgateway-admins-membership"]["member"])

    def test_missing_group_removes_source_owned_membership(self):
        result = evaluate(
            "source_expression",
            request=request(user(True)),
            properties={"email": "brett@example.com"},
        )
        self.assertEqual(result["groups"], [])
        self.assertFalse(result["attributes"]["agentgateway-admins-membership"]["member"])

    def test_mismatched_identity_and_invalid_attributes_raise(self):
        for properties in (
            {"email": "other@example.com"},
            {"email": "brett@external.example"},
            {"email": ["brett@example.com"]},
            {"email": "brett@example.com", "groups": [{"name": "Pneuma Sandbox Administrators"}]},
        ):
            with self.assertRaises(ValueError):
                evaluate("source_expression", request=request(), properties=properties)

    def test_delayed_consent_does_not_extend_absolute_expiry(self):
        token = SimpleNamespace(
            user=user(True),
            expires=SimpleNamespace(timestamp=lambda: 20000),
        )
        self.assertEqual(evaluate("expiry_expression", token=token), {"exp": 15400})
        token.expires = SimpleNamespace(timestamp=lambda: 12000)
        self.assertEqual(evaluate("expiry_expression", token=token), {"exp": 12000})

    def test_missing_membership_expires_immediately(self):
        token = SimpleNamespace(user=user(False))
        self.assertEqual(evaluate("expiry_expression", token=token), {"exp": 0})
        token.user.attributes["agentgateway-admins-membership"] = None
        self.assertEqual(evaluate("expiry_expression", token=token), {"exp": 0})


if __name__ == "__main__":
    unittest.main()
