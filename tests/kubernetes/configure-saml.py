#!/usr/bin/env python3
"""Prepare public Google SAML trust inputs for the local fixture."""

import argparse
import base64
import json
from pathlib import Path
import subprocess
from xml.etree import ElementTree


def configuration(metadata_path, google_group, refresh_seconds):
    raw = metadata_path.read_bytes()
    if b"<!DOCTYPE" in raw.upper() or b"<!ENTITY" in raw.upper():
        raise ValueError("SAML metadata must not contain XML document types or entities")
    root = ElementTree.fromstring(raw)
    namespaces = {
        "md": "urn:oasis:names:tc:SAML:2.0:metadata",
        "ds": "http://www.w3.org/2000/09/xmldsig#",
    }
    if root.tag != "{urn:oasis:names:tc:SAML:2.0:metadata}EntityDescriptor":
        raise ValueError("Expected one Google IdP EntityDescriptor")
    entity_id = root.get("entityID", "")
    services = root.findall(
        "./md:IDPSSODescriptor/md:SingleSignOnService", namespaces
    )
    urls = [
        service.get("Location", "")
        for service in services
        if service.get("Binding") == "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
    ]
    certificates = root.findall(
        "./md:IDPSSODescriptor/md:KeyDescriptor[@use='signing']"
        "/ds:KeyInfo/ds:X509Data/ds:X509Certificate",
        namespaces,
    )
    if len(urls) != 1 or len(certificates) != 1:
        raise ValueError("Expected one Redirect SSO endpoint and one signing certificate")
    if not entity_id.startswith("https://accounts.google.com/") or not urls[0].startswith(
        "https://accounts.google.com/"
    ):
        raise ValueError("Only Google accounts IdP metadata is supported")
    if not google_group.strip() or not 300 <= refresh_seconds <= 14400:
        raise ValueError("Supply a group name and refresh interval between 300 and 14400 seconds")
    der = base64.b64decode("".join((certificates[0].text or "").split()), validate=True)
    pem = subprocess.run(
        ["openssl", "x509", "-inform", "DER", "-outform", "PEM"],
        input=der, capture_output=True, check=True,
    ).stdout.decode("ascii")
    subprocess.run(
        ["openssl", "x509", "-noout", "-checkend", "0"],
        input=pem.encode("ascii"), capture_output=True, check=True,
    )
    return {
        "admin_saml": {
            "email_domain": "osinfra.io",
            "google_group": google_group.strip(),
            "group_attribute": "groups",
            "idp_entity_id": entity_id,
            "refresh_seconds": refresh_seconds,
            "signing_certificate": pem,
            "sso_url": urls[0],
        }
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("metadata", type=Path)
    parser.add_argument("--group", required=True)
    parser.add_argument("--refresh-seconds", type=int, default=14400)
    args = parser.parse_args()
    values = configuration(args.metadata, args.group, args.refresh_seconds)
    output = Path(__file__).resolve().parent / ".work/config/admin-saml.tfvars.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(values, indent=2) + "\n")
    output.chmod(0o600)
    print(f"Prepared public SAML trust in {output}")
    print("This does not apply configuration. Enable the Google app and local Enterprise license before setup.")


if __name__ == "__main__":
    main()
