# Praise — Canonical Lyrics Format

## Purpose

Praise stores each language as a plain-text body with lightweight structural
markers. This keeps CSV maintenance and custom-song editing simple while giving
the reader enough information to style sections and repeat instructions.

## Canonical rules

- Store one lyric line per physical line.
- Use one blank line between sections.
- Remove leading and trailing whitespace.
- Collapse repeated horizontal spaces and repeated blank lines.
- Write repeat counts as `×2`, `×3`, and so on.
- Write repeat cues on their own line as `[Repeat: cue]`.
- Optional explicit section labels are `[Verse 1]`, `[Chorus]`,
  `[Pre-Chorus]`, `[Bridge]`, and `[Ending]`.
- Do not infer a verse or chorus label when the source is ambiguous.
- Preserve wording, punctuation, and language independently of layout cleanup.

Example:

```text
[Verse 1]
Agni Manduchundene – Poda Kaalipoledugaa ×2
Aa Agnilo Nunde Neevu Moshenu Darshinchinaave ×2

[Repeat: Agni]
```

Legacy `(2)` repeat counts are normalized to `×2`. Legacy `||Agni||` markers
are normalized to `[Repeat: Agni]`.

## Reader presentation

- Normal lyric lines use a `1.5` line-height multiplier.
- Independent lyric groups receive 20 logical pixels of separation.
- Section labels receive 24 logical pixels before them and use the theme accent.
- Repeat cues receive 18 logical pixels before them and render as a small,
  lightly highlighted cue without an added label.
- A section label or repeat cue receives 30 logical pixels after it before the
  next lyric line. This is the visual equivalent of one additional blank line.
- The outer primary/English lyrics heading receives 28 logical pixels before
  its first content block.
- Primary and English language blocks remain separate, with 32 logical pixels
  around the language divider.
- Pinch scaling changes lyric text size while structural labels remain stable.
- The selected Telugu typeface applies to the primary title, primary lyrics,
  structural labels, repeat cues, and repeat counts. English lyrics continue to
  use the app's default typeface.
- A trailing repeat count from `×2` through `×12` renders as compact, lightly
  highlighted text. One song-level `Expand ×N` action expands every annotated
  line into plain repeated lines in both languages; `Compact` restores the
  concise view. This is temporary reader state and never rewrites the song.

Unknown bracketed text remains visible as ordinary lyrics. The reader never
silently discards syntax it does not understand.

## Editorial source and structured lyrics

The catalogue keeps two bodies per language:

| Field | Purpose |
| --- | --- |
| `original_song` / `original_english_song` | Immutable submitted lyrics. Never overwrite with AI formatting. |
| `structured_song` / `structured_english_song` | Editor-approved display text, including lightweight markers. |

The published app body is `structured_song` when it is non-empty; otherwise it
falls back to `original_song`. This keeps formatting experiments reversible and
lets reviewers compare every proposed change with the source.

### Multi-line repeat blocks

Use a multi-line repeat block only when the same consecutive group is intended
to be sung repeatedly:

```text
[Repeat ×4]
అన్ని వేళల ఆరాధన
కన్న తండ్రి నీకే మహిమ
[/Repeat]
```

The reader shows the group once in short lyrics mode and expands the *entire*
group four times in full lyrics mode. It is different from a trailing `×2`,
which repeats only that single line.

### Repeat-block review tool

The repository provides a safe, reusable workflow for large catalogues:

```powershell
# 1. Detect candidates only — this never modifies lyrics.
python tool/repeat_blocks.py scan `
  --input catalog/source/songs.normalized.csv `
  --review catalog/reports/repeat_blocks_review.csv

# 2. Open the review CSV and change selected `decision` values to `approved`.

# 3. Apply approved proposals to structured fields only.
python tool/repeat_blocks.py apply `
  --input catalog/source/songs.normalized.csv `
  --review catalog/reports/repeat_blocks_review.csv `
  --output catalog/source/songs.normalized.updated.csv
```

The apply step refuses to overwrite a manually edited structured body. Review
that song manually, or deliberately pass `--overwrite-structured` when the
original source is the intended basis for regeneration.

## Chords

Chords are not written into the canonical lyrics body. The body stays one lyric
line per physical line so search, copy, sync, and lyrics-only reading remain
simple and fast.

Future chord support uses optional structured arrangements described in
`docs/CHORDS_SCHEMA.md`. Chords are anchored to positions inside normalized
lyric lines and rendered above the lyrics at display time. Do not preserve
legacy padded chord-over-lyric spacing as the canonical format; it is an input
format that must be parsed and validated before publishing.

## Normalization workflow

The original supplied CSV is never overwritten. Generate the maintained copy,
review report, static catalogue, and complete bundled catalogue with:

```powershell
python tool/normalize_lyrics.py `
  --input "C:\path\to\lyricly - TELUGU.csv"

python tool/build_catalog.py `
  --input catalog/source/songs.normalized.csv `
  --version 3 `
  --bundle-output assets/data/songs.json `
  --bundle-all

python tool/validate_catalog.py
```

Every changed catalogue must use a version higher than the currently published
manifest. The builder rejects changed content with a reused or lower version.

`catalog/reports/lyrics_review.csv` contains only cases that require human
judgment, including unusually long lines and differences in repeat-cue counts
between the Telugu and English bodies. These are review warnings, not automatic
evidence that the source wording is wrong.
