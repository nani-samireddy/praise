# Praise

Praise is an Android-first, offline-first Flutter application for browsing,
reading, and organizing Christian song lyrics.

The project is currently in the planning and foundation stage. Product scope,
technical boundaries, and the proposed delivery sequence are documented here:

- [Product requirements](docs/PRD.md)
- [Technical architecture](docs/ARCHITECTURE.md)
- [Implementation notes](docs/IMPLEMENTATION_NOTES.md)

## Planned stack

- Flutter and Material 3
- Riverpod
- Drift and SQLite
- Dio
- GoRouter
- Freezed and json_serializable

## Current state

The offline library now seeds 20 songs and supports local search, favorites,
custom-song CRUD, automatic My Songs membership, user-defined list management,
song ordering, persistent themes and reading preferences, and pinch-to-resize
lyrics. Manual server synchronization remains the main planned V1 phase.

## Baseline commands

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```
