#!/usr/bin/env python3
from __future__ import annotations

import datetime as dt
import hashlib
import plistlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VERIFIER = ROOT / "scripts" / "stable-runner" / "verify_ios_profile.py"
BUNDLE = "example.product"
TEAM = "A1B2C3D4E5"
UUID = "11111111-2222-3333-4444-555555555555"
NAME = "Fixture App Store Profile"
CERT = b"fixture-only certificate bytes"
FINGERPRINT = hashlib.sha1(CERT).hexdigest().upper()


def fixture(**changes):
    profile = {
        "UUID": UUID,
        "Name": NAME,
        "Platform": ["iOS"],
        "TeamIdentifier": [TEAM],
        "ApplicationIdentifierPrefix": [TEAM],
        "ExpirationDate": dt.datetime.now(dt.timezone.utc) + dt.timedelta(days=30),
        "ProvisionedDevices": [],
        "ProvisionsAllDevices": False,
        "Entitlements": {
            "application-identifier": f"{TEAM}.{BUNDLE}",
            "com.apple.developer.team-identifier": TEAM,
            "get-task-allow": False,
            "beta-reports-active": True,
        },
        "DeveloperCertificates": [CERT],
    }
    profile.update(changes)
    return profile


class ProvisioningProfileVerifierTests(unittest.TestCase):
    def run_profile(self, profile, *extra):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "profile.plist"
            path.write_bytes(plistlib.dumps(profile))
            return subprocess.run(
                [
                    sys.executable,
                    str(VERIFIER),
                    "--profile",
                    str(path),
                    "--bundle-id",
                    BUNDLE,
                    "--team-id",
                    TEAM,
                    "--profile-uuid",
                    UUID,
                    "--profile-name",
                    NAME,
                    *extra,
                ],
                capture_output=True,
                text=True,
                check=False,
            )

    def test_accepts_matching_app_store_profile_and_returns_only_certificate_hashes(self):
        result = self.run_profile(fixture(), "--print-certificate-sha1s")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), f'["{FINGERPRINT}"]')

    def test_rejects_wrong_bundle_and_team_entitlements(self):
        profile = fixture()
        profile["Entitlements"]["application-identifier"] = f"{TEAM}.other.product"
        self.assertNotEqual(self.run_profile(profile).returncode, 0)

    def test_rejects_development_and_enterprise_profiles(self):
        development = fixture()
        development["Entitlements"]["get-task-allow"] = True
        self.assertNotEqual(self.run_profile(development).returncode, 0)
        enterprise = fixture()
        enterprise["ProvisionsAllDevices"] = True
        self.assertNotEqual(self.run_profile(enterprise).returncode, 0)

    def test_rejects_expired_profile_and_wrong_selected_certificate(self):
        expired = fixture()
        expired["ExpirationDate"] = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=1)
        self.assertNotEqual(self.run_profile(expired).returncode, 0)
        mismatch = self.run_profile(fixture(), "--certificate-sha1", "0" * 40)
        self.assertNotEqual(mismatch.returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
