#!/usr/bin/env python3
"""Find and safely apply proposed multi-line lyric repeat blocks.

The scanner never changes lyrics. Editors approve individual rows in its CSV
output, then the apply command creates structured lyrics from the immutable
original lyrics. Existing manual structured edits are protected by default.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import re
from collections import defaultdict
from pathlib import Path


LANGUAGES = (
    ("telugu", "ID", "TELUGU TITLE", "TELUGU ORIGINAL SONG", "TELUGU STRUCTURED SONG"),
    ("english", "ID", "ENGLISH TITLE", "ENGLISH ORIGINAL SONG", "ENGLISH STRUCTURED SONG"),
)
TRAILING_COUNT = re.compile(r"\s*(?:×|x|X|\*)([2-9]|1[0-2])\s*$|\s*\(([2-9]|1[0-2])\)\s*$")

REVIEW_COLUMNS = [
    "decision",
    "source_id",
    "title",
    "language",
    "start_line",
    "end_line",
    "repeat_count",
    "confidence",
    "reason",
    "source_sha256",
    "original_block",
    "proposed_structured_block",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)
    for command in ("scan", "apply"):
        child = subcommands.add_parser(command)
        child.add_argument("--input", required=True, type=Path)
        child.add_argument("--review", required=True, type=Path)
    apply = subcommands.choices["apply"]
    apply.add_argument("--output", required=True, type=Path)
    apply.add_argument(
        "--overwrite-structured",
        action="store_true",
        help="Allow replacing structured lyrics that were manually changed",
    )
    return parser.parse_args()


def read_rows(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fields = reader.fieldnames or []
        required = {"ID", "TELUGU ORIGINAL SONG", "TELUGU STRUCTURED SONG"}
        missing = required - set(fields)
        if missing:
            raise ValueError(f"{path} is missing columns: {', '.join(sorted(missing))}")
        return fields, list(reader)


def clean_line(line: str) -> tuple[str, int]:
    match = TRAILING_COUNT.search(line)
    if not match:
        return line.strip(), 1
    count = int(match.group(1) or match.group(2))
    return line[: match.start()].strip(), count


def fingerprint(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def candidates(body: str) -> list[tuple[int, int, int, float, str]]:
    """Find immediately repeated 2-8 line groups, preserving blank-section boundaries."""
    lines = body.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    result: list[tuple[int, int, int, float, str]] = []
    seen: set[tuple[int, int]] = set()
    for start in range(len(lines)):
        if not lines[start].strip() or lines[start].lstrip().startswith("["):
            continue
        for size in range(min(8, (len(lines) - start) // 2), 1, -1):
            group = lines[start : start + size]
            if any(not line.strip() or line.lstrip().startswith("[") for line in group):
                continue
            normalized = [clean_line(line)[0] for line in group]
            count_multiplier = max(clean_line(line)[1] for line in group)
            repeat_runs = 1
            while start + (repeat_runs + 1) * size <= len(lines):
                next_group = lines[start + repeat_runs * size : start + (repeat_runs + 1) * size]
                if [clean_line(line)[0] for line in next_group] != normalized:
                    break
                repeat_runs += 1
            if repeat_runs < 2:
                continue
            end = start + repeat_runs * size
            key = (start, end)
            if key in seen:
                continue
            seen.add(key)
            repeat_count = repeat_runs * count_multiplier
            proposed = "[Repeat ×%d]\n%s\n[/Repeat]" % (repeat_count, "\n".join(normalized))
            confidence = 0.99 if count_multiplier > 1 else 0.97
            reason = (
                f"{repeat_runs} adjacent copies of a {size}-line group"
                + (f", each marked ×{count_multiplier}" if count_multiplier > 1 else "")
            )
            result.append((start + 1, end, repeat_count, confidence, reason + "\n" + proposed))
            break
    return result


def scan(input_path: Path, review_path: Path) -> int:
    _, rows = read_rows(input_path)
    output: list[dict[str, str]] = []
    for row in rows:
        for language, id_key, title_key, original_key, _ in LANGUAGES:
            body = (row.get(original_key) or "").strip()
            if not body:
                continue
            lines = body.replace("\r\n", "\n").replace("\r", "\n").split("\n")
            for start, end, repeat_count, confidence, packed in candidates(body):
                reason, proposed = packed.split("\n", 1)
                original = "\n".join(lines[start - 1 : end])
                output.append(
                    {
                        "decision": "pending",
                        "source_id": row[id_key],
                        "title": row.get(title_key) or row.get("TELUGU TITLE") or "",
                        "language": language,
                        "start_line": str(start),
                        "end_line": str(end),
                        "repeat_count": str(repeat_count),
                        "confidence": f"{confidence:.2f}",
                        "reason": reason,
                        "source_sha256": fingerprint(body),
                        "original_block": original,
                        "proposed_structured_block": proposed,
                    }
                )
    review_path.parent.mkdir(parents=True, exist_ok=True)
    with review_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=REVIEW_COLUMNS)
        writer.writeheader()
        writer.writerows(output)
    return len(output)


def apply(input_path: Path, review_path: Path, output_path: Path, *, overwrite: bool) -> int:
    fields, rows = read_rows(input_path)
    with review_path.open("r", encoding="utf-8-sig", newline="") as handle:
        approvals = [row for row in csv.DictReader(handle) if (row.get("decision") or "").strip().lower() == "approved"]
    grouped: dict[tuple[str, str], list[dict[str, str]]] = defaultdict(list)
    for approval in approvals:
        grouped[(approval["source_id"], approval["language"])].append(approval)

    changed = 0
    for row in rows:
        for language, id_key, _, original_key, structured_key in LANGUAGES:
            proposals = grouped.get((row["ID"], language), [])
            if not proposals:
                continue
            original = (row.get(original_key) or "").strip()
            existing = (row.get(structured_key) or "").strip()
            if existing and existing != original and not overwrite:
                raise ValueError(
                    f"{row['ID']} has manual {language} structured lyrics; "
                    "review them or pass --overwrite-structured explicitly"
                )
            if any(proposal.get("source_sha256") != fingerprint(original) for proposal in proposals):
                raise ValueError(f"{row['ID']} changed since its review file was generated")
            lines = original.split("\n")
            replacements = []
            for proposal in proposals:
                replacements.append((int(proposal["start_line"]) - 1, int(proposal["end_line"]), proposal["proposed_structured_block"]))
            replacements.sort(reverse=True)
            for start, end, replacement in replacements:
                lines[start:end] = replacement.split("\n")
            value = "\n".join(lines)
            if row.get(structured_key) != value:
                row[structured_key] = value
                changed += 1

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    return changed


def main() -> None:
    args = parse_args()
    if args.command == "scan":
        count = scan(args.input, args.review)
        print(f"Found {count} repeat-block candidates in {args.review}")
        return
    changed = apply(
        args.input,
        args.review,
        args.output,
        overwrite=args.overwrite_structured,
    )
    print(f"Applied approved repeat blocks to {changed} song language bodies")


if __name__ == "__main__":
    main()
