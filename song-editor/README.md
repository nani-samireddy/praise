# Praise Song Studio

Independent static web tool. No backend, login, API key, dependency installation
or build step. Files remain in this browser; one draft is saved in localStorage.
Use Download to keep additional drafts. This initial editor handles one language
at a time. Exported JSON retains original text and both output representations.

## Run

From this directory: `python -m http.server 4173`, then open
http://localhost:4173. Tests: `node --test`.

## Use

Paste plain lyrics, then Arrange lyrics. Blank lines and repeat counts establish
phrase boundaries. Change section labels and Times sung; place the cursor on a
line and Split at cursor to start a new phrase. Expanded preview repeats the
whole phrase. Return cues remain visible; their target is reviewed by the editor.
No AI inference is used. Unknown headings/counts remain text; verify before export.
Use For Google Sheets for normalized text; For Praise app for repeat markup.
Full draft JSON is an archival export (JSON import is not yet implemented).

## Deploy separately

### Catalogue repository: GitHub Pages

The existing `.github/workflows/publish-catalog.yml` tests the editor and copies
its static files into `song-editor/` in the catalogue repository on main pushes.
It uses the existing CATALOG_REPOSITORY and CATALOG_DEPLOY_KEY configuration.
The catalogue repository's existing Pages deployment serves the editor too.

Merge these files through the normal PR flow, then check Actions → Publish
catalogue to server repository. Manual Run workflow on main is also available.
No extra Pages site or secrets are needed when catalogue publishing is configured.

Expected URL after successful deployment:
https://nani-samireddy.github.io/praise-catalog/song-editor/

Drafts are tied to the browser origin, so localhost drafts do not migrate to
the hosted site. Publishing also validates the catalogue before copying files.

### Other static hosts or a separate repository

Copy this folder into its own repository, or configure a static host with
`song-editor` as its root/output directory. Cloudflare Pages: no framework,
no build command, output `.` when this folder is the project root. GitHub Pages:
publish the folder contents at the root of the selected publishing branch.
All asset paths are relative, so subpath hosting works. No mobile release needed.
Include index.html, style.css, chords.css, mobile.css, app.js, format.js, chords.js and transliterate.js for hosting.

On phones the editor uses one column, with Edit lyrics and Preview & export
shortcuts. Preview scrolls with the page; inputs use 16px text and buttons have
44px minimum touch targets. Desktop retains the two-column preview.

## English transliteration

Telugu titles and arranged lyrics automatically produce editable Latin-script
text locally, using the app's readable transliteration convention. This is
transliteration, not translation. Review spellings before publishing. English
edits are preserved until Regenerate is chosen; review them after lyric changes.
Repeats and chord markers survive conversion. Export English transliteration
alone or use Full draft JSON for both languages.

## Adding chords

Place the cursor before a lyric syllable, enter a chord such as D, F#m or G/B,
and choose Add chord at cursor. Inline markers like `[D]` can also be typed,
edited or deleted directly. The preview displays chords above lyric segments,
including each expanded repeat. Chords move with the text during phrase splits.
Insertion snaps to grapheme boundaries to preserve Telugu combining characters.

Choose Chord chart to copy/download inline notation for the `chord_chart` field.
Full draft JSON includes it too. Normalized and app lyrics exports omit valid
chord markers. The web editor does not publish chord data or add mobile rendering.
Key/capo metadata and transposition are not implemented yet. Unknown bracketed
text is preserved as text; validate the chart in the catalogue pipeline.
