"""Verify that only a Google-established identity becomes the authorization header."""

from pathlib import Path
import re
import sys
import textwrap
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


class GoogleProxyMappingTest(unittest.TestCase):
    def setUp(self):
        source = (Path(__file__).parents[1] / "regional/config/locals.tofu").read_text()
        match = re.search(
            r"google_proxy_mapping_expression = <<-EOT\n(.*?)\n  EOT", source, re.DOTALL,
        )
        self.assertIsNotNone(match)
        self.user = SimpleNamespace(
            attributes={"osinfra_google_email": "member@example.com"},
            email="member@example.com",
            is_active=True,
            is_superuser=False,
            group_attributes=lambda request: {
                "additionalHeaders": {
                    "x-authentik-osinfra-google-email": "forged@example.com",
                    "X-AuthEntik-Osinfra-Google-Email": "forged@example.com",
                    "X-authentik-groups": "forged-group",
                    "X-App-Other": "preserved",
                }
            },
        )
        self.connection = Mock()
        self.connection.objects.filter.return_value.exists.return_value = True
        self.namespace = {"request": SimpleNamespace(user=self.user)}
        exec("def mapping():\n" + textwrap.indent(textwrap.dedent(match.group(1)), "    "), self.namespace)

    def mapping(self):
        module = SimpleNamespace(UserOAuthSourceConnection=self.connection)
        with patch.dict(sys.modules, {"authentik.sources.oauth.models": module}):
            return self.namespace["mapping"]()["ak_proxy"]

    def test_only_source_established_header_and_preserved_attributes(self):
        result = self.mapping()
        self.assertEqual(result["user_attributes"]["additionalHeaders"], {
            "X-authentik-osinfra-google-email": "member@example.com",
            "X-App-Other": "preserved",
        })
        self.assertFalse(result["is_superuser"])
        self.connection.objects.filter.assert_called_once_with(
            user=self.user, source__slug="google",
        )

    def test_wrong_source_is_not_a_verified_identity(self):
        self.connection.objects.filter.return_value.exists.return_value = False
        self.assertEqual(self.mapping()["user_attributes"]["additionalHeaders"]["X-authentik-osinfra-google-email"], "")

    def test_missing_marker_changed_email_and_inactive_users_fail_closed(self):
        for attributes, email, active in [
            ({}, "member@example.com", True),
            ({"osinfra_google_email": None}, "member@example.com", True),
            ({"osinfra_google_email": "member@example.com"}, "other@example.com", True),
            ({"osinfra_google_email": "member@example.com"}, "member@example.com", False),
        ]:
            with self.subTest(attributes=attributes, email=email, active=active):
                self.user.attributes = attributes
                self.user.email = email
                self.user.is_active = active
                self.assertEqual(self.mapping()["user_attributes"]["additionalHeaders"]["X-authentik-osinfra-google-email"], "")


if __name__ == "__main__":
    unittest.main()
