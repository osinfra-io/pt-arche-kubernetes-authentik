"""Exercise the actual administrator expressions without an Authentik server."""

from datetime import datetime, timezone
import json
from pathlib import Path
import re
import time
from textwrap import dedent, indent
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from xml.etree import ElementTree


LOCALS = (
    Path(__file__).resolve().parents[1]
    / "regional/config/admins/locals.tofu"
).read_text()
VALUES = {
    "local.attribute_key": "agentgateway-admins-membership",
    "var.configuration.group_name": "agentgateway-admins",
    "var.configuration.google_group": "Pneuma Sandbox Administrators",
    "var.configuration.group_attribute": "groups",
    "var.configuration.idp_entity_id": "https://accounts.google.com/o/saml2?idpid=test",
    "lower(var.configuration.email_domain)": "example.com",
    "local.source_acs_url": "https://authentik.example.com/source/saml/agentgateway-admins/acs/",
    "local.source_entity_id": "https://authentik.example.com/source/saml/agentgateway-admins/metadata/",
}
NS = "{urn:oasis:names:tc:SAML:2.0:assertion}"


def saml_context():
    instant = datetime.fromtimestamp(time.time() - 1, timezone.utc).isoformat()
    expiry = datetime.fromtimestamp(time.time() + 300, timezone.utc).isoformat()
    root = ElementTree.Element(
        "{urn:oasis:names:tc:SAML:2.0:protocol}Response",
        Destination=VALUES["local.source_acs_url"],
        InResponseTo="request-id",
    )
    ElementTree.SubElement(root, NS + "Issuer").text = VALUES["var.configuration.idp_entity_id"]
    assertion = ElementTree.SubElement(root, NS + "Assertion", IssueInstant=instant)
    ElementTree.SubElement(assertion, NS + "Issuer").text = VALUES["var.configuration.idp_entity_id"]
    conditions = ElementTree.SubElement(assertion, NS + "Conditions", NotOnOrAfter=expiry)
    restriction = ElementTree.SubElement(conditions, NS + "AudienceRestriction")
    ElementTree.SubElement(restriction, NS + "Audience").text = VALUES["local.source_entity_id"]
    subject = ElementTree.SubElement(assertion, NS + "Subject")
    confirmation = ElementTree.SubElement(
        subject, NS + "SubjectConfirmation", Method="urn:oasis:names:tc:SAML:2.0:cm:bearer"
    )
    ElementTree.SubElement(
        confirmation,
        NS + "SubjectConfirmationData",
        Recipient=VALUES["local.source_acs_url"],
        InResponseTo="request-id",
        NotOnOrAfter=expiry,
    )
    return {"root": root, "assertion": assertion}


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
    if name == "source_expression" and "assertion" not in context:
        context.update(saml_context())
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

    def test_wrong_environment_audience_is_rejected(self):
        context = saml_context()
        context["assertion"].find(NS + "Conditions/" + NS + "AudienceRestriction/" + NS + "Audience").text = "https://another-environment.example/metadata/"
        with self.assertRaisesRegex(ValueError, "audience"):
            evaluate("source_expression", request=request(), properties={"email": "brett@example.com"}, **context)

    def test_wrong_issuer_destination_and_recipient_are_rejected(self):
        for target in ("issuer", "destination", "recipient", "request-id"):
            with self.subTest(target=target):
                context = saml_context()
                if target == "issuer":
                    context["assertion"].find(NS + "Issuer").text = "https://other-idp.example"
                elif target == "destination":
                    context["root"].set("Destination", "https://other-source.example/acs/")
                else:
                    data = context["assertion"].find(NS + "Subject/" + NS + "SubjectConfirmation/" + NS + "SubjectConfirmationData")
                    data.set("Recipient" if target == "recipient" else "InResponseTo", "wrong")
                with self.assertRaises(ValueError):
                    evaluate("source_expression", request=request(), properties={"email": "brett@example.com"}, **context)

    def test_missing_audience_and_multiple_assertions_are_rejected(self):
        for target in ("audience", "assertions"):
            with self.subTest(target=target):
                context = saml_context()
                if target == "audience":
                    conditions = context["assertion"].find(NS + "Conditions")
                    conditions.remove(conditions.find(NS + "AudienceRestriction"))
                else:
                    ElementTree.SubElement(context["root"], NS + "Assertion")
                with self.assertRaises(ValueError):
                    evaluate("source_expression", request=request(), properties={"email": "brett@example.com"}, **context)

    @patch("time.time", return_value=1100)
    def test_membership_timestamp_uses_assertion_issuance(self, _clock):
        context = saml_context()
        context["assertion"].set("IssueInstant", datetime.fromtimestamp(1000, timezone.utc).isoformat())
        result = evaluate(
            "source_expression",
            request=request(),
            properties={"email": "brett@example.com", "groups": ["Pneuma Sandbox Administrators"]},
            **context,
        )
        self.assertEqual(result["attributes"]["agentgateway-admins-membership"]["checked_at"], 1000)

    @patch("time.time", return_value=15400)
    def test_delayed_assertion_cannot_restart_freshness(self, _clock):
        context = saml_context()
        context["assertion"].set("IssueInstant", datetime.fromtimestamp(1000, timezone.utc).isoformat())
        with self.assertRaisesRegex(ValueError, "freshness"):
            evaluate("source_expression", request=request(), properties={"email": "brett@example.com"}, **context)

    def test_expired_and_timezone_free_confirmations_are_rejected(self):
        for expiry in ("1970-01-01T00:00:00+00:00", "2100-01-01T00:00:00"):
            with self.subTest(expiry=expiry):
                context = saml_context()
                data = context["assertion"].find(NS + "Subject/" + NS + "SubjectConfirmation/" + NS + "SubjectConfirmationData")
                data.set("NotOnOrAfter", expiry)
                with self.assertRaises(ValueError):
                    evaluate("source_expression", request=request(), properties={"email": "brett@example.com"}, **context)


if __name__ == "__main__":
    unittest.main()
