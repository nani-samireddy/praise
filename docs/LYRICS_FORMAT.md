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
