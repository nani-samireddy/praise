# UI/UX QA — 12 October 2026

Baseline: `b1251cc`; isolated branch `codex/accessibility-qa`. This is a
host/widget review, not a hardware release sign-off. The untracked original
`APP_AUDIT_2026-10-12.md` was read before creating the worktree. No AGENTS.md
was found in the project/parent search. Other implementation branches own
onboarding, search, controls, local photo saving, drafts, sharing/imports and reading mode.

## Repeatable checks

Run from the repository root:

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter test test/qa
PRAISE_QA_EXPORT_DIR=/tmp/praise-qa-export flutter test test/qa/export_boundaries_test.dart
pdfinfo /tmp/praise-qa-export/long-bilingual.pdf
pdftoppm -scale-to 1200 -png /tmp/praise-qa-export/long-bilingual.pdf /tmp/praise-qa-export/page
```

`ui_qa_fixture.dart` provides deterministic Riverpod overrides without opening
SQLite or touching local user data. Its reusable viewports are 320×568,
568×320 and 1024×768, at device pixel ratio 1 and 200% text. Card and bilingual
reader tests cover both light/dark Material 3 themes, long Telugu and English
text, bounded layout, scrolling, favorite selected state, labels and Android
48 logical-pixel targets. The long export test checks multi-page generation and
oversized-image rejection. These checks do not establish Telugu glyph shaping,
contrast, TalkBack traversal or full-screen usability. Reader goldens load the
real bundled NotoSansTelugu font (including English) and were visually reviewed
at 320×568 / 200% in both themes. Regenerate only with intentional visual
changes using `flutter test --update-goldens test/qa/reader_golden_test.dart`;
pin Flutter 3.47.7 / Dart 3.13.5 and macOS for these baseline images. Existing tests cover
custom editing, list dialogs/detail/add-to-list, reader interactions, import
codec and export content; they are not full visual/accessibility coverage.

## Review and defect log

| ID | Area / reproduction | Evidence / status | Acceptance after integration |
| --- | --- | --- | --- |
| QA-01 | Onboarding, 320×568, 200% | Audit reproduced overflow; source still has centered non-scrollable Column. Owned by onboarding branch. | Scroll to every role and Continue; selected role announced; no overflow in landscape/keyboard. |
| QA-02 | Songs/Favorites/Lists song card favorite | FavoriteButton has tooltip but previously no explicit selected state. Fixed here with Material IconButton selected state and a separate semantic container. | Favorite action remains separate from opening song; announce selected and action, persist on toggle. |
| QA-03 | Settings change role | Audit router redirect blocks completed users; enum spelling exposed. Owned by onboarding branch. | Settings → Change role → Save works; readable Worship leader label. |
| QA-04 | Import confirmation | Source shows only list name/count; invalid links silently return. Sharing/import branch owns fix. | Focus enters preview; actual matched/missing songs announced; Cancel writes nothing. |
| QA-05 | Photo PDF plus typed/English text | Source `_buildPhotoSongPdf` includes title, details, image and footer, omitting lyric bodies. Sharing branch owns fix. | Preview accurately describes output and includes chosen content. |
| QA-06 | Export reader preferences | Export uses fixed typeface/font sizes. Source confirmed; options branch owns behavior. | Preview matches selected language/content; do not imply chords/transpose are included if absent. |
| QA-07 | Share anchoring | Source passes nullable Rect through song/list services; song screen uses RenderBox origin. Actual popover/native share sheet unverified. | All entry points provide finite non-empty on-screen origin on tablet/rotation, no crash. |
| QA-08 | Focus/contrast/photo labels | Paste and refresh have tooltips; camera/gallery/native controls and full traversal need hardware review. No pass claimed. | Follow checklist below; attach screenshots/traversal notes and defect IDs. |
| QA-10 | PDF accessibility | Poppler reports untagged PDF. Visual rendering does not prove accessible document reading order. | Assess exported text selection/reading order in PDF screen reader; document supported behavior. |
| QA-11 | Local photo-only scope | Baseline photo flow still contains recognition UI; removal belongs to photo branch and is not verified in this isolated checkout. | Integrated camera/gallery, lost-picker recovery, durable images, create/edit/replace/remove and cancel/draft checks pass; no active extraction, model, quota or Scan/OCR controls. |
| QA-09 | Long PDF boundaries | MultiPage divides lyrics at blank paragraphs; a very large uninterrupted paragraph remains a boundary-risk requiring dedicated review. | No missing lines, orphan section headings, clipped header/footer, malformed Telugu or unexpected empty pages. |

Do not count an expected defective behavior assertion as an acceptance pass.
Do not silently disable new failures after integrating another branch.

## Physical Android / TalkBack checklist (NOT EXECUTED)

Record commit, APK/AAB hash, model, Android version, TalkBack version, display
size/font scale, locale, installation channel and screenshots for each run.
Use a spare/test profile with synthetic data, plus an upgrade test with existing
favorites/lists/custom songs/photos/notes/settings. Preserve production data.

1. Install via Play internal testing; launch offline and online. Verify seed,
   permission denial and restart retain user data. Compare direct and Play internal
   track installation without assuming either proves online provider behavior.
2. Enable TalkBack. Traverse onboarding forward/backward: heading, instructions,
   Singer, Musician, Worship leader, Continue. Choose each role; verify selected
   state, no decorative-icon noise, reachable Continue and unchanged focus after
   rotation. Repeat completed-user Settings change-role flow.
3. Songs/search: toolbar → search → clear → first result → favorite → remaining
   results → bottom destinations. Type Telugu/English and rapid query changes,
   scroll while loading, verify retained results/retry and meaningful empty state.
   Long title must remain fully spoken even when visually ellipsized. Search
   clear and favorite must not activate the parent result.
4. Favorites: toggle from reader/card and return; search, clear and empty states.
   Lists: create/rename, add/remove/reorder, system list, empty list, long title.
   Verify reorder is usable without dragging for TalkBack; report if absent.
5. Reader: title/back/favorite/share/controls/lyrics/notes in logical order.
   Telugu and English, bilingual/line-by-line/repeats, text selection, max size,
   dark/light, controls expanded/collapsed, pinch and keyboard focus. Rotate and
   return from background; reading position must be stable. Check relevant music
   controls and no misleading availability on unarranged songs.
6. Settings: headings, role, switches and their on/off states, font/theme/display
   selections, refresh busy/error/completion announcements, reachable support.
7. Custom/photo: verify camera and gallery entry points have distinct labels and
   adequate targets. Deny permissions, cancel picker and simulate process death;
   lost-picker recovery must restore the pending image without duplicate songs.
   Save a photo-only song; restart offline and verify its durable private image
   remains readable after the picker/cache source is removed. Add optional manual
   Telugu/English text and preserve it through Save, edit, back and cancellation.
8. Photo lifecycle/accessibility: edit a saved photo-only song; replace and remove
   its photo, then cancel or save each operation. Cancel must preserve the previous
   persisted photo/text; Save must apply exactly the reviewed change. Test new and
   existing-song draft recovery/discard, including retained photos and interrupted
   saves. Preview must expose a meaningful photo description, labeled replace/remove
   actions, reachable zoom/back controls and sensible focus return. Repeat with
   200% text, both themes, rotation and a small phone. Local photo saving and manual
   entry must work without internet. Verify the integrated active flow has no text
   extraction/recognition buttons, model downloads, provider quota/reset displays
   or misleading Scan/OCR wording. Recognition and model benchmarking are deferred
   product work, not release acceptance; no provider/model setup is needed.
9. Preview/share: song and list, text/image/PDF, photo-plus-text, language options,
   oversized-image PDF alternative; cancel leaves data intact. On tablet and
   landscape verify share origin/popover placement, screen-reader dismissal and
   return focus. Open every exported PDF; review first, boundary and final pages,
   including a 100-stanza song and a song without blank lines.
10. Imports: warm/cold app link, fresh onboarding, invalid/oversized link, duplicate
    IDs, missing songs, all missing and cancel/confirm. Preview must match imported
    songs and announce failures without losing context.

Repeat steps 2–10 in light/dark, 100%/200% font, smallest supported phone,
landscape and tablet. Use Android Accessibility Scanner for targets/contrast,
then manually inspect Telugu marks, line breaks, truncation, dialogs/bottom
sheets and keyboard behavior. Minimum targets: 48×48 logical pixels; normal
text contrast ≥4.5:1, large text ≥3:1. Automated widget checks are supplementary.

## Integration rerun gate

After all seven implementation branches land in a dedicated integration checkout,
record its commit and rerun formatting, analyzer, the complete Flutter suite and
`test/qa`. Extend the shared fixture to each changed screen with fake repository
states (loading/data/empty/error), selected controls, focus traversal and keyboard
insets. Extend/review full-screen goldens with real bundled Telugu fonts on a pinned
Flutter/OS runner; avoid approving Ahem glyph snapshots as Telugu validation.
Resolve QA-01/03/04/05/06 with acceptance tests supplied by their owners, and probe
QA-07/08/09/11 on device/rendered artifacts. Re-render exports after any content-model
change. Perform the physical checklist using the integrated Play build, attach
evidence, and keep unresolved defects visible before release sign-off.

## Host evidence for this branch

The 100-stanza bilingual PDF generated 13 A4 pages. Poppler rendered pages 1, 2,
9 (English section boundary), and 13 (final); those inspected pages showed visible
Telugu text, contained content and separated footers. This sampling is not a
complete glyph-accuracy or every-page sign-off. PDF metadata reports `Tagged: no`;
PDF screen-reader reading order is therefore unverified and should be assessed
separately from visual rendering. The renderer rejected the same document as an
oversized single image. No physical Android, TalkBack, Play checks
were executed. Review artifacts are reproducible via the opt-in command above.

Verified branch checks: `dart format --output=none --set-exit-if-changed lib test`
passed (96 files, zero changes); `flutter analyze --no-pub` passed with no issues;
`flutter test --no-pub` passed all 115 tests, including 17 new QA checks. The
focused `flutter test --no-pub test/qa` also passed all 17. Earlier exploratory
semantics/golden runs failed while the fixture was being corrected; the final
suite used the reviewed real-font goldens and passed. No production data,
network service, model download or provider credentials were used by these tests.

Scope update: local photo saving and manual entry supersede both offline and
online recognition plans. Existing baseline recognition tests/results above
are historical checks of this branch, not acceptance for the new flow. After
integrating the photo branch, use fakes for camera/gallery cancellation, lost
picker data, durable file copying and draft persistence; assert no extraction,
model-download or quota widgets are present in the create/edit/preview screens.
Search active presentation/routes for `scan`, `OCR`, `extract`, `Gemma`, `Gemini`,
`Tesseract` and quota terminology, review each match in context, then check visible
strings and semantic labels on device. Historical documentation and deferred
benchmark notes may mention recognition; they must not appear as active actions.
