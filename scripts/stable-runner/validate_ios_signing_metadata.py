#!/usr/bin/env python3
"""Fail-closed checks for private iOS distribution-signing metadata paths."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import stat
import sys
import uuid
from pathlib import Path


class ValidationError(Exception):
    pass


def is_within(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def resolved_home_root(home: Path, relative: str) -> Path:
    relative_path = Path(relative)
    if relative_path.is_absolute() or ".." in relative_path.parts:
        raise ValidationError
    candidate = home / relative_path
    current = home
    for component in relative_path.parts:
        current = current / component
        if current.is_symlink():
            raise ValidationError
    try:
        resolved = candidate.resolve(strict=True)
    except OSError as error:
        raise ValidationError from error
    if resolved != candidate or not resolved.is_dir() or not is_within(resolved, home):
        raise ValidationError
    return resolved


def confined_regular_file(value: object, roots: list[Path], *, mode: int | None = None) -> Path:
    if not isinstance(value, str) or not value:
        raise ValidationError
    candidate = Path(value)
    if not candidate.is_absolute() or ".." in candidate.parts or candidate.is_symlink():
        raise ValidationError
    try:
        resolved = candidate.resolve(strict=True)
        info = resolved.stat()
    except OSError as error:
        raise ValidationError from error
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
        raise ValidationError
    if mode is not None and stat.S_IMODE(info.st_mode) != mode:
        raise ValidationError
    if not any(is_within(resolved, root) for root in roots):
        raise ValidationError
    return resolved


def future_date(value: object) -> bool:
    if not isinstance(value, str) or not value:
        return False
    try:
        expiration = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return expiration.tzinfo is not None and expiration > dt.datetime.now(dt.timezone.utc)


def validate(metadata_relative: str, bundle_id: str, platform: str) -> None:
    home = Path.home().resolve(strict=True)
    relative = Path(metadata_relative)
    if relative.is_absolute() or not relative.parts or ".." in relative.parts:
        raise ValidationError

    metadata_root = resolved_home_root(home, ".codex/release-runners")
    keychain_root = resolved_home_root(home, "Library/Keychains")
    password_roots = [
        resolved_home_root(home, ".codex/release-runners"),
        resolved_home_root(home, ".codex/secrets"),
    ]
    metadata_file = confined_regular_file(
        str(home / relative), [metadata_root], mode=0o600
    )

    try:
        metadata = json.loads(metadata_file.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValidationError from error
    if not isinstance(metadata, dict):
        raise ValidationError

    platforms = metadata.get("platforms")
    signing = platforms.get(platform) if isinstance(platforms, dict) else None
    if signing is None or signing is False:
        signing = metadata
    if not isinstance(signing, dict):
        raise ValidationError

    if not isinstance(signing.get("certificateId"), str) or not signing["certificateId"]:
        raise ValidationError
    if signing.get("certificateType") != "DISTRIBUTION":
        raise ValidationError
    if not future_date(signing.get("certificateExpirationDate")):
        raise ValidationError

    profiles = signing.get("profiles")
    profile = profiles.get(bundle_id) if isinstance(profiles, dict) else None
    if not isinstance(profile, dict):
        raise ValidationError
    if not isinstance(profile.get("profileId"), str) or not profile["profileId"]:
        raise ValidationError
    if not isinstance(profile.get("profileName"), str) or not profile["profileName"]:
        raise ValidationError
    profile_uuid = profile.get("profileUuid")
    if not isinstance(profile_uuid, str) or not re.fullmatch(r"[0-9a-fA-F-]{36}", profile_uuid):
        raise ValidationError
    try:
        uuid.UUID(profile_uuid)
    except ValueError as error:
        raise ValidationError from error
    if profile.get("profileType") != "IOS_APP_STORE" or profile.get("profileState") != "ACTIVE":
        raise ValidationError
    if not future_date(profile.get("profileExpirationDate")):
        raise ValidationError

    confined_regular_file(metadata.get("keychainPath"), [keychain_root])
    confined_regular_file(metadata.get("passwordFile"), password_roots, mode=0o600)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--metadata-relative", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--platform", choices=("iOS",), required=True)
    args = parser.parse_args()
    try:
        validate(args.metadata_relative, args.bundle_id, args.platform)
    except ValidationError:
        print("signing metadata validation failed", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
