#!/usr/bin/env python3
"""Verify that Android release archives contain required native payloads."""

from __future__ import annotations

import argparse
import zipfile
from pathlib import Path


ABIS = ("arm64-v8a", "armeabi-v7a", "x86_64")
LIBRARIES = ("libapp.so", "libflutter.so", "libsqlite3.so")


def _verify_archive(path: Path, prefix: str) -> None:
    if not path.is_file():
        raise ValueError(f"Artifact does not exist: {path}")

    try:
        with zipfile.ZipFile(path) as archive:
            corrupt_entry = archive.testzip()
            if corrupt_entry is not None:
                raise ValueError(f"{path} contains a corrupt entry: {corrupt_entry}")

            entries = {entry.filename: entry for entry in archive.infolist()}
            required = {
                f"{prefix}{abi}/{library}"
                for abi in ABIS
                for library in LIBRARIES
            }
            missing = sorted(required.difference(entries))
            if missing:
                raise ValueError(
                    f"{path} is missing required native entries: {', '.join(missing)}"
                )

            empty = sorted(name for name in required if entries[name].file_size == 0)
            if empty:
                raise ValueError(
                    f"{path} contains empty native entries: {', '.join(empty)}"
                )
    except zipfile.BadZipFile as error:
        raise ValueError(f"{path} is not a valid ZIP archive") from error


def verify(apk: Path, aab: Path) -> None:
    _verify_archive(apk, "lib/")
    _verify_archive(aab, "base/lib/")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apk", type=Path, required=True)
    parser.add_argument("--aab", type=Path, required=True)
    args = parser.parse_args()

    try:
        verify(args.apk, args.aab)
    except ValueError as error:
        parser.error(str(error))

    print(f"Verified Android artifacts for {len(ABIS)} ABIs: {args.apk}, {args.aab}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
