#!/usr/bin/env python3
"""Add immutable original and editable structured lyric columns to a catalogue CSV."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


APP_SHEET_COLUMNS = {
    "body": ("original_song", "structured_song"),
    "english_body": ("original_english_song", "structured_english_song"),
}
MASTER_COLUMNS = {
    "TELUGU SONG": ("TELUGU ORIGINAL SONG", "TELUGU STRUCTURED SONG"),
    "ENGLISH SONG": ("ENGLISH ORIGINAL SONG", "ENGLISH STRUCTURED SONG"),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--appsheet", action="store_true", help="Migrate AppSheet column names"
    )
    return parser.parse_args()


def migrate(path: Path, output: Path, *, appsheet: bool) -> int:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fields = reader.fieldnames or []
        mapping = APP_SHEET_COLUMNS if appsheet else MASTER_COLUMNS
        missing = [column for column in mapping if column not in fields]
        if missing:
            raise ValueError(f"{path} is already migrated or missing: {', '.join(missing)}")

        new_fields: list[str] = []
        for field in fields:
            if field in mapping:
                new_fields.extend(mapping[field])
            else:
                new_fields.append(field)

        rows: list[dict[str, str]] = []
        for row in reader:
            migrated: dict[str, str] = {}
            for field in fields:
                if field in mapping:
                    original, structured = mapping[field]
                    value = row.get(field) or ""
                    # Historical catalogues did not preserve a raw copy.  Start
                    # both values from the existing lyrics rather than inventing
                    # or attempting to reverse prior formatting.
                    migrated[original] = value
                    migrated[structured] = value
                else:
                    migrated[field] = row.get(field) or ""
            rows.append(migrated)

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=new_fields)
        writer.writeheader()
        writer.writerows(rows)
    return len(rows)


def main() -> None:
    args = parse_args()
    count = migrate(args.input, args.output, appsheet=args.appsheet)
    print(f"Migrated {count} rows to {args.output}")


if __name__ == "__main__":
    main()
