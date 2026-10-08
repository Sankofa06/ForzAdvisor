#!/usr/bin/env python3
"""Validate an already-decoded App Store provisioning profile without disclosing selectors."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import plistlib
import sys
from pathlib import Path


class ProfileError(Exception):
    pass


def inspect_profile(
    path: Path,
    *,
    bundle_id: str,
    team_id: str,
    profile_uuid: str,
    profile_name: str,
    certificate_sha1: str | None = None,
) -> list[str]:
    try:
        with path.open("rb") as stream:
            profile = plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException, ValueError) as exc:
        raise ProfileError from exc

    entitlements = profile.get("Entitlements")
    if not isinstance(entitlements, dict):
        raise ProfileError
    if profile.get("UUID") != profile_uuid or profile.get("Name") != profile_name:
        raise ProfileError
    if "iOS" not in profile.get("Platform", []):
        raise ProfileError
    if team_id not in profile.get("TeamIdentifier", []):
        raise ProfileError
    if team_id not in profile.get("ApplicationIdentifierPrefix", []):
        raise ProfileError
    if entitlements.get("application-identifier") != f"{team_id}.{bundle_id}":
        raise ProfileError
    if entitlements.get("com.apple.developer.team-identifier") != team_id:
        raise ProfileError
    if entitlements.get("get-task-allow") is not False:
        raise ProfileError
    if entitlements.get("beta-reports-active") is not True:
        raise ProfileError
    if profile.get("ProvisionedDevices"):
        raise ProfileError
    if profile.get("ProvisionsAllDevices") is True:
        raise ProfileError

    expires = profile.get("ExpirationDate")
    if not isinstance(expires, dt.datetime):
        raise ProfileError
    if expires.tzinfo is None:
        expires = expires.replace(tzinfo=dt.timezone.utc)
    if expires <= dt.datetime.now(dt.timezone.utc):
        raise ProfileError

    certificates = profile.get("DeveloperCertificates")
    if not isinstance(certificates, list) or not certificates:
        raise ProfileError
    if not all(isinstance(cert, bytes) and cert for cert in certificates):
        raise ProfileError
    fingerprints = sorted({hashlib.sha1(cert).hexdigest().upper() for cert in certificates})
    if certificate_sha1 and certificate_sha1.upper() not in fingerprints:
        raise ProfileError
    return fingerprints


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--profile", required=True, type=Path)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--team-id", required=True)
    parser.add_argument("--profile-uuid", required=True)
    parser.add_argument("--profile-name", required=True)
    parser.add_argument("--certificate-sha1")
    parser.add_argument("--print-certificate-sha1s", action="store_true")
    args = parser.parse_args()

    try:
        fingerprints = inspect_profile(
            args.profile,
            bundle_id=args.bundle_id,
            team_id=args.team_id,
            profile_uuid=args.profile_uuid,
            profile_name=args.profile_name,
            certificate_sha1=args.certificate_sha1,
        )
    except ProfileError:
        print("profile verification failed", file=sys.stderr)
        return 2

    if args.print_certificate_sha1s:
        print(json.dumps(fingerprints, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
