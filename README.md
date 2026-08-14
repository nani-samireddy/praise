# Praise

Praise is an Android-first, offline-first Flutter application for browsing,
reading, and organizing Christian song lyrics.

The project is currently in the planning and foundation stage. Product scope,
technical boundaries, and the proposed delivery sequence are documented here:

- [Product requirements](docs/PRD.md)
- [Technical architecture](docs/ARCHITECTURE.md)
- [Implementation notes](docs/IMPLEMENTATION_NOTES.md)
- [Canonical lyrics format](docs/LYRICS_FORMAT.md)
- [Bundled font licenses](docs/FONT_LICENSES.md)
- [Separate catalogue server setup](docs/CATALOG_SERVER_SETUP.md)

## Planned stack

- Flutter and Material 3
- Riverpod
- Drift and SQLite
- Dio
- GoRouter
- Freezed and json_serializable

## Current state

The offline library seeds all 1,374 normalized songs and supports local search,
favorites, custom-song CRUD, automatic My Songs membership, user-defined list
management, song ordering, persistent reading preferences, formatted repeat
cues, copy/share actions, pinch-to-resize lyrics, and five persistent Telugu
typeface choices (system plus four bundled Google Fonts families). A versioned
GitHub Pages catalogue provides manual snapshot synchronization without a
maintained application server.

## Baseline commands

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Normal builds use the production catalogue automatically:

```powershell
flutter run
```

Override the catalogue only for development or staging:

```powershell
flutter run --dart-define=CATALOG_MANIFEST_URL=https://example.test/catalog/manifest.json
```

Catalogue publishing is intentionally separated from the application
repository. After the one-time GitHub configuration, every push to `main`
validates and synchronizes the static catalogue to its dedicated GitHub Pages
repository. See [Separate catalogue server setup](docs/CATALOG_SERVER_SETUP.md).
