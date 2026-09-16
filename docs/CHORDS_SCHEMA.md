# Praise — Chord Schema Design

## Purpose

Praise should support chords without making normal lyric reading slower or
fragile. Chords are optional presentation metadata layered over canonical
lyrics; the existing plain-text body remains the fallback for search, sharing,
and devices that do not render chords.

## Design goals

- Keep normal lyrics readable even when chord data is missing or invalid.
- Avoid embedding chords directly into lyric text where spacing can break on
  different phones and fonts.
- Support transposition later without rewriting lyrics.
- Keep catalogue validation strict and deterministic.
- Store enough structure for image/PDF export and future practice features.

## Data model

The current song fields remain:

```json
{
  "id": "csv-0001",
  "title": "primary title",
  "englishTitle": "English title",
  "body": "plain canonical lyrics",
  "englishBody": "plain English lyrics",
  "author": "author"
}
```

Chord support adds an optional `arrangements` array. Each arrangement is a
structured overlay for one language/body, not a replacement for `body`.

```json
{
  "arrangements": [
    {
      "id": "default",
      "name": "Default",
      "language": "primary",
      "key": "D",
      "capo": 0,
      "sections": [
        {
          "label": "Verse 1",
          "lines": [
            {
              "text": "నీ ప్రేమ నన్ను నడిపించెను",
              "segments": [
                { "text": "నీ ప్రేమ", "chord": "D" },
                { "text": "నన్ను నడి", "chord": "G" },
                { "text": "పించెను", "chord": "A" }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

## Field rules

| Field | Rule |
| --- | --- |
| `arrangements` | Optional array. Missing means lyrics-only. |
| `arrangements[].id` | Stable lowercase identifier unique within one song. |
| `name` | Human label such as `Default`, `Acoustic`, or `Female key`. |
| `language` | `primary` or `english`. Determines which plain body it overlays. |
| `key` | Concert key. Use canonical names like `C`, `F#`, `Bb`, `Am`. |
| `capo` | Integer from `0` to `12`. |
| `sections[].label` | Optional display label matching the lyrics format labels when possible. |
| `lines[].text` | The complete lyric line, retained for search and validation. |
| `lines[].segments` | Ordered lyric pieces that make up the rendered line. |
| `segments[].text` | Contiguous lyric text. Preserve boundary whitespace when it is meaningful. |
| `segments[].chord` | Optional valid chord symbol applied to the start of that segment. |

Segments are ordered and concatenated to form the lyric line. Chords are
attached to lyric content rather than character offsets, so the renderer can
lay out each segment and chord together at every font size and screen width.

## Capo, guitar shapes, and harmony

The mobile structure form may also include `capo` at the song level. It is an
integer from `0` to `12`. When guitar shapes are enabled, the reader displays
the transposed concert chord together with the playable shape relative to the
capo. For example, a concert `C` chord with capo `2` uses an `A` shape.

Optional harmony parts use the same line and segment format as the primary
sections:

```json
{
  "capo": 2,
  "harmonyParts": [
    {
      "label": "Alto",
      "lines": [
        { "text": "ఆల్టో గీతము" }
      ]
    }
  ]
}
```

Harmony content is hidden by default and is shown only when the `harmony`
feature is enabled and the reader's Harmony parts control is turned on.

## Chord grammar

Start with a deliberately small grammar:

```text
root       = A | B | C | D | E | F | G
accidental = # | b
quality    = m | maj | min | dim | aug | sus2 | sus4
extension  = 2 | 4 | 5 | 6 | 7 | 9 | 11 | 13
bass       = "/" root accidental?
chord      = root accidental? quality? extension? bass?
```

Accepted examples:

```text
C
D
Em
F#m
Bb
G7
Asus4
D/F#
```

Rejected examples should remain visible as validation errors in the editorial
workflow and should not be published into the mobile catalogue.

## Storage strategy

Use two levels of compatibility:

1. Catalogue JSON can add optional `arrangements` after the mobile parser is
   updated to ignore unsupported optional fields safely.
2. The local database should store arrangements in a separate table or JSON
   column only after the reader UI is ready.

Recommended Drift table for the first implementation:

| Column | Type | Notes |
| --- | --- | --- |
| `song_id` | text | Foreign key to `songs.id`, cascade delete. |
| `arrangement_id` | text | Stable arrangement ID. |
| `name` | text | Display label. |
| `language` | text | `primary` or `english`. |
| `key` | text | Normalized musical key. |
| `capo` | integer | 0 through 12. |
| `sections_json` | text | Validated compact JSON for sections and lines. |
| `updated_at` | datetime | UTC. |

Primary key: (`song_id`, `arrangement_id`).

This keeps ordinary song search and list rendering on the existing `songs`
table. Chord data is loaded only on song detail when the user opens the chord
view.

## Rendering model

The reader should support two modes:

- Lyrics: current plain lyric rendering, no chord layout cost.
- Chords: sectioned chord sheet with chords positioned above lyric segments.

The chord renderer should:

- layout each lyric segment with its optional chord label;
- keep the chord and segment as one responsive unit;
- wrap segments as a group without losing their association;
- hide or compress overlapping chord labels on narrow screens only after
  preserving the lyric line;
- use the selected transpose value as temporary UI state unless the user saves
  a custom arrangement later.

Do not store chord labels as padded text. Padded chord sheets are brittle with
Telugu fonts, proportional fonts, PDF rendering, and user font-size changes.

## Transposition

Transposition should operate on parsed chord tokens, not string replacement.

Rules:

- Keep the stored arrangement in its original key.
- Apply transpose in memory during rendering and export.
- Preserve slash bass movement independently.
- Prefer sharps or flats based on the target key.
- Do not transpose invalid or unknown chord strings.

## Catalogue validation

The catalogue builder must reject:

- duplicate arrangement IDs within a song;
- unsupported `language` values;
- invalid keys or capo values;
- malformed or empty lyric segments;
- chord symbols outside the supported grammar;
- empty sections with no lines; and
- arrangement bodies that do not substantially match the plain `body` or
  `englishBody` they overlay.

The last rule prevents chord sheets from silently drifting away from the
canonical lyrics.

## AppSheet editing

AppSheet should not ask editors to edit raw nested JSON or segment arrays by
default. The first editor format is inline chord markup:

```text
[Verse 1]
[D]నీ ప్రేమ [G]నన్ను నడి[A]పించెను

[Chorus]
[G]యేసయ్య నీ [A]నామమే [D]జయము
```

Editors place `[D]`, `[G]`, `[A]`, and similar chord markers immediately before
the lyric phrase where the chord changes. The build tool removes the chord
markers, validates the chord names, and writes ordered lyric segments.

The local parser can be run with:

```powershell
python tool/parse_chord_chart.py `
  --input chord-chart.txt `
  --output arrangement.json `
  --id default-d `
  --name "Default - D" `
  --language primary `
  --key D
```

The secondary editor option is retained for later:

1. Start with a `ChordChart` long-text column containing inline `[Chord]lyric`
   markup, then have GitHub Actions parse and validate it into `arrangements`.
2. Later, add child sheets such as `Arrangements`, `ArrangementSections`, and
   `ArrangementLines` for a more controlled editor UI.

The first approach is faster to launch. The second is safer once many editors
are involved.

## Implementation phases

1. Add validators and tests for chord symbols, keys, segments, and arrangement
   shape.
2. Extend the catalogue schema with optional `arrangements` while preserving
   lyrics-only parsing.
3. Add the local arrangement table and migration tests.
4. Render a read-only chord mode on song detail.
5. Add transpose controls as local reader state.
6. Include chords in PDF/image export as an explicit export option.
7. Add AppSheet chord entry only after the parser and validator are stable.

Chords should not be added to V1 release scope. They are a V2 data and reader
feature because they require schema migration, catalogue validation, and new
rendering behavior.
