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

## Deploy from GitHub Actions

The app repository includes `.github/workflows/deploy-support-worker.yml`.
It deploys this Worker automatically when `main` receives changes under
`support_worker/**`.

Add these repository secrets in GitHub:

- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

Then add the Discord webhook URL as a Cloudflare Worker secret:

```powershell
cd support_worker
npx wrangler secret put DISCORD_WEBHOOK_URL
```

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
npx wrangler secret put DISCORD_WEBHOOK_URL
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

1. Create a private `#praise-support` or forum channel.
2. Create a webhook for that channel.
3. Store the webhook URL as the Worker secret `DISCORD_WEBHOOK_URL`.
4. Deploy the Worker.
5. Confirm:

```powershell
Invoke-WebRequest https://YOUR_WORKER_URL/health
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

This worker is intentionally only the intake layer. Discord review buttons,
Google Sheets writes, AI formatting, and GitHub catalogue deployment should be
added after the basic intake path is stable.
