#!/usr/bin/env python3
"""Build the versioned static Praise catalogue from the master CSV."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
from datetime import datetime, timezone
from pathlib import Path


REQUIRED_COLUMNS = {
    "ID",
    "TELUGU TITLE",
    "TELUGU SONG",
    "ENGLISH TITLE",
    "ENGLISH SONG",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path, help="Master CSV file")
    parser.add_argument("--version", required=True, type=int, help="Catalogue version")
    parser.add_argument(
        "--output", type=Path, default=Path("docs/catalog"), help="Output directory"
    )
    parser.add_argument(
        "--id-map",
        type=Path,
        default=Path("tool/catalog_id_map.json"),
        help="Persistent source-ID to app-ID mapping",
    )
    parser.add_argument(
        "--bundle-output",
        type=Path,
        help="Optional Flutter bundled-catalogue JSON output",
    )
    parser.add_argument(
        "--bundle-count",
        type=int,
        default=20,
        help="Number of leading songs to include in the Flutter bundle",
    )
    parser.add_argument(
        "--bundle-all",
        action="store_true",
        help="Include the complete catalogue in the Flutter bundle",
    )
    return parser.parse_args()


def optional(value: str | None) -> str | None:
    if value is None:
        return None
    trimmed = value.strip()
    return trimmed or None


def load_id_map(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict) or not all(
        isinstance(key, str) and isinstance(item, str) for key, item in value.items()
    ):
        raise ValueError(f"{path} must contain a JSON string-to-string object")
    if len(set(value.values())) != len(value):
        raise ValueError(f"{path} contains duplicate application IDs")
    return value


def next_id(id_map: dict[str, str]) -> str:
    numbers = []
    for value in id_map.values():
        match = re.fullmatch(r"csv-(\d+)", value)
        if match:
            numbers.append(int(match.group(1)))
    return f"csv-{(max(numbers, default=0) + 1):04d}"


def read_songs(path: Path, id_map: dict[str, str]) -> list[dict[str, object]]:
    songs: list[dict[str, object]] = []
    source_ids: set[str] = set()
    app_ids = set(id_map.values())
    candidate_id = next_id(id_map)

    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fields = set(reader.fieldnames or [])
        missing = sorted(REQUIRED_COLUMNS - fields)
        if missing:
            raise ValueError(f"CSV is missing columns: {', '.join(missing)}")

        for line_number, row in enumerate(reader, start=2):
            source_id = (row.get("ID") or "").strip()
            title = (row.get("TELUGU TITLE") or "").strip()
            body = (row.get("TELUGU SONG") or "").strip()
            if not source_id or not title or not body:
                raise ValueError(
                    f"CSV row {line_number} requires ID, TELUGU TITLE, and TELUGU SONG"
                )
            if source_id in source_ids:
                raise ValueError(f"CSV row {line_number} repeats source ID {source_id!r}")
            source_ids.add(source_id)

            app_id = id_map.get(source_id)
            if app_id is None:
                while candidate_id in app_ids:
                    number = int(candidate_id.split("-")[1]) + 1
                    candidate_id = f"csv-{number:04d}"
                app_id = candidate_id
                id_map[source_id] = app_id
                app_ids.add(app_id)
                number = int(candidate_id.split("-")[1]) + 1
                candidate_id = f"csv-{number:04d}"

            songs.append(
                {
                    "id": app_id,
                    "title": title,
                    "englishTitle": optional(row.get("ENGLISH TITLE")),
                    "body": body,
                    "englishBody": optional(row.get("ENGLISH SONG")),
                    "author": optional(row.get("AUTHOR")),
                    "maleVideoUrl": optional(row.get("MALE VIDEO URL")),
                    "femaleVideoUrl": optional(row.get("FEMALE VIDEO URL")),
                }
            )

    if not songs:
        raise ValueError("CSV contains no songs")
    return songs


def json_bytes(value: object, *, pretty: bool = False) -> bytes:
    text = json.dumps(
        value,
        ensure_ascii=False,
        indent=2 if pretty else None,
        separators=None if pretty else (",", ":"),
    )
    return (text + "\n").encode("utf-8")


def write_atomic(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_bytes(data)
    os.replace(temporary, path)


def main() -> None:
    args = parse_args()
    if args.version < 1:
        raise ValueError("--version must be at least 1")

    id_map = load_id_map(args.id_map)
    songs = read_songs(args.input, id_map)
    songs_data = json_bytes(songs)
    checksum = hashlib.sha256(songs_data).hexdigest()

    manifest_path = args.output / "manifest.json"
    songs_path = args.output / "songs.json"
    previous_manifest = None
    if manifest_path.exists():
        previous_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        previous_version = int(previous_manifest["catalogVersion"])
        previous_bytes = songs_path.read_bytes() if songs_path.exists() else b""
        if songs_data != previous_bytes and args.version <= previous_version:
            raise ValueError(
                f"Catalogue content changed; --version must exceed {previous_version}"
            )
        if args.version < previous_version:
            raise ValueError(f"--version cannot be lower than {previous_version}")

    if (
        previous_manifest
        and args.version == int(previous_manifest["catalogVersion"])
        and songs_path.exists()
        and songs_data == songs_path.read_bytes()
    ):
        generated_at = previous_manifest["generatedAt"]
    else:
        generated_at = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    manifest = {
        "schemaVersion": 1,
        "catalogVersion": args.version,
        "generatedAt": generated_at,
        "songCount": len(songs),
        "sha256": checksum,
        "catalogUrl": "songs.json",
    }

    write_atomic(songs_path, songs_data)
    write_atomic(manifest_path, json_bytes(manifest, pretty=True))
    sorted_map = dict(sorted(id_map.items(), key=lambda item: item[1]))
    write_atomic(args.id_map, json_bytes(sorted_map, pretty=True))
    if args.bundle_output:
        if args.bundle_count < 1:
            raise ValueError("--bundle-count must be at least 1")
        bundled_songs = songs if args.bundle_all else songs[: args.bundle_count]
        write_atomic(
            args.bundle_output,
            json_bytes(bundled_songs, pretty=True),
        )
    print(
        f"Built catalogue v{args.version}: {len(songs)} songs, "
        f"SHA-256 {checksum}"
    )


if __name__ == "__main__":
    main()
