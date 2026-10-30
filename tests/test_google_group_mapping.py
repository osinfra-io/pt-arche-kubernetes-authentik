"""Exercise the checked-out Google property mapping without OAuth credentials."""

import json
from pathlib import Path
import re
import textwrap
import unittest


class GoogleGroupMappingTest(unittest.TestCase):
    def setUp(self):
        source = (
            Path(__file__).parents[1] / "regional/config/locals.tofu"
        ).read_text()
        match = re.search(
            r"google_group_mapping_expression = <<-EOT\n(.*?)\n  EOT",
            source,
            re.DOTALL,
        )
        self.assertIsNotNone(match)
        groups = {
            "pt-pneuma-agentgateway-admins": {
                "name": "pt-pneuma: agentgateway Admins",
                "members": ["member@example.com"],
                "description": "UI access",
            }
        }
        expression = textwrap.dedent(match.group(1)).replace(
            "${jsonencode(jsonencode(var.application_groups))}",
            json.dumps(json.dumps(groups)),
        )
        namespace = {}
        exec("def mapping(info):\n" + textwrap.indent(expression, "    "), namespace)
        self.mapping = namespace["mapping"]

    def test_verified_member(self):
        result = self.mapping(
            {"email": "member@example.com", "email_verified": True}
        )
        self.assertEqual(result["groups"], ["pt-pneuma: agentgateway Admins"])
        self.assertEqual(result["attributes"]["osinfra_google_email"], "member@example.com")

    def test_normalized_member(self):
        result = self.mapping(
            {"email": "MEMBER@example.com", "email_verified": True}
        )
        self.assertEqual(result["groups"], ["pt-pneuma: agentgateway Admins"])
        self.assertEqual(result["email"], "member@example.com")
        self.assertEqual(result["attributes"]["osinfra_google_email"], result["email"])

    def test_google_native_userinfo_verification(self):
        result = self.mapping(
            {"email": "member@example.com", "verified_email": True}
        )
        self.assertEqual(result["groups"], ["pt-pneuma: agentgateway Admins"])

    def test_nonmember_cannot_supply_groups(self):
        result = self.mapping(
            {
                "email": "other@example.com",
                "email_verified": True,
                "groups": ["pt-pneuma: agentgateway Admins"],
            }
        )
        self.assertEqual(result["groups"], [])

    def test_consistent_verification_fields(self):
        result = self.mapping(
            {"email": "member@example.com", "email_verified": True, "verified_email": True}
        )
        self.assertEqual(result["groups"], ["pt-pneuma: agentgateway Admins"])

    def test_unverified_identity_fails(self):
        for info in [
            {"email": "member@example.com"},
            {"email": "member@example.com", "email_verified": False},
            {"email": "member@example.com", "email_verified": "true"},
            {"email": "member@example.com", "verified_email": False},
            {"email": "member@example.com", "verified_email": "true"},
            {"email": "member@example.com", "email_verified": False, "verified_email": True},
            {"email": "member@example.com", "email_verified": True, "verified_email": False},
            {"email": "member@example.com", "email_verified": True, "verified_email": "true"},
            {"email": "member@example.com", "email_verified": 1},
            {"email": "member@example.com", "verified_email": 1},
            {"email": "", "email_verified": True},
            {"email": None, "email_verified": True},
        ]:
            with self.subTest(info=info), self.assertRaises(ValueError):
                self.mapping(info)


class GoogleIdentityMappingTest(unittest.TestCase):
    def mapping(self, info, domains=("osinfra.io",)):
        source = (Path(__file__).parents[1] / "regional/config/locals.tofu").read_text()
        match = re.search(
            r"google_identity_mapping_expression = <<-EOT\n(.*?)\n  EOT",
            source,
            re.DOTALL,
        )
        self.assertIsNotNone(match)
        expression = textwrap.dedent(match.group(1)).replace(
            "${jsonencode(jsonencode(var.google_internal_domains))}",
            json.dumps(json.dumps(list(domains))),
        )
        namespace = {}
        exec("def mapping(info):\n" + textwrap.indent(expression, "    "), namespace)
        return namespace["mapping"](info)

    def test_verified_workspace_members_are_internal(self):
        for verification in ("verified_email", "email_verified"):
            with self.subTest(verification=verification):
                result = self.mapping({
                    "email": "member@osinfra.io", "hd": "osinfra.io", verification: True,
                })
                self.assertEqual(result, {"username": "member@osinfra.io", "type": "internal"})

    def test_other_or_unverified_accounts_remain_external(self):
        for info in [
            {"email": "member@osinfra.io", "verified_email": True},
            {"email": "member@osinfra.io", "hd": "osinfra.io"},
            {"email": "member@osinfra.io", "hd": "osinfra.io", "verified_email": "true"},
            {"email": "member@osinfra.io", "hd": "osinfra.io", "verified_email": 1},
            {"email": "member@osinfra.io", "hd": "osinfra.io", "email_verified": True, "verified_email": False},
            {"email": "member@example.com", "hd": "example.com", "verified_email": True},
            {"email": "member@example.com", "hd": "osinfra.io", "verified_email": True},
            {"email": "member@osinfra.io.attacker.example", "hd": "osinfra.io", "verified_email": True},
            {"email": None, "hd": "osinfra.io", "verified_email": True},
        ]:
            with self.subTest(info=info):
                self.assertEqual(self.mapping(info)["type"], "external")

    def test_no_domains_grants_no_internal_access(self):
        result = self.mapping(
            {"email": "member@osinfra.io", "hd": "osinfra.io", "verified_email": True},
            domains=(),
        )
        self.assertEqual(result["type"], "external")


if __name__ == "__main__":
    unittest.main()
