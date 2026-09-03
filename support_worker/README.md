# Praise Cloudflare support worker

This worker receives anonymous support submissions from the Praise app and posts
them into Discord for review. It keeps the current app API contract:

```http
POST /v1/issues
```

returns:

```json
{ "number": 123456789, "url": "https://discord.com/channels/..." }
```

The app treats the returned URL as the user's tracking/reference link.

## Endpoints

- `GET /health` returns `{"status":"ok"}`.
- `POST /v1/issues` accepts:
  - `song_request`
  - `song_correction`
  - `problem_report`
- `POST /v1/catalog/deploy` queues the Google Sheets catalogue import workflow.

## Deploy from GitHub Actions

The app repository includes `.github/workflows/deploy-support-worker.yml`.
It deploys this Worker automatically when `main` receives changes under
`support_worker/**`.

Add these repository secrets in GitHub:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

Then add the Discord webhook URLs as Cloudflare Worker secrets:

```powershell
cd support_worker
npx wrangler secret put DISCORD_SONG_REQUESTS_WEBHOOK_URL
npx wrangler secret put DISCORD_APP_REPORTS_WEBHOOK_URL
npx wrangler secret put APPSHEET_DEPLOY_TOKEN
npx wrangler secret put GITHUB_DISPATCH_TOKEN
```

`DISCORD_SONG_REQUESTS_WEBHOOK_URL` receives song requests and song
corrections. `DISCORD_APP_REPORTS_WEBHOOK_URL` receives app problem reports.
`DISCORD_WEBHOOK_URL` is still supported as a fallback for older deployments.

If you want a separate deployment branch, change the workflow trigger from:

```yaml
branches: [main]
```

to something like:

```yaml
branches: [cloudflare]
```

Then configure your Cloudflare deployment/source to watch that same branch. For
this repo, the recommended v1 setup is `main` plus the existing path filter,
because only support worker changes trigger the Worker deployment.

## Manual deploy

```powershell
cd support_worker
npm install
npx wrangler login
npx wrangler secret put DISCORD_SONG_REQUESTS_WEBHOOK_URL
npx wrangler secret put DISCORD_APP_REPORTS_WEBHOOK_URL
npx wrangler secret put APPSHEET_DEPLOY_TOKEN
npx wrangler secret put GITHUB_DISPATCH_TOKEN
npx wrangler deploy
```

Optional shared rate limiting:

```powershell
npx wrangler kv namespace create PRAISE_SUPPORT_RATE_LIMIT
```

Then copy the generated namespace id into `wrangler.toml`:

```toml
[[kv_namespaces]]
binding = "RATE_LIMIT"
id = "..."
```

## Discord setup

1. Create private `#song-requests` and `#app-reports` channels.
2. Create one webhook for each channel.
3. Store the `#song-requests` webhook URL as
   `DISCORD_SONG_REQUESTS_WEBHOOK_URL`.
4. Store the `#app-reports` webhook URL as
   `DISCORD_APP_REPORTS_WEBHOOK_URL`.
5. Optionally keep `DISCORD_WEBHOOK_URL` only as a fallback.
6. Deploy the Worker.
7. Confirm:

```powershell
Invoke-WebRequest https://YOUR_WORKER_URL/health
```

## AppSheet deploy webhook

Create a random deploy token and store the same value in AppSheet and the
Worker secret `APPSHEET_DEPLOY_TOKEN`.

Create a fine-grained GitHub token for only the app repository with
`Contents: Read and write` permission. GitHub requires that permission for the
repository dispatch API. Store the token only as the Worker secret
`GITHUB_DISPATCH_TOKEN`.

Configure AppSheet to call:

```text
POST https://praise-support.nanisamireddy05.workers.dev/v1/catalog/deploy
```

Headers:

```text
Authorization: Bearer YOUR_APPSHEET_DEPLOY_TOKEN
Content-Type: application/json
```

Body:

```json
{
  "source": "appsheet"
}
```

Optional body fields:

```json
{
  "source": "appsheet",
  "catalogue_version": "12",
  "sheet_csv_url": "https://docs.google.com/spreadsheets/d/.../export?format=csv"
}
```

## App configuration

The app default is configured in:

```text
lib/core/config/app_config.dart
```

For release builds, either keep the default Worker URL after deployment or pass:

```powershell
flutter build appbundle --release `
  --dart-define=FEEDBACK_API_URL=https://YOUR_WORKER_URL/v1/issues
```

## Next step

This worker is intentionally only the intake and deploy-trigger layer. Discord
review buttons, Google Sheets writes, and AI formatting can be added later.
