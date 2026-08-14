# Praise — Product Requirements Document

## Document status

- Product: Praise
- Platform: Flutter, Android-first
- Release: Version 1
- Status: Draft for implementation
- Last updated: 2026-08-13

## 1. Product summary

Praise is an offline-first Christian song lyrics application. It gives worship
leaders, church members, and ministry teams a fast, readable song library that
continues to work without an internet connection.

The installed catalogue is stored locally. Users can search and read songs,
mark favourites, create their own songs, and organize songs into custom lists.
An explicit refresh action downloads catalogue changes from a remote service
without overwriting user-created content.

## 2. Problem statement

Churches and worship teams often need lyrics in locations with slow, unstable,
or unavailable connectivity. General-purpose lyrics websites depend on a live
connection, while note-taking apps do not provide song-oriented search,
favourites, or set lists.

Praise should make the most important workflow—finding and reading a song—fast
and dependable regardless of network availability.

## 3. Product principles

1. Offline by default: downloaded and bundled lyrics remain usable without a
   network connection.
2. Local data is authoritative for the UI: screens render from the device
   database, not directly from API responses.
3. User data is protected: catalogue refreshes never overwrite custom songs,
   favourites, or lists.
4. Readability comes first: lyrics typography and navigation are more important
   than decorative UI.
5. Sync is understandable: the user chooses when to refresh and can see the
   latest successful refresh time.
6. V1 stays focused: authentication and cloud synchronization are deferred.

## 4. Target users

### Worship leader

Needs to find lyrics quickly, collect songs for a service, and continue working
inside church buildings with unreliable connectivity.

### Church member

Wants a personal library of favourite songs with comfortable, adjustable text.

### Ministry team member

Needs to enter locally used songs that are not in the shared catalogue and
organize them for meetings or events.

## 5. Goals and success criteria

### V1 goals

- Provide a useful catalogue immediately after first installation.
- Support offline browsing, title search, and lyric reading.
- Persist favourites, custom songs, lists, and settings across restarts.
- Refresh server-managed songs on demand.
- Preserve all user-managed data when refreshing the catalogue.
- Provide light and dark themes with accessible, scalable lyrics text.

### Product success criteria

- A seeded song can be opened without a network connection after installation.
- Search results update from local data without an API request.
- A failed refresh leaves the existing catalogue fully usable.
- A custom song survives a refresh that modifies or deletes server songs.
- Core screens remain usable with large system text settings.

## 6. V1 scope

### 6.1 Song library

The Songs screen shall:

- display active server and custom songs from local storage;
- show the primary title and optional English title;
- support offline search by either title or author;
- indicate custom songs;
- allow favourites to be toggled from the list;
- expose pull-to-refresh without hiding cached content; and
- provide an action for creating a custom song.

### 6.2 Song detail

The song reader shall:

- display the primary title and optional English title;
- display the primary body and optional English body while preserving line
  breaks;
- preserve stanza and line breaks;
- allow the song to be favourited;
- allow the song to be added to a custom list;
- allow the complete bilingual song to be copied as readable plain text;
- allow the complete bilingual song to be shared through the platform share
  sheet;
- allow custom songs to be edited or deleted;
- use the configured lyrics font size and Telugu typeface;
- visually separate structural labels and repeat cues from the lyric line that
  follows them; and
- remain readable in light and dark themes.

### 6.3 Favourites

Users shall be able to:

- favourite or unfavourite server and custom songs;
- browse favourites as a separate local view; and
- retain favourites across restarts and catalogue refreshes.

If a server song is deleted by a refresh, it shall no longer appear in the
active favourites view. Its stale favourite relationship may be removed safely
by the database relationship or cleanup transaction.

### 6.4 Custom songs

Users shall be able to:

- create a song with title, optional English title, body, optional English
  body, and optional author;
- edit and delete their own songs;
- favourite custom songs; and
- add custom songs to lists.

Custom songs shall be identified as locally owned and shall never be updated or
deleted by catalogue synchronization.

### 6.5 Lists

Users shall be able to:

- create, rename, and delete a list;
- view songs in a list;
- add or remove server and custom songs;
- prevent duplicate songs in the same list; and
- reorder songs within a list.

Example list names include Sunday Worship, Youth Meeting, Christmas, and Prayer
Meeting.

### 6.6 Catalogue synchronization

Synchronization shall begin only after a user refresh action from Songs or
Settings.

The refresh workflow shall:

1. Read the locally stored catalogue version.
2. Download the static catalogue manifest.
3. Download the complete snapshot only when its version is newer.
4. Validate the checksum, count, identifiers, and complete response.
5. Apply server-song upserts and soft deletions in a database transaction.
6. Preserve custom songs and locally managed relationships.
7. Record the version and successful refresh time only after success.
8. Let database streams update visible screens.

During refresh, cached data shall remain visible. Failure shall produce a
non-blocking, understandable message and shall not change the last-successful
sync timestamp.

### 6.7 Initial catalogue

The application shall bundle a JSON catalogue at
`assets/data/songs.json` containing the complete release catalogue. On first
launch, it shall import the bundle and record its seed version. When an app
release raises that seed version, it shall safely upsert the newer bundle.
Bundled imports shall never overwrite custom songs or user-managed lists.

### 6.8 Settings

V1 settings shall include:

- lyrics font size;
- Telugu typeface: system, Noto Sans Telugu, Noto Serif Telugu, Mandali, or
  Ramabhadra;
- theme preference: system, light, or dark;
- latest successful catalogue sync time; and
- a manual catalogue refresh action.

## 7. Navigation

Primary navigation uses four destinations:

1. Songs
2. Favourites
3. Lists
4. Settings

Expected routes:

| Route | Purpose |
| --- | --- |
| `/songs` | Searchable local song library |
| `/songs/:id` | Song reader |
| `/favorites` | Favourite songs |
| `/lists` | Custom lists |
| `/lists/:id` | Songs in a list |
| `/custom-song/new` | Create a custom song |
| `/custom-song/:id/edit` | Edit a custom song |
| `/settings` | Local preferences and sync status |

## 8. Empty, loading, and error states

The application shall provide useful states for:

- no songs found for a search;
- no favourite songs yet;
- no custom lists yet;
- an empty list;
- initial database setup;
- refresh in progress;
- offline or network failure;
- invalid server response; and
- a requested song that no longer exists.

Database-backed screens may show a loading state while their first local query
resolves. A catalogue refresh shall not replace loaded content with a full-page
spinner.

## 9. Non-functional requirements

### Reliability

- All core reading and organization workflows must function offline.
- Catalogue changes must be applied atomically.
- Failed sync and malformed responses must not corrupt cached data.

### Performance

- Local title search should feel immediate for the expected catalogue size.
- Long song lists must use lazy list rendering.
- Database columns used for search, filters, ordering, and sync should be
  indexed where useful.

### Accessibility

- Respect platform text scaling without clipping primary actions.
- Give icon-only controls semantic labels and tooltips.
- Maintain sufficient colour contrast in both themes.
- Do not use colour as the only indicator of state.

### Privacy and security

- V1 does not require an account or collect personal information.
- API traffic should use HTTPS outside local development.
- Server responses are untrusted input and must be validated before persistence.
- Logs must not include full user-created lyrics unless explicitly enabled for
  local debugging.

### Compatibility

- Android is the primary supported platform.
- The Flutter codebase should remain portable to iOS where practical.
- The API base URL must be supplied through build-time configuration rather
  than hard-coded production values.

## 10. Out of scope for V1

- Authentication and user accounts
- Cloud backup or synchronization of user data
- Importable or shareable lists
- QR import or export
- Community submissions and moderation
- Transliteration
- Chords and chord transposition
- Audio playback or references
- Worship presentation integration
- Song arrangement or version history
- Automatic background synchronization
- Full-text lyrics search

These features should not be implemented speculatively, but the V1 design must
avoid choices that make them unnecessarily difficult later.

## 11. V2 committed scope

### Shareable lists

V2 shall let a user share a complete song list without requiring an account or
a maintained application server.

- A list can be exported as a versioned Praise list package.
- The package can be sent through the platform share sheet.
- Another Praise installation can open, preview, and import the package.
- Catalogue songs are matched using stable song identifiers rather than titles.
- Import creates local identifiers and never overwrites an existing list or
  custom song silently.
- Duplicate and missing songs are summarized before the user confirms import.
- Invalid or unsupported package versions fail safely with a readable message.
- A readable plain-text list can also be shared with recipients who do not use
  Praise.

### Share formats

V2 shall expand sharing for both individual songs and complete lists:

| Content | Text | Image | PDF | Importable Praise package |
| --- | --- | --- | --- | --- |
| Song | Yes | Yes | Yes | No |
| List | Yes | Yes | Yes | Yes |

- Text remains optimized for copying, messaging, and recipients without Praise.
- Image export creates a readable share card or long image using the selected
  language content and display typography.
- PDF export preserves titles, authors, song order, lyric structure, page
  breaks, and Telugu font rendering.
- The user previews the output and chooses Telugu, English, or bilingual content
  before sharing when translations are available.
- Generation happens on the device and uses the platform share sheet; no
  upload service is required.
- Oversized image output offers PDF instead of generating an unreadable or
  unstable image.

The first V2 implementation remains asynchronous and offline-first. Live list
collaboration, accounts, public list hosting, and cloud conflict resolution are
not included unless separately approved.

The package policy for custom-song lyrics, including explicit user consent and
rights messaging, must be decided before implementation.

## 12. V1 acceptance checklist

- [x] Fresh install seeds the bundled catalogue exactly once.
- [x] Songs can be browsed and opened in airplane mode.
- [x] Primary title, English title, and author search use only local data.
- [x] Favourite state survives an application restart.
- [x] A custom song can be created, edited, deleted, favourited, and listed.
- [x] Lists can be created, renamed, deleted, populated, and reordered.
- [x] Refresh inserts and updates server songs.
- [x] Refresh hides server songs absent from the snapshot.
- [x] Refresh never modifies custom songs.
- [x] Failed refresh preserves cached data and the previous sync timestamp.
- [x] Lyrics font size and theme preferences persist.
- [x] Analyzer, automated tests, and an Android debug build pass.

## 13. Open product decisions

The following can be decided during implementation without blocking the initial
architecture:

- Whether server-deleted songs are soft-deleted or physically removed.
- The content ownership and publication approval process.
- Minimum and maximum lyrics font sizes.
- Whether search ignores punctuation and diacritics in V1.
