"""Execute the OpenTofu-rendered Authentik browser authorization expressions."""

import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import textwrap
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


ADMIN = "pt-pneuma: agentgateway Admins"


class PolicyRequest:
    def __init__(self, user):
        self.user = user
        self.debug = False

    @property
    def should_cache(self):
        return self.user.is_active and not self.debug


class BrowserAccessPolicyTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (Path(__file__).parents[1] / "regional/config/locals.tofu").read_text()
        block = re.search(
            r"  browser_access_policy_expressions = \{.*?\n  \}", source, re.DOTALL,
        )
        if block is None:
            raise AssertionError("Browser access policy expressions are missing")
        bindings = {
            "managed": {"groups": ["all", "operators"], "roles": [ADMIN, "reviewer"]},
            "roles_only": {"groups": [], "roles": [ADMIN]},
            "baseline": {"groups": ["all"], "roles": []},
            "quoted": {"groups": ['group "quoted" & <literal>'], "roles": []},
        }
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "main.tofu").write_text(
                'variable "browser_group_policy_bindings" { type = any }\n'
                "locals {\n" + block.group(0) + "\n}\n"
            )
            result = subprocess.run(
                ["tofu", "console", "-var=browser_group_policy_bindings=" + json.dumps(bindings)],
                input="jsonencode(local.browser_access_policy_expressions)\n",
                cwd=root, capture_output=True, text=True,
            )
            if result.returncode:
                raise AssertionError(result.stdout + result.stderr)
        cls.expressions = json.loads(json.loads(result.stdout))

    def setUp(self):
        self.user = SimpleNamespace(
            is_active=True,
            email="member@example.com",
            attributes={"osinfra_google_email": "member@example.com"},
            ak_groups=Mock(),
        )
        self.connection = Mock()
        self.connection.objects.filter.return_value.exists.return_value = True

    def allows(self, memberships, policy="managed"):
        self.user.ak_groups.values_list.return_value = memberships
        request = PolicyRequest(self.user)
        namespace = {"request": request}
        exec(
            "def evaluate():\n" + textwrap.indent(self.expressions[policy], "    "),
            namespace,
        )
        module = SimpleNamespace(UserOAuthSourceConnection=self.connection)
        with patch.dict(sys.modules, {"authentik.sources.oauth.models": module}):
            result = namespace["evaluate"]()
        self.assertTrue(request.debug)
        self.assertFalse(request.should_cache)
        return result

    def test_or_within_lists_and_and_between_lists(self):
        for memberships, expected in [
            (["all", ADMIN], True),
            (["operators", "reviewer"], True),
            (["all"], False),
            ([ADMIN], False),
            ([], False),
            (["all", ADMIN + " extra"], False),
        ]:
            with self.subTest(memberships=memberships):
                self.assertEqual(self.allows(memberships), expected)

    def test_unlinked_google_identity_cannot_obtain_new_access(self):
        self.assertTrue(self.allows(["all", ADMIN]))
        self.connection.objects.filter.return_value.exists.return_value = False
        self.assertFalse(self.allows(["all", ADMIN]))
        self.connection.objects.filter.assert_called_with(user=self.user, source__slug="google")

    def test_invalid_identity_and_inactive_users_denied(self):
        for attributes, email, active in [
            ({}, "member@example.com", True),
            ({"osinfra_google_email": None}, "member@example.com", True),
            ({"osinfra_google_email": ""}, "", True),
            ({"osinfra_google_email": "member@example.com"}, "other@example.com", True),
            ({"osinfra_google_email": "member@example.com"}, "member@example.com", False),
        ]:
            with self.subTest(attributes=attributes, email=email, active=active):
                self.user.attributes = attributes
                self.user.email = email
                self.user.is_active = active
                self.assertFalse(self.allows(["all", ADMIN]))

    def test_roles_only_and_membership_removal(self):
        self.assertTrue(self.allows([ADMIN], "roles_only"))
        self.assertFalse(self.allows([], "roles_only"))

    def test_baseline_does_not_require_google(self):
        self.user.attributes = {}
        self.connection.objects.filter.return_value.exists.return_value = False
        self.assertTrue(self.allows(["all"], "baseline"))
        self.assertFalse(self.allows([], "baseline"))

    def test_group_names_are_data_not_executable_python(self):
        self.assertTrue(self.allows(['group "quoted" & <literal>'], "quoted"))
        self.assertFalse(self.allows(["all"], "quoted"))


if __name__ == "__main__":
    unittest.main()
