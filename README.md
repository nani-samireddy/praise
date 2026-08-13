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

The first offline vertical slice is implemented: the app seeds 20 songs from a
local JSON catalogue, stores them with Drift/SQLite, supports local title and
author search, and provides a bilingual song reader. Favorites, custom songs,
lists, settings, and server synchronization remain planned work.

## Baseline commands

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```
