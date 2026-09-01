#!/usr/bin/env python3
"""Verify that a release tag matches the Flutter application version."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


SEMANTIC_TAG = re.compile(
    r"app-v(?P<version>\d+\.\d+\.\d+(?:-(?:internal|beta)\.\d+)?)"
)
PUBSPEC_VERSION = re.compile(
    r"^version:\s*(?P<version>\d+\.\d+\.\d+(?:-(?:internal|beta)\.\d+)?)\+(?P<build>\d+)\s*$",
    re.MULTILINE,
)


def verify(tag: str, pubspec_text: str) -> tuple[str, int]:
    tag_match = SEMANTIC_TAG.fullmatch(tag)
    if tag_match is None:
        raise ValueError(
            f"Release tag {tag!r} must use app-vMAJOR.MINOR.PATCH, "
            "app-vMAJOR.MINOR.PATCH-internal.N, or app-vMAJOR.MINOR.PATCH-beta.N."
        )

    version_match = PUBSPEC_VERSION.search(pubspec_text)
    if version_match is None:
        raise ValueError(
            "pubspec.yaml must contain version: MAJOR.MINOR.PATCH+BUILD, "
            "MAJOR.MINOR.PATCH-internal.N+BUILD, or MAJOR.MINOR.PATCH-beta.N+BUILD."
        )

    tag_version = tag_match.group("version")
    app_version = version_match.group("version")
    build_number = int(version_match.group("build"))
    if tag_version != app_version:
        raise ValueError(
            f"Tag version {tag_version} does not match pubspec version {app_version}."
        )
    if build_number < 1:
        raise ValueError("The release build number must be a positive integer.")

    return app_version, build_number


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", required=True)
    parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    args = parser.parse_args()

    try:
        version, build = verify(
            args.tag,
            args.pubspec.read_text(encoding="utf-8"),
        )
    except (OSError, ValueError) as error:
        parser.error(str(error))

    print(f"Verified release {args.tag}: version={version}, build={build}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
