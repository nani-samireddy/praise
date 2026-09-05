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


def validate_song(song: object, index: int) -> str:
    song_id = required_text(song, "id", index)
    required_text(song, "title", index)
    required_text(song, "body", index)
    for key in (
        "englishTitle",
        "englishBody",
        "author",
        "maleVideoUrl",
        "femaleVideoUrl",
    ):
        value = song.get(key)
        if value is not None and not isinstance(value, str):
            raise ValueError(f"Song {index} has invalid {key}")
        if key.endswith("VideoUrl") and value is not None:
            host = re.sub(r"^https?://", "", value).split("/", 1)[0].lower()
            if host != "youtu.be" and not host.endswith("youtube.com"):
                raise ValueError(f"Song {index} has invalid {key}")
    return song_id


def validate_delta_file(
    *,
    folder: Path,
    catalog_version: int,
    delta_from_version: int,
    delta_sha256: str,
    delta_url: str,
) -> None:
    if (
        not isinstance(delta_from_version, int)
        or delta_from_version < 1
        or delta_from_version >= catalog_version
    ):
        raise ValueError("Invalid deltaFromVersion")
    if (
        not isinstance(delta_sha256, str)
        or not re.fullmatch(r"[0-9a-f]{64}", delta_sha256)
    ):
        raise ValueError("Invalid deltaSha256")
    if (
        not isinstance(delta_url, str)
        or not delta_url
        or "\\" in delta_url
        or "/" in delta_url
    ):
        raise ValueError("Invalid deltaUrl")
    delta_data = (folder / delta_url).read_bytes().replace(b"\r\n", b"\n")
    if hashlib.sha256(delta_data).hexdigest() != delta_sha256:
        raise ValueError("Delta checksum mismatch")
    delta = json.loads(delta_data.decode("utf-8"))
    if delta.get("fromVersion") != delta_from_version:
        raise ValueError("Delta fromVersion mismatch")
    if delta.get("toVersion") > catalog_version:
        raise ValueError("Delta toVersion exceeds catalog version")
    upserts = delta.get("upserts")
    deletes = delta.get("deletes")
    if not isinstance(upserts, list) or not isinstance(deletes, list):
        raise ValueError("Delta upserts and deletes must be arrays")
    delta_ids: set[str] = set()
    for index, song in enumerate(upserts):
        song_id = validate_song(song, index)
        if song_id in delta_ids:
            raise ValueError(f"Duplicate delta song ID {song_id!r}")
        delta_ids.add(song_id)
    for song_id in deletes:
        if not isinstance(song_id, str) or not song_id.strip():
            raise ValueError("Delta delete IDs must be non-empty strings")
        if song_id in delta_ids:
            raise ValueError(f"Delta both upserts and deletes song ID {song_id!r}")
        delta_ids.add(song_id)


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
        song_id = validate_song(song, index)
        if song_id in ids:
            raise ValueError(f"Duplicate song ID {song_id!r}")
        ids.add(song_id)

    delta_fields = (
        manifest.get("deltaFromVersion"),
        manifest.get("deltaSha256"),
        manifest.get("deltaUrl"),
    )
    if any(value is not None for value in delta_fields):
        if any(value is None for value in delta_fields):
            raise ValueError("Manifest delta fields must be provided together")
        delta_from_version, delta_sha256, delta_url = delta_fields
        validate_delta_file(
            folder=folder,
            catalog_version=manifest["catalogVersion"],
            delta_from_version=delta_from_version,
            delta_sha256=delta_sha256,
            delta_url=delta_url,
        )

    deltas = manifest.get("deltas", [])
    if not isinstance(deltas, list):
        raise ValueError("Manifest deltas must be an array")
    references: set[tuple[int, int]] = set()
    for item in deltas:
        if not isinstance(item, dict):
            raise ValueError("Manifest delta reference must be an object")
        from_version = item.get("fromVersion")
        to_version = item.get("toVersion")
        sha = item.get("sha256")
        url = item.get("url")
        if not isinstance(to_version, int) or to_version <= 1:
            raise ValueError("Invalid delta toVersion")
        key = (from_version, to_version)
        if key in references:
            raise ValueError("Duplicate manifest delta reference")
        references.add(key)
        validate_delta_file(
            folder=folder,
            catalog_version=manifest["catalogVersion"],
            delta_from_version=from_version,
            delta_sha256=sha,
            delta_url=url,
        )
        delta = json.loads((folder / url).read_text(encoding="utf-8"))
        if delta.get("toVersion") != to_version:
            raise ValueError("Delta toVersion mismatch")

    print(f"Validated catalogue v{manifest['catalogVersion']}: {len(songs)} songs")


if __name__ == "__main__":
    main()
