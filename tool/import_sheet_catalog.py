#!/usr/bin/env python3
"""Import approved AppSheet/Google Sheets rows into the Praise catalogue CSV."""

from __future__ import annotations

import argparse
import csv
import io
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


SOURCE_COLUMNS = {
    "source_id",
    "title",
    "english_title",
    "body",
    "english_body",
    "author",
    "status",
}

OUTPUT_COLUMNS = [
    "ID",
    "TELUGU TITLE",
    "TELUGU SONG",
    "ENGLISH TITLE",
    "ENGLISH SONG",
    "AUTHOR",
    "MALE VIDEO URL",
    "FEMALE VIDEO URL",
]

PUBLISHABLE_STATUSES = {"approved", "published"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--input", type=Path, help="Local AppSheet/Sheets CSV export")
    source.add_argument("--url", help="HTTPS CSV export URL")
    parser.add_argument("--output", required=True, type=Path, help="Normalized CSV output")
    parser.add_argument(
        "--token",
        help="Optional bearer token for a protected CSV endpoint",
    )
    return parser.parse_args()


def read_csv_text(*, input_path: Path | None, url: str | None, token: str | None) -> str:
    if input_path is not None:
        return input_path.read_text(encoding="utf-8-sig")

    if url is None:
        raise ValueError("--url is required when --input is not provided")
    if not url.startswith("https://"):
        raise ValueError("Sheet CSV URL must use HTTPS")

    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = Request(url, headers=headers)
    try:
        with urlopen(request, timeout=30) as response:
            content_type = response.headers.get("Content-Type", "")
            if "text/csv" not in content_type and "text/plain" not in content_type:
                print(
                    f"Warning: CSV endpoint returned content type {content_type!r}",
                    file=sys.stderr,
                )
            return response.read().decode("utf-8-sig")
    except HTTPError as error:
        raise ValueError(f"CSV endpoint returned HTTP {error.code}") from error
    except URLError as error:
        raise ValueError(f"Could not reach CSV endpoint: {error.reason}") from error


def normalize_header(value: str) -> str:
    return value.strip().lower().replace(" ", "_")


def required(row: dict[str, str], key: str, line_number: int) -> str:
    value = (row.get(key) or "").strip()
    if not value:
        raise ValueError(f"Row {line_number} requires {key}")
    return value


def optional(row: dict[str, str], key: str) -> str:
    return (row.get(key) or "").strip()


def convert_rows(text: str) -> list[dict[str, str]]:
    reader = csv.DictReader(io.StringIO(text))
    if not reader.fieldnames:
        raise ValueError("Sheet CSV has no header row")

    field_map = {field: normalize_header(field) for field in reader.fieldnames}
    normalized_fields = set(field_map.values())
    missing = sorted(SOURCE_COLUMNS - normalized_fields)
    if missing:
        raise ValueError(f"Sheet CSV is missing columns: {', '.join(missing)}")

    output: list[dict[str, str]] = []
    source_ids: set[str] = set()
    for line_number, raw_row in enumerate(reader, start=2):
        row = {
            field_map[key]: value
            for key, value in raw_row.items()
            if key is not None and field_map.get(key)
        }
        status = optional(row, "status").lower()
        if status not in PUBLISHABLE_STATUSES:
            continue

        source_id = required(row, "source_id", line_number)
        if source_id in source_ids:
            raise ValueError(f"Row {line_number} repeats source_id {source_id!r}")
        source_ids.add(source_id)

        output.append(
            {
                "ID": source_id,
                "TELUGU TITLE": required(row, "title", line_number),
                "TELUGU SONG": required(row, "body", line_number),
                "ENGLISH TITLE": optional(row, "english_title"),
                "ENGLISH SONG": optional(row, "english_body"),
                "AUTHOR": optional(row, "author"),
                "MALE VIDEO URL": optional(row, "male_video_url"),
                "FEMALE VIDEO URL": optional(row, "female_video_url"),
            }
        )

    if not output:
        raise ValueError("Sheet CSV contains no approved or published songs")
    return output


def write_output(path: Path, rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    text = read_csv_text(input_path=args.input, url=args.url, token=args.token)
    rows = convert_rows(text)
    write_output(args.output, rows)
    print(f"Imported {len(rows)} approved songs to {args.output}")


if __name__ == "__main__":
    main()
