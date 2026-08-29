"""Parse editor-friendly chord charts into Praise arrangement JSON."""

from __future__ import annotations

import argparse
import json
import re
import unicodedata
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


CHORD_RE = re.compile(
    r"^[A-G](?:#|b)?(?:(?:maj|min|dim|aug|sus2|sus4|m)?(?:2|4|5|6|7|9|11|13)?)?(?:/[A-G](?:#|b)?)?$"
)
SECTION_RE = re.compile(r"^\[(Verse \d+|Chorus|Pre-Chorus|Bridge|Ending)\]$")
INLINE_CHORD_RE = re.compile(r"\[([^\]\r\n]+)\]")
KEY_RE = re.compile(r"^[A-G](?:#|b)?m?$")


class ChordChartError(ValueError):
    """Raised when an editor chord chart cannot be converted safely."""


@dataclass(frozen=True)
class ParsedLine:
    text: str
    chords: list[dict[str, object]]


def is_valid_chord(value: str) -> bool:
    return bool(CHORD_RE.fullmatch(value.strip()))


def grapheme_count(value: str) -> int:
    return sum(1 for _ in grapheme_clusters(value))


def grapheme_clusters(value: str) -> Iterable[str]:
    cluster = ""
    join_next = False
    for char in value:
        if not cluster:
            cluster = char
            join_next = char == "\u200d"
            continue

        category = unicodedata.category(char)
        if category.startswith("M") or char in ("\u200c", "\u200d") or join_next:
            cluster += char
        else:
            yield cluster
            cluster = char
        join_next = char == "\u200d" or char == "\u0c4d"

    if cluster:
        yield cluster


def parse_inline_chord_line(line: str, line_number: int) -> ParsedLine:
    text_parts: list[str] = []
    chords: list[dict[str, object]] = []
    grapheme_offset = 0
    cursor = 0

    for match in INLINE_CHORD_RE.finditer(line):
        before = line[cursor : match.start()]
        text_parts.append(before)
        grapheme_offset += grapheme_count(before)

        chord = match.group(1).strip()
        if not is_valid_chord(chord):
            raise ChordChartError(f"Line {line_number}: invalid chord {chord!r}")
        chords.append({"at": grapheme_offset, "chord": chord})
        cursor = match.end()

    remainder = line[cursor:]
    text_parts.append(remainder)
    text = "".join(text_parts).strip()
    if not text:
        raise ChordChartError(f"Line {line_number}: chord line has no lyric text")

    leading_trimmed = "".join(text_parts).find(text)
    if leading_trimmed > 0:
        leading_offset = grapheme_count("".join(text_parts)[:leading_trimmed])
        chords = [
            {"at": max(0, int(chord["at"]) - leading_offset), "chord": chord["chord"]}
            for chord in chords
        ]

    line_length = grapheme_count(text)
    for chord in chords:
        if int(chord["at"]) > line_length:
            raise ChordChartError(
                f"Line {line_number}: chord {chord['chord']!r} is outside lyric text"
            )
    return ParsedLine(text=text, chords=chords)


def parse_arrangement_text(
    source: str,
    *,
    arrangement_id: str,
    name: str,
    language: str,
    key: str,
    capo: int = 0,
) -> dict[str, object]:
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", arrangement_id):
        raise ChordChartError("Arrangement id must be lowercase kebab-case")
    if language not in {"primary", "english"}:
        raise ChordChartError("Language must be primary or english")
    if not KEY_RE.fullmatch(key):
        raise ChordChartError(f"Invalid key {key!r}")
    if capo < 0 or capo > 12:
        raise ChordChartError("Capo must be between 0 and 12")

    sections: list[dict[str, object]] = []
    current: dict[str, object] = {"label": None, "lines": []}

    def flush() -> None:
        nonlocal current
        if current["lines"]:
            section = {"lines": current["lines"]}
            if current["label"]:
                section["label"] = current["label"]
            sections.append(section)
        current = {"label": None, "lines": []}

    for line_number, raw_line in enumerate(source.splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            flush()
            continue

        section_match = SECTION_RE.fullmatch(line)
        if section_match:
            flush()
            current["label"] = section_match.group(1)
            continue

        if "[" not in line and "]" not in line:
            current["lines"].append({"text": line, "chords": []})
            continue

        if line.count("[") != line.count("]"):
            raise ChordChartError(f"Line {line_number}: unmatched chord bracket")

        parsed = parse_inline_chord_line(line, line_number)
        current["lines"].append({"text": parsed.text, "chords": parsed.chords})

    flush()
    if not sections:
        raise ChordChartError("Chord chart must contain at least one lyric line")

    return {
        "id": arrangement_id,
        "name": name.strip() or arrangement_id,
        "language": language,
        "key": key,
        "capo": capo,
        "sections": sections,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--id", required=True, dest="arrangement_id")
    parser.add_argument("--name", required=True)
    parser.add_argument("--language", choices=["primary", "english"], default="primary")
    parser.add_argument("--key", required=True)
    parser.add_argument("--capo", type=int, default=0)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    arrangement = parse_arrangement_text(
        args.input.read_text(encoding="utf-8-sig"),
        arrangement_id=args.arrangement_id,
        name=args.name,
        language=args.language,
        key=args.key,
        capo=args.capo,
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(arrangement, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Parsed chord arrangement {arrangement['id']}")


if __name__ == "__main__":
    main()
