# Praise — AppSheet Catalogue Workflow

## Purpose

Praise should let trusted editors maintain songs in Google Sheets through an
AppSheet editor UI, then publish reviewed catalogue updates to the separate
GitHub Pages catalogue repository without running a permanent application
server.

This workflow keeps Google Sheets as the editorial source, GitHub Actions as
the build worker, and GitHub Pages as the mobile app's static download server.

## Ownership

| System | Owns | Does not own |
| --- | --- | --- |
| Google Sheets | Editorial rows, review state, draft metadata | Mobile sync state |
| AppSheet | Editor forms, validation hints, review actions | Final JSON generation |
| App repository | Build scripts, validators, workflow definitions | Published static hosting |
| Catalogue repository | `catalog/manifest.json` and `catalog/songs.json` | Secrets or editorial drafts |
| Mobile app | Local cache, custom songs, favourites, lists | Editorial workflow |

## Sheet structure

Use one canonical `Songs` sheet with these columns:

| Column | Required | Notes |
| --- | --- | --- |
| `source_id` | Yes | Stable editorial ID. Never reuse for a different song. |
| `title` | Yes | Telugu or primary-language title. |
| `english_title` | No | English title. |
| `body` | Yes | Canonical primary lyrics body. |
| `english_body` | No | Canonical English lyrics body. |
| `author` | No | Author or source attribution. |
| `male_video_url` | No | YouTube URL for a male practice version. |
| `female_video_url` | No | YouTube URL for a female practice version. |
| `status` | Yes | `draft`, `needs_review`, `approved`, or `published`. |
| `review_notes` | No | Editor-visible notes. Not shipped to the app. |
| `catalogue_version` | No | Filled after publishing. Editors do not need to set this. |
| `updated_at` | Yes | AppSheet-maintained timestamp. |
| `updated_by` | Yes | Editor identity from AppSheet. |

Future optional columns can include `chord_chart_json`.
Columns that are not part of the mobile schema must be stripped during the
catalogue build.

## AppSheet app

The AppSheet app should provide:

- an editor form for draft song entry;
- read-only generated IDs after creation;
- validation hints for missing titles, empty bodies, and unsupported repeat
  markers;
- a review view filtered to `status = needs_review`;
- an approval action that changes `status` to `approved`; and
- a deploy switch exposed only to maintainers.

The deploy switch should not directly edit GitHub Pages. It should trigger a
GitHub Actions workflow in the app repository with a maintainer-scoped token.
The workflow is the only component that converts sheets into release JSON. If
the deploy request does not provide a catalogue version, the workflow publishes
the next version after the checked-in manifest only when approved catalogue
content changed.

## Deploy switch flow

```mermaid
sequenceDiagram
    actor Editor
    participant AppSheet
    participant Sheets as Google Sheets
    participant Actions as GitHub Actions
    participant AppRepo as Praise app repo
    participant CatRepo as praise-catalog repo
    participant Mobile as Mobile app

    Editor->>AppSheet: Review and approve songs
    AppSheet->>Sheets: Save approved rows
    Editor->>AppSheet: Turn on Deploy
    AppSheet->>Actions: repository_dispatch or workflow_dispatch
    Actions->>Sheets: Read approved rows
    Actions->>AppRepo: Normalize and validate catalogue
    Actions->>AppRepo: Build manifest and songs JSON
    Actions->>AppRepo: Commit generated catalogue state
    Actions->>CatRepo: Push changed catalog/ files
    Mobile->>CatRepo: Refresh manifest
    Mobile->>Mobile: Apply newer snapshot locally
```

## GitHub Actions design

Create a workflow such as `.github/workflows/import-sheet-catalog.yml`.

The workflow should:

1. fetch the `Songs` sheet through a configured HTTPS CSV export endpoint;
2. authenticate with an optional bearer token when the endpoint is protected;
3. keep only rows with `status = approved` or `status = published`;
4. map `source_id` through the existing `tool/catalog_id_map.json`;
5. normalize lyrics using the canonical format rules;
6. run catalogue validation and review warning generation;
7. publish the supplied catalogue version, or automatically reuse the current
   version for unchanged content and increment it for changed content;
8. build `docs/catalog/songs.json` and `docs/catalog/manifest.json`;
9. commit `docs/catalog`, `assets/data/songs.json`,
   `catalog/source/songs.normalized.csv`, and `tool/catalog_id_map.json` back
   to the app repository so source IDs stay stable; and
10. publish the static output to `nani-samireddy/praise-catalog`.

Secrets required in the app repository:

| Name | Type | Purpose |
| --- | --- | --- |
| `CATALOG_REPOSITORY` | Actions variable | Existing target repository, for example `nani-samireddy/praise-catalog`. |
| `SONGS_SHEET_CSV_URL` | Actions variable | HTTPS CSV export URL for the approved catalogue sheet. |
| `CATALOG_DEPLOY_KEY` | Actions secret | Existing private deploy key for the catalogue repository. |
| `SHEET_EXPORT_TOKEN` | Actions secret | Optional bearer token for a protected CSV export endpoint. |

## Manual workflow trigger

Run **Import catalogue from Google Sheets** from GitHub Actions with:

- `catalogue_version`: optional; leave blank to publish the next version;
- `sheet_csv_url`: optional override. Leave blank to use `SONGS_SHEET_CSV_URL`.

This should be the first production test because it verifies sheet import,
catalogue build, validation, and GitHub Pages publishing without involving
AppSheet automation.

## AppSheet webhook trigger

After the manual workflow is reliable, configure the AppSheet deploy action as
an automation webhook that calls GitHub's repository dispatch endpoint:

```text
POST https://api.github.com/repos/nani-samireddy/praise/dispatches
```

Headers:

```text
Accept: application/vnd.github+json
Authorization: Bearer YOUR_FINE_GRAINED_GITHUB_TOKEN
X-GitHub-Api-Version: 2026-03-10
Content-Type: application/json
```

Body:

```json
{
  "event_type": "catalog_deploy",
  "client_payload": {
    "source": "appsheet"
  }
}
```

If the sheet URL needs to vary per environment, include `sheet_csv_url` in the
payload. Otherwise store it once as the `SONGS_SHEET_CSV_URL` Actions variable.
If a maintainer wants to force a specific version, include
`catalogue_version`; normal AppSheet deploys should omit it and let GitHub
Actions choose the correct version.

The GitHub token used by AppSheet should be fine-grained and limited to the app
repository. It needs permission to call repository dispatch for Actions. Do not
store the catalogue deploy private key in AppSheet.

## Safety rules

- A deploy only publishes approved rows.
- A changed catalogue must increase `catalogueVersion`.
- Generated app IDs remain stable through `tool/catalog_id_map.json`.
- The import workflow commits the updated ID map back to the app repository
  before publishing.
- The workflow fails before publishing if validation or checksum generation
  fails.
- Review notes, editor emails, draft rows, and AppSheet metadata are never
  shipped to the mobile app.
- The mobile app still treats downloaded catalogue JSON as untrusted input.
- Custom songs, favourites, and lists remain local and are never sent to
  Google Sheets.

## Implementation phases

1. Create the Google Sheet columns and AppSheet editor/review views.
2. Use `tool/import_sheet_catalog.py` to convert exported sheet data into the
   existing normalized CSV shape.
3. Run tests for required columns, status filtering, ID stability, and version
   validation.
4. Use `.github/workflows/import-sheet-catalog.yml` with manual
   `workflow_dispatch` first.
5. Wire the AppSheet deploy action to the workflow's `repository_dispatch`
   trigger after manual publishing succeeds.
6. Add optional sheet write-back of published version and status later if
   editors need it.

The first deploy path should be manually triggered from GitHub Actions. The
AppSheet switch becomes a convenience after the build is proven repeatable.
