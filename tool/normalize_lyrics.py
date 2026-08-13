#!/usr/bin/env python3
"""Normalize legacy Praise lyric markers without modifying the master CSV."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path


LYRIC_COLUMNS = ("TELUGU SONG", "ENGLISH SONG")
MARKER = re.compile(r"\|\|\s*([^|\r\n]+?)\s*\|\|")
REPEAT_COUNT = re.compile(r"\(\s*([2-9]\d*)\s*\)")
HORIZONTAL_SPACE = re.compile(r"[\t \u00a0\u1680\u2000-\u200a\u202f\u205f\u3000]+")
JOINED_WORDS = re.compile(r"[a-z][A-Z]")
SPACED_MARKER_DELIMITER = re.compile(r"\|\s+\|")
SINGLE_CLOSING_DELIMITER = re.compile(r"(\|\|[^|\n]+)\|$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path, help="Original CSV")
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("catalog/source/songs.normalized.csv"),
        help="Normalized CSV copy",
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=Path("catalog/reports/lyrics_review.csv"),
        help="Manual-review report",
    )
    parser.add_argument(
        "--summary",
        type=Path,
        default=Path("catalog/reports/lyrics_summary.json"),
        help="Normalization summary",
    )
    return parser.parse_args()


def clean_inline(value: str) -> str:
    return HORIZONTAL_SPACE.sub(" ", value).strip()


def append_line(lines: list[str], value: str) -> None:
    value = clean_inline(value)
    if value:
        lines.append(value)


def append_blank(lines: list[str]) -> None:
    if lines and lines[-1] != "":
        lines.append("")


def normalize_body(value: str) -> tuple[str, int, int, int]:
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    output: list[str] = []
    marker_count = 0
    repeat_count = 0
    repaired_marker_count = 0

    for raw_line in value.split("\n"):
        line = clean_inline(raw_line)
        if not line:
            append_blank(output)
            continue

        repaired_line = SPACED_MARKER_DELIMITER.sub("||", line)
        repaired_line = SINGLE_CLOSING_DELIMITER.sub(r"\1||", repaired_line)
        if repaired_line != line:
            repaired_marker_count += 1
        line = repaired_line

        repeat_count += len(REPEAT_COUNT.findall(line))
        line = REPEAT_COUNT.sub(lambda match: f"×{match.group(1)}", line)
        position = 0
        matches = list(MARKER.finditer(line))
        for match in matches:
            append_line(output, line[position : match.start()])
            append_blank(output)
            output.append(f"[Repeat: {clean_inline(match.group(1))}]")
            append_blank(output)
            marker_count += 1
            position = match.end()
        append_line(output, line[position:])

    while output and output[-1] == "":
        output.pop()
    compact: list[str] = []
    for line in output:
        if line == "" and (not compact or compact[-1] == ""):
            continue
        compact.append(line)
    return "\n".join(compact), marker_count, repeat_count, repaired_marker_count


def add_review_issues(
    issues: list[dict[str, object]],
    *,
    row_number: int,
    song_id: str,
    title: str,
    column: str,
    body: str,
) -> None:
    for line_number, line in enumerate(body.splitlines(), start=1):
        problem = None
        if "||" in line:
            problem = "unmatched_repeat_marker"
        elif len(line) > 120:
            problem = "line_over_120_characters"
        elif len(line) > 80 and len(JOINED_WORDS.findall(line)) >= 3:
            problem = "possible_joined_words"
        if problem:
            issues.append(
                {
                    "csvRow": row_number,
                    "songId": song_id,
                    "title": title,
                    "column": column,
                    "line": line_number,
                    "issue": problem,
                    "excerpt": line[:240],
                }
            )


def main() -> None:
    args = parse_args()
    with args.input.open("r", encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source)
        fields = reader.fieldnames or []
        missing = [column for column in LYRIC_COLUMNS if column not in fields]
        if missing:
            raise ValueError(f"CSV is missing columns: {', '.join(missing)}")
        rows = list(reader)

    issues: list[dict[str, object]] = []
    marker_total = 0
    repeat_total = 0
    repaired_marker_total = 0
    changed_songs = 0
    for row_number, row in enumerate(rows, start=2):
        changed = False
        for key, value in list(row.items()):
            cleaned = (value or "").strip()
            if cleaned != (value or ""):
                changed = True
            row[key] = cleaned

        marker_counts: dict[str, int] = {}
        for column in LYRIC_COLUMNS:
            original = row[column]
            normalized, markers, repeats, repaired_markers = normalize_body(original)
            row[column] = normalized
            marker_counts[column] = markers
            marker_total += markers
            repeat_total += repeats
            repaired_marker_total += repaired_markers
            changed = changed or normalized != original
            add_review_issues(
                issues,
                row_number=row_number,
                song_id=row.get("ID", ""),
                title=row.get("TELUGU TITLE", ""),
                column=column,
                body=normalized,
            )

        if marker_counts[LYRIC_COLUMNS[0]] != marker_counts[LYRIC_COLUMNS[1]]:
            issues.append(
                {
                    "csvRow": row_number,
                    "songId": row.get("ID", ""),
                    "title": row.get("TELUGU TITLE", ""),
                    "column": "BOTH",
                    "line": "",
                    "issue": "repeat_marker_count_mismatch",
                    "excerpt": (
                        f"Telugu={marker_counts[LYRIC_COLUMNS[0]]}; "
                        f"English={marker_counts[LYRIC_COLUMNS[1]]}"
                    ),
                }
            )
        if changed:
            changed_songs += 1

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8-sig", newline="") as destination:
        writer = csv.DictWriter(destination, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    report_fields = ("csvRow", "songId", "title", "column", "line", "issue", "excerpt")
    args.report.parent.mkdir(parents=True, exist_ok=True)
    with args.report.open("w", encoding="utf-8-sig", newline="") as report:
        writer = csv.DictWriter(report, fieldnames=report_fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(issues)

    issue_counts = Counter(str(issue["issue"]) for issue in issues)
    summary = {
        "songCount": len(rows),
        "changedSongCount": changed_songs,
        "normalizedRepeatCueCount": marker_total,
        "normalizedRepeatCountCount": repeat_total,
        "repairedMalformedRepeatMarkerCount": repaired_marker_total,
        "reviewIssueCount": len(issues),
        "reviewIssueCounts": dict(sorted(issue_counts.items())),
        "sourceFile": args.input.name,
        "normalizedFile": args.output.as_posix(),
    }
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        f"Normalized {len(rows)} songs ({changed_songs} changed); "
        f"created {len(issues)} review issues"
    )


if __name__ == "__main__":
    main()
