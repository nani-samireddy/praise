# Performance reading mode

Opt in from the reader's “Enter performance mode” action or a list's “Perform this list” action. Exit with the close button or system Back. The ordinary reader stays mounted beneath this route, preserving its reader state; list navigation pushes rather than replacing list pages. No database migration or preference writes are introduced.

## Integration boundaries

- `song_detail_screen.dart`: one optional collection ID and one entry action. Musical controls, sharing, notes, and videos are unchanged.
- `router.dart`: `/perform/:id?list=…` route plus forwarding list context into the ordinary reader.
- `collection_detail_screen.dart` and `song_list_card.dart`: pass the list ID on reader navigation; list entry starts at the first song in stored order, independent of search filtering.
- New `features/performance/presentation` owns the focused reader, per-song in-session scroll offsets, temporary font size, capability status, and native keep-awake lifecycle.

List order comes from the existing Drift-backed Riverpod stream. Reordering immediately changes neighbors; first/last controls disable without wrapping. Missing or removed current IDs never silently select a replacement. An explicit “Continue from first song” action recovers when there are remaining songs. Empty/deleted lists leave exit available and navigation disabled. Loading/error order disables navigation; retry is available for errors.

The focused reader uses the song's plain lyric bodies through existing Telugu/repeat and bilingual renderers and the saved language/typeface/size defaults. Font changes are temporary (16–48). It includes saved photos, with an unavailable-file fallback. Arrangement/chord controls, videos, notes, and sharing remain in the ordinary reader; there is no automatic audio or media initialization in performance mode.

## Keep-awake

`wakelock_plus` 1.8.1 is a maintained Flutter Community screen-wake plugin. Existing Android AGP/Kotlin/Gradle versions meet its documented requirements. No new permission is required. This feature invokes native keep-awake only on Android; other platforms report unavailability and continue reading. Missing plugin/native errors are also visible. A user can turn keep-awake off without leaving the mode.

Native enable/disable calls are serialized, including disposal, so delayed enable completion is followed by release. Inactive, hidden, paused, and detached states release it; resume reacquires it only if the user has kept it enabled. Both Back and Exit dispose the session. No CPU/background wakelock is requested.

## Validation

Automated: analyzer, formatting, focused session/widget tests, and existing collection-detail widget regression. Tests use injected wake fakes, not physical screen-sleep behavior. Coverage includes lifecycle release/resume, opt-out persistence within the session, delayed-enable cleanup, capability failure, live reorder/removal, boundary states, per-song scroll restoration, temporary sizing, system Back, explicit Exit, missing song, and disposal.

Physical Android validation remains: screen stays on beyond the configured timeout only during performance mode; sleep returns after Exit/Back/background; resume and manual opt-out behave correctly; native capability failure is understandable. Check long Telugu titles, photo songs, TalkBack focus/labels, 200% text, landscape and tablets. No physical-device QA or Android build is claimed.
