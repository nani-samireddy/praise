#!/usr/bin/env python3
"""Validate generated GitHub Pages catalogue artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--catalog", type=Path, default=Path("docs/catalog"), help="Catalogue folder"
    )
    return parser.parse_args()


def required_text(song: object, key: str, index: int) -> str:
    if not isinstance(song, dict):
        raise ValueError(f"Song {index} is not an object")
    value = song.get(key)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"Song {index} has invalid {key}")
    return value.strip()


def main() -> None:
    folder = parse_args().catalog
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
    songs_data = (folder / "songs.json").read_bytes()
    songs = json.loads(songs_data.decode("utf-8"))

    if manifest.get("schemaVersion") != 1:
        raise ValueError("Unsupported schemaVersion")
    if not isinstance(manifest.get("catalogVersion"), int) or manifest["catalogVersion"] < 1:
        raise ValueError("catalogVersion must be a positive integer")
    if manifest.get("catalogUrl") != "songs.json":
        raise ValueError("catalogUrl must be songs.json")
    checksum = hashlib.sha256(songs_data).hexdigest()
    if manifest.get("sha256") != checksum or not re.fullmatch(r"[0-9a-f]{64}", checksum):
        raise ValueError("Catalogue checksum mismatch")
    if not isinstance(songs, list) or manifest.get("songCount") != len(songs):
        raise ValueError("Catalogue song count mismatch")

    ids: set[str] = set()
    for index, song in enumerate(songs):
        song_id = required_text(song, "id", index)
        required_text(song, "title", index)
        required_text(song, "body", index)
        if song_id in ids:
            raise ValueError(f"Duplicate song ID {song_id!r}")
        ids.add(song_id)
        for key in ("englishTitle", "englishBody", "author"):
            value = song.get(key)
            if value is not None and not isinstance(value, str):
                raise ValueError(f"Song {index} has invalid {key}")

    print(f"Validated catalogue v{manifest['catalogVersion']}: {len(songs)} songs")


if __name__ == "__main__":
    main()
