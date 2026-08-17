# Praise support API

This stateless service accepts structured feedback from Praise, creates an issue
in `nani-samireddy/praise`, and returns the public issue number and URL. GitHub
credentials remain on the server and are never included in the Android app.

## Render setup

1. Create a fine-grained GitHub personal access token scoped only to
   `nani-samireddy/praise`, with repository **Issues: Read and write**. Do not
   give it Contents or Administration write access.
2. In Render, create a Blueprint from this repository using `render.yaml`.
3. Set the prompted `GITHUB_TOKEN` secret in Render.
4. Confirm `https://praise-support-api.onrender.com/health` returns
   `{"status":"ok"}`.
5. Submit one test report from Praise and confirm the returned issue link.

The free Render service can sleep after inactivity, so the first submission may
take about one minute. No database or persistent disk is required because
GitHub stores the issues.

## Local checks

```powershell
python -m unittest discover -s support_api/tests -p "test_*.py"
$env:GITHUB_TOKEN = "REPLACE_WITH_FINE_GRAINED_TOKEN"
$env:GITHUB_REPOSITORY = "nani-samireddy/praise"
python support_api/server.py
```

Never commit the token or send it through chat, email, logs, or an issue.
