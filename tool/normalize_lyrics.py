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
JOINED_ENGLISH_LINE = re.compile(r"(?<=[a-z])(?=[A-Z])")
REPEAT_LINE_BOUNDARY = re.compile(r"(×\d+)(?=\S)")
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
    parser.add_argument(
        "--line-break-overrides",
        type=Path,
        default=Path("tool/lyrics_line_break_overrides.json"),
        help="Reviewed per-song lyric line breaks",
    )
    parser.add_argument(
        "--stanza-breaks",
        type=Path,
        default=Path("tool/lyrics_stanza_breaks.json"),
        help="Reviewed lines after which a blank stanza separator is inserted",
    )
    return parser.parse_args()


def load_line_break_overrides(path: Path) -> dict[str, dict[str, str]]:
    if not path.exists():
        return {}
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("Line-break overrides must be a JSON object keyed by song ID")

    overrides: dict[str, dict[str, str]] = {}
    for song_id, columns in raw.items():
        if not isinstance(song_id, str) or not isinstance(columns, dict):
            raise ValueError("Each line-break override must map a song ID to columns")
        unexpected = set(columns) - set(LYRIC_COLUMNS)
        if unexpected:
            raise ValueError(
                f"Override {song_id} has unsupported columns: {', '.join(sorted(unexpected))}"
            )
        parsed_columns: dict[str, str] = {}
        for column, lines in columns.items():
            if not isinstance(lines, list) or not all(
                isinstance(line, str) for line in lines
            ):
                raise ValueError(
                    f"Override {song_id}/{column} must be an array of lyric lines"
                )
            parsed_columns[column] = "\n".join(lines).strip()
        overrides[song_id] = parsed_columns
    return overrides


def load_stanza_breaks(path: Path) -> dict[str, dict[str, list[str]]]:
    if not path.exists():
        return {}
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("Stanza breaks must be a JSON object keyed by song ID")

    stanza_breaks: dict[str, dict[str, list[str]]] = {}
    for song_id, columns in raw.items():
        if not isinstance(song_id, str) or not isinstance(columns, dict):
            raise ValueError("Each stanza-break entry must map a song ID to columns")
        unexpected = set(columns) - set(LYRIC_COLUMNS)
        if unexpected:
            raise ValueError(
                f"Stanza breaks for {song_id} have unsupported columns: "
                + ", ".join(sorted(unexpected))
            )
        parsed_columns: dict[str, list[str]] = {}
        for column, lines in columns.items():
            if not isinstance(lines, list) or not all(
                isinstance(line, str) and line for line in lines
            ):
                raise ValueError(
                    f"Stanza breaks for {song_id}/{column} must be non-empty lines"
                )
            parsed_columns[column] = lines
        stanza_breaks[song_id] = parsed_columns
    return stanza_breaks


def apply_stanza_breaks(body: str, break_after: list[str]) -> str:
    requested = set(break_after)
    matched: set[str] = set()
    output: list[str] = []
    lines = body.splitlines()
    for index, line in enumerate(lines):
        output.append(line)
        if line in requested:
            matched.add(line)
            if index + 1 < len(lines) and lines[index + 1] != "":
                output.append("")
    unmatched = requested - matched
    if unmatched:
        raise ValueError(
            "Stanza-break lines were not found after normalization: "
            + " | ".join(sorted(unmatched))
        )
    return "\n".join(output).strip()


def clean_inline(value: str) -> str:
    return HORIZONTAL_SPACE.sub(" ", value).strip()


def append_lines(lines: list[str], value: str, *, english: bool) -> int:
    value = clean_inline(value)
    if not value:
        return 0
    value, repeat_splits = REPEAT_LINE_BOUNDARY.subn(r"\1\n", value)
    camel_splits = 0
    if english:
        value, camel_splits = JOINED_ENGLISH_LINE.subn("\n", value)
    for part in value.splitlines():
        cleaned = clean_inline(part)
        if cleaned:
            lines.append(cleaned)
    return repeat_splits + camel_splits


def append_blank(lines: list[str]) -> None:
    if lines and lines[-1] != "":
        lines.append("")


def normalize_body(value: str, *, english: bool) -> tuple[str, int, int, int, int]:
    value = value.replace("\r\n", "\n").replace("\r", "\n")
    output: list[str] = []
    marker_count = 0
    repeat_count = 0
    repaired_marker_count = 0
    repaired_joined_line_count = 0

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
            repaired_joined_line_count += append_lines(
                output, line[position : match.start()], english=english
            )
            append_blank(output)
            output.append(f"[Repeat: {clean_inline(match.group(1))}]")
            append_blank(output)
            marker_count += 1
            position = match.end()
        repaired_joined_line_count += append_lines(
            output, line[position:], english=english
        )

    while output and output[-1] == "":
        output.pop()
    compact: list[str] = []
    for line in output:
        if line == "" and (not compact or compact[-1] == ""):
            continue
        compact.append(line)
    return (
        "\n".join(compact),
        marker_count,
        repeat_count,
        repaired_marker_count,
        repaired_joined_line_count,
    )


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
    line_break_overrides = load_line_break_overrides(args.line_break_overrides)
    stanza_breaks = load_stanza_breaks(args.stanza_breaks)
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
    repaired_joined_line_total = 0
    overridden_songs: set[str] = set()
    stanza_spaced_songs: set[str] = set()
    seen_song_ids: set[str] = set()
    changed_songs = 0
    for row_number, row in enumerate(rows, start=2):
        changed = False
        for key, value in list(row.items()):
            cleaned = (value or "").strip()
            if cleaned != (value or ""):
                changed = True
            row[key] = cleaned

        song_id = row.get("ID", "")
        seen_song_ids.add(song_id)
        song_overrides = line_break_overrides.get(song_id, {})
        song_stanza_breaks = stanza_breaks.get(song_id, {})
        marker_counts: dict[str, int] = {}
        for column in LYRIC_COLUMNS:
            original = row[column]
            normalized, markers, repeats, repaired_markers, repaired_lines = (
                normalize_body(original, english=column == "ENGLISH SONG")
            )
            if column in song_overrides:
                normalized = song_overrides[column]
                overridden_songs.add(song_id)
            if column in song_stanza_breaks:
                normalized = apply_stanza_breaks(
                    normalized, song_stanza_breaks[column]
                )
                stanza_spaced_songs.add(song_id)
            row[column] = normalized
            marker_counts[column] = markers
            marker_total += markers
            repeat_total += repeats
            repaired_marker_total += repaired_markers
            repaired_joined_line_total += repaired_lines
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

    unknown_override_ids = set(line_break_overrides) - seen_song_ids
    if unknown_override_ids:
        raise ValueError(
            "Line-break overrides contain unknown song IDs: "
            + ", ".join(sorted(unknown_override_ids))
        )
    unknown_stanza_ids = set(stanza_breaks) - seen_song_ids
    if unknown_stanza_ids:
        raise ValueError(
            "Stanza breaks contain unknown song IDs: "
            + ", ".join(sorted(unknown_stanza_ids))
        )

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
        "repairedJoinedLineBoundaryCount": repaired_joined_line_total,
        "lineBreakOverrideSongCount": len(overridden_songs),
        "stanzaSpacingSongCount": len(stanza_spaced_songs),
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
