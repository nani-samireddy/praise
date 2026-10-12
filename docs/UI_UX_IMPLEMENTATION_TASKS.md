# UI/UX implementation tasks

Created 12 October 2026. Each task has been dispatched to a separate Praise project chat with instructions to implement and verify its scope in an isolated managed worktree. Changes require integration and combined QA before release.

Latest scope update: task 4 now implements **local photo saving only**. Remove OCR, AI/text recognition, model downloads, online extraction and associated quota UI/backend work for now. Preserve camera/gallery selection, private durable photos, preview/replacement/removal, manual entry and draft recovery. Recognition is deferred until a concrete model is selected. This supersedes both the original offline/Play-model requirements and the intermediate online-Gemini/quota plan below. Tasks 5, 6 and 8 have been notified.

## 1. Accessible onboarding and role settings

Chat: 01a13128-36c4-7df2-9f21-08ad01295f79

Fix accessible onboarding and role personalization. Replace the centered non-scrollable StarterScreen Column with a layout that works at 320×568, 200% text, landscape, and constrained height/keyboard; keep Continue reachable and respect SafeArea. Add explicit selected semantics and keyboard/focus accessibility for role choices. Use friendly role labels everywhere, including “Worship leader” in Settings. Repair /starter?change=true routing after completed onboarding; preserve first-launch redirects and deliberate cancel/back behavior. Persist role/default-feature changes atomically and make the effect on existing custom switches explicit. Own starter_screen.dart, feature_flags.dart, router.dart and only the role section of settings_screen.dart. Test first launch, completed onboarding, change role, large text, and landscape. Deliver usable code and a short QA record.

## 2. Lyrics-first contextual musical controls

Chat: 01a13128-3a02-7472-8eab-7d6f24139fb5

Make the reader keep lyrics dominant and show musical controls only when relevant content exists. Audit chord/key/capo/harmony detection and distinguish user preference enabled from song content available. Keep controls collapsed initially and ordinary lyrics fully usable without arrangements. Do not imply all 1,374 songs have chords: only two bundled arrangement records were found. Hide or explain unavailable chord/transpose/capo/harmony controls accurately; keep metronome as an independently useful practice tool. Improve labels, active states, touch targets, and screen-reader semantics. Mark the already implemented controls-panel TODO accurately. Own the song-controls portion of song_detail_screen.dart, extracted controls widgets/helpers, structured_lyrics.dart as necessary, and docs/TODO.md. Avoid changing export actions or onboarding. Add tests for no arrangement, malformed data, chords without key, capo, harmony and role preferences. Document content-publication gaps separately rather than solving catalogue sync here.

## 3. Stable offline search and pagination

Chat: 01a13128-3cda-7f30-bd92-d7ad75c9c3d0

Implement stable offline search. Add a short debounce (roughly 200–300 ms), retain currently loaded results during query updates, display an unobtrusive searching state, and discard stale initial/page responses when the query or generation changes. Preserve loaded rows after load-more failure and offer inline retry. Centralize invalidation after catalogue sync and custom-song changes so Settings refresh cannot leave Songs stale. Add useful match context for English title or author without excessive decoration. Evaluate safe punctuation/Unicode normalization with Telugu preservation; implement only justified normalization and keep title/author search local, without server search or speculative FTS. Own songs_screen.dart, song_providers.dart, song_list_card.dart, relevant repository/database queries and sync-controller integration. Avoid Settings layout changes. Test rapid typing plus paging, stale response ordering, clear query, paging failure, return after CRUD, and refresh from Settings.

## 4. Clear photo OCR and optional AI workflow

Chat: 01a13128-40a3-7311-995f-60c573d6b159

Redesign photo scanning into clear Keep photo, Extract text, and optional Organize text choices. Allow OCR review and saving without waiting for model setup. Preserve original photos and recognized text on failures, cancellation and retries; retain Android image-picker lost-data recovery. Expose truthful AI capability/install requirements for a Play-delivered Gemma model versus sideloaded installs. Implement progress/state signals for downloaded bytes/total, downloading, waiting for Wi-Fi, cancel/retry and errors where supported by Play APIs; avoid fabricated percentages. Make the roughly 584 MB download optional and terms acceptance explicit. Own scan_song_screen.dart, song_scan_service.dart, native OCR/AI channel and SongStructuringService, and extracted workflow widgets. The editing-protection task owns generic custom_song_editor_screen lifecycle/draft handling: keep changes there minimal and clearly document any integration adapter. Test service states and OCR fallback using fakes; report native Play testing as pending unless actually run. Do not change model choice or send photos/text to a server.

## 5. Protect unsaved song edits and drafts

Chat: 01a13128-4480-7292-855e-ceb8562517a7

Protect work when editing existing custom songs. Inspect new-song draft storage and add recoverable edit drafts keyed to song identity, or a robust unsaved-change confirmation where recovery is impractical. Prefer recovery that survives app restarts with explicit restore/discard choices, preserving retained/replaced photos and cleaning only unreferenced draft files. Handle back navigation, scanning into an editor, saving, repeated saves, discard, errors, and externally deleted songs without overwriting newer saved content silently. Own local_song_draft.dart, custom_song_editor_screen.dart lifecycle/save/draft behavior and related image ownership logic/tests. Keep OCR/AI visual workflow in extracted components to ease integration with its separate task. Test create versus edit isolation, restart recovery, save cleanup, discard, image replacement, and failed save. Do not change catalogue ownership or require cloud storage.

## 6. Sharing and import previews

Chat: 01a13128-4831-7e20-8ae4-bd910269d923

Add understandable previews before sharing and importing. For song/list exports, preview selected language/content, list index versus full lyrics, whether a photo or accompanying text is included/omitted, and the oversized-image PDF alternative before the platform share sheet. Preserve Telugu rendering and existing sharing formats; ensure share-position origin works on larger screens. For import links resolve and display actual matching songs, ordered titles, missing/duplicate counts, and invalid-version feedback before confirmation; offer refresh/retry or explicit partial import without silent omission/overwrite. Align builder/parser size limits so the app cannot generate an unimportable link. Own collection_link_handler.dart, collection_link_codec.dart, sharing/export services/renderers, preview widgets, and repository import support. Avoid modifying unrelated reader controls; extract a reader action adapter if needed. Test missing/duplicate IDs, empty/oversized links, cancelled previews, photo-only and photo-plus-text exports, long-image fallback, and ordering. Do not publish external links or change remote hosting configuration.

## 7. Focused performance reading mode

Chat: 01a13128-4c31-7790-aa94-e597af3e7713

Implement and validate a focused performance-reading mode as a deliberate opt-in UX improvement. Inspect existing reader/list navigation first. Provide reversible keep-screen-awake only while this mode is active, clear exit behavior, accessible larger quick controls, stable song/list scroll state, and ordered next/previous navigation within a list. Preserve ordinary reader behavior and personal settings; do not start audio automatically. Handle missing/deleted songs, list reorder/update, first/last boundaries, back, route disposal and app background/resume. Own newly extracted performance-mode components/controller and list-to-reader context plumbing; avoid rewriting song-controls or share actions owned by other tasks. Use a narrow integration hook in song_detail_screen.dart/router.dart and explain it in the handoff. If a plugin is needed, select a maintained minimal dependency and implement Android-first capability handling. Test navigation/state/lifecycle and cleanup with fakes; clearly separate physical-device wakelock verification from widget tests.

## 8. Accessibility visual QA and regression coverage

Chat: 01a13128-4f72-7721-9a0c-a1f7392e2dd5

Perform an accessibility and visual QA pass across onboarding, Songs/search, Favorites, Lists, reader, Settings, custom-song/photo flow, export previews and imports. Add repeatable widget/golden/accessibility checks for semantics labels, selected state, focus order, touch targets, long titles, Telugu wrapping, dark/light modes, 200% text, small phone, landscape and tablet constraints. Review long PDF page boundaries and share-sheet anchoring; render representative exports where feasible using applicable artifact skills. Other tasks are actively improving the UI: work in an isolated worktree, prioritize reusable QA fixtures, tests and a clear defect log over overlapping production edits. Fix isolated accessibility problems only within this scoped branch. Record a reproducible physical Android/TalkBack and Play workflow checklist; do not claim hardware checks passed without executing them. Own new QA tests/fixtures and docs/UI_UX_QA.md. Run available checks and distinguish confirmed failures, fixes, and unverified device checks. Include a plan to rerun the suite after integration of all seven implementation branches.

