"""Test the local public-metadata preparation helper."""

import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch


SPEC = importlib.util.spec_from_file_location(
    "configure_saml", Path(__file__).parent / "kubernetes/configure-saml.py"
)
HELPER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(HELPER)
METADATA = """<EntityDescriptor xmlns="urn:oasis:names:tc:SAML:2.0:metadata"
entityID="https://accounts.google.com/o/saml2?idpid=test">
<IDPSSODescriptor>
<KeyDescriptor use="signing"><KeyInfo xmlns="http://www.w3.org/2000/09/xmldsig#">
<X509Data><X509Certificate>dGVzdA==</X509Certificate></X509Data>
</KeyInfo></KeyDescriptor>
<SingleSignOnService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
Location="https://accounts.google.com/o/saml2/idp?idpid=test"/>
</IDPSSODescriptor></EntityDescriptor>"""


class LocalSamlMetadataTest(unittest.TestCase):
    def prepare(self, text, **kwargs):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "metadata.xml"
            path.write_text(text)
            return HELPER.configuration(path, "Sandbox Administrators", kwargs.get("interval", 300))

    @patch.object(HELPER.subprocess, "run")
    def test_google_metadata_produces_local_trust(self, run):
        run.return_value.stdout = b"-----BEGIN CERTIFICATE-----\ntest\n-----END CERTIFICATE-----\n"
        values = self.prepare(METADATA)["admin_saml"]
        self.assertEqual(values["google_group"], "Sandbox Administrators")
        self.assertEqual(values["refresh_seconds"], 300)
        self.assertEqual(values["group_attribute"], "groups")
        self.assertEqual(run.call_count, 2)
        self.assertTrue(all(call.kwargs["check"] for call in run.call_args_list))

    def test_untrusted_or_ambiguous_metadata_is_rejected(self):
        for text in (
            METADATA.replace("accounts.google.com", "attacker.example"),
            METADATA.replace('use="signing"', 'use="encryption"'),
            "<!DOCTYPE x>" + METADATA,
            METADATA.replace("dGVzdA==", "invalid!"),
        ):
            with self.subTest(text=text):
                with self.assertRaises(ValueError):
                    self.prepare(text)

    def test_out_of_bounds_interval_is_rejected(self):
        for interval in (299, 14401):
            with self.assertRaises(ValueError):
                self.prepare(METADATA, interval=interval)


if __name__ == "__main__":
    unittest.main()
