# Praise — Implementation Notes

## 1. Purpose

This document turns the PRD and architecture into an executable delivery plan.
It should be updated as implementation decisions are made. It is not a progress
log; durable design changes belong here or in a focused architecture decision
record.

## 2. Current repository state

The repository now contains the Phase 1 application foundation and the first
Phase 2 vertical slice: Drift persistence, a versioned 20-song seed catalogue,
local title/author search, the Songs screen, and the bilingual song reader.
Favorites, custom-song editing, lists, settings, and remote sync remain pending.

The directory is not currently initialized as a Git repository. Initialize Git
before substantive implementation if version history is desired.

## 3. Delivery strategy

Build vertical slices that remain runnable. Each phase should finish with
formatting, static analysis, relevant tests, and an Android debug build where
platform code or dependencies changed.

Do not postpone all testing until the final phase. Add repository and service
tests alongside the behavior they protect.

## 4. Phase 1 — Application foundation

### Work

- Replace the counter application with `ProviderScope` and `MaterialApp.router`.
- Add stable SDK-compatible dependencies:
  - `flutter_riverpod`
  - `drift` and Flutter SQLite support
  - `dio`
  - `go_router`
  - `freezed_annotation` and `json_annotation`
  - `uuid`
- Add generator development dependencies:
  - `build_runner`
  - `drift_dev`
  - `freezed`
  - `json_serializable`
- Create the feature-first directory structure.
- Add Material 3 light and dark themes.
- Configure the four-branch navigation shell.
- Add `AppConfig` with `API_BASE_URL` from `String.fromEnvironment`.
- Replace the default widget test with an application-level smoke test.

### Exit criteria

- The app starts on the Songs destination.
- All four primary destinations are navigable.
- No widget accesses the database or Dio directly.
- `flutter analyze` and the smoke test pass.

## 5. Phase 2 — Database and offline song library

### Work

- Define Drift tables, constraints, foreign keys, and initial indexes.
- Enable SQLite foreign key enforcement at database open.
- Create version 1 schema and migration strategy.
- Create an in-memory database constructor for tests.
- Add and register `assets/data/songs.json`.
- Implement transactional, marker-based one-time seeding.
- Implement `SongRepository` and its providers.
- Build the searchable Songs screen from a Drift stream.
- Build song detail with readable stanza-preserving typography.
- Add repository tests for seeding and primary title, English title, and author
  search.

### Notes

- Store all timestamps as UTC and convert only for display.
- Trim user-entered fields before persistence.
- Keep search query parameters bound; do not concatenate raw SQL.
- Escape `%` and `_` if user text is used in a SQL `LIKE` pattern and Drift
  does not handle that for the selected query API.
- Exclude `is_deleted = true` rows from normal song queries.

### Exit criteria

- A fresh database imports the bundle once.
- Seeded songs remain available without a network connection.
- Primary title, English title, and author search are local and reactive.
- Song detail handles missing/deleted IDs gracefully.

## 6. Phase 3 — Favourites and custom songs

### Work

- Implement `FavoritesRepository` and reactive providers.
- Add favourite toggles to song list and detail screens.
- Build the Favourites screen and its empty state.
- Build a reusable custom-song form with validation.
- Implement custom song create, edit, and delete operations.
- Restrict custom-song mutations to `source = custom` records.
- Add confirmation before destructive deletion.
- Add persistence and CRUD tests.

### Suggested form validation

- Title: required after trimming.
- English title: optional.
- Body: required after trimming.
- English body: optional.
- Author: optional.

The submit action should prevent duplicate submissions and preserve the form
after a recoverable failure.

### Exit criteria

- Favourite state is consistent on Songs, Detail, and Favourites screens.
- A custom song survives restart and all repository sync tests.
- Server songs cannot enter the custom edit flow.

## 7. Phase 4 — Lists

### Work

- Implement list CRUD and list-detail queries.
- Add an add-to-list sheet from song detail.
- Support removal and transactional reordering.
- Normalize sort orders after reorder or deletion.
- Add empty states and deletion confirmation.
- Test duplicate prevention, cascade behavior, and ordering.

### Reordering approach

Within one transaction, assign the ordered membership rows sequential values
such as `0, 1, 2...`. Do not rely on floating-point gaps for V1. The expected
list sizes are small enough for a straightforward update.

### Exit criteria

- Lists retain membership and order across restarts.
- The same song cannot be added twice to one list.
- Deleting one list does not delete its songs or other lists.

## 8. Phase 5 — Remote catalogue sync

### Work

- Configure one Dio client with base URL, connect timeout, and receive timeout.
- Create strict remote DTOs and JSON serialization.
- Implement a remote catalogue data source.
- Implement `SyncService` with a single-flight guard.
- Apply validated changes in one Drift transaction.
- Add pull-to-refresh and a Settings refresh action.
- Display last successful sync time.
- Map network, response, database, and sync failures.
- Test the complete sync matrix with a fake remote data source.

### Required sync test matrix

| Case | Expected result |
| --- | --- |
| New server song | Inserted and emitted by local stream |
| Existing server song | Updated from server values |
| Deleted server ID | Removed or hidden |
| Deleted ID matching custom song | Custom song unchanged |
| Server song ID matching custom row | Custom song unchanged; conflict reported or skipped |
| Malformed response | No database changes |
| Network failure | Cached content remains usable |
| Transaction failure | All catalogue changes rolled back |
| Any failed sync | Last sync timestamp unchanged |
| Successful empty delta | Server time recorded |

### Exit criteria

- Refresh never blocks access to cached content.
- Custom songs, favourites, and lists are preserved.
- Overlapping refresh attempts do not produce overlapping writes.
- All sync matrix tests pass.

## 9. Phase 6 — Settings, accessibility, and release polish

### Work

- Persist system/light/dark theme mode.
- Persist and apply lyrics font size.
- Verify layouts with large text scale and narrow Android devices.
- Add semantic labels and tooltips to icon actions.
- Review empty states and error messages.
- Add migration tests before any schema version increase.
- Run an airplane-mode integration test on Android.
- Create a release-oriented README with setup and run instructions.

### Exit criteria

- Preferences survive restart.
- Core actions remain accessible with large text.
- Static analysis, unit tests, widget tests, and Android build pass.
- PRD V1 acceptance checklist is complete.

## 10. Coding conventions

### General

- Prefer small, explicit classes and functions.
- Keep files focused; split a file when it contains multiple unrelated widgets
  or responsibilities.
- Use `const` widgets and values where practical.
- Avoid `dynamic` at persistence and network boundaries.
- Do not introduce a general abstraction until at least one real consumer needs
  it.

### Naming

- Providers end in `Provider`.
- Stream providers describe the value, such as `songsProvider`.
- Infrastructure implementations may use descriptive names such as
  `DriftSongRepository`; avoid `Impl` when a clearer name exists.
- Database-generated row models should not leak directly into remote DTOs.

### Async UI

- Handle loading, data, and error states explicitly.
- Check `context.mounted` after awaited work before using `BuildContext`.
- Disable or guard repeated destructive and submit actions.
- Use snack bars or inline messages for non-blocking failures.

### Database

- Wrap multi-table and ordered operations in transactions.
- Use foreign keys and uniqueness constraints as the final integrity boundary.
- Keep ownership checks in repository write queries, not only in widgets.
- Never update the schema without a migration and migration test.

## 11. Build and generation commands

Run from the project root:

```powershell
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

For active development with generated models:

```powershell
dart run build_runner watch --delete-conflicting-outputs
```

Run against a local API from an Android emulator:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Do not commit secrets through `--dart-define`; it is configuration, not secure
secret storage.

## 12. Test organization

Suggested structure:

```text
test/
├── core/
│   ├── database/
│   └── sync/
├── features/
│   ├── songs/
│   ├── favorites/
│   ├── collections/
│   └── custom_songs/
├── helpers/
│   ├── database.dart
│   └── fixtures.dart
└── widget_test.dart
```

Tests should create fresh isolated state and close database instances in
teardown. Avoid depending on test execution order or real network access.

## 13. Definition of done for each change

- Behavior matches the relevant PRD acceptance criteria.
- Persistent behavior has repository or service coverage.
- User-visible states include loading, empty, success, and failure as relevant.
- No raw Dio or Drift exception is exposed to the user.
- Generated files are current.
- Code is formatted.
- `flutter analyze` passes without warnings.
- Relevant tests pass.
- Documentation is updated when contracts or behavior changed.

## 14. Deferred implementation notes

Do not build V1 placeholders for authentication, cloud sync, sharing, chords,
audio, or presentation integration. When those features are approved, start
with explicit ownership and conflict-resolution requirements rather than
extending the catalogue sync path implicitly.
