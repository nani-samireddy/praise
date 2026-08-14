# Separate GitHub Pages Catalogue Server

The Flutter application repository is the catalogue source of truth. A push to
its `main` branch runs `.github/workflows/publish-catalog.yml`, validates the
checked-in catalogue, and synchronizes `docs/catalog/` into `catalog/` in a
separate GitHub repository.

The server repository contains only static files. It has no application
runtime, database, billing account, or scheduled maintenance.

## One-time GitHub setup

1. Create a public repository for the server, for example
   `nani-samireddy/praise-catalog`. Initialize it with a README so that its
   `main` branch exists.
2. In the server repository, open **Settings > Pages**. Select **Deploy from a
   branch**, then choose `main` and `/(root)`.
3. Generate a dedicated ED25519 key pair. When prompted for a passphrase, press
   Enter twice to leave it empty because the key is used by GitHub Actions:

   ```powershell
   ssh-keygen -t ed25519 -C "praise-catalog-publisher" -f "$env:TEMP\praise_catalog_deploy"
   ```

4. In the server repository, open **Settings > Deploy keys > Add deploy key**.
   Paste the contents of `praise_catalog_deploy.pub`, name it
   `Praise catalogue publisher`, and enable **Allow write access**.
5. In the application repository, open **Settings > Secrets and variables >
   Actions**:
   - Add a repository variable named `CATALOG_REPOSITORY` with the value
     `OWNER/REPOSITORY`, for example `nani-samireddy/praise-catalog`.
   - Add a repository secret named `CATALOG_DEPLOY_KEY` containing the complete
     private `praise_catalog_deploy` file, including its BEGIN and END lines.
6. Delete both temporary key files after GitHub has stored them:

   ```powershell
   Remove-Item -LiteralPath "$env:TEMP\praise_catalog_deploy", "$env:TEMP\praise_catalog_deploy.pub"
   ```

7. Push the application repository's `main` branch or manually run **Publish
   catalogue to server repository** under the Actions tab.

The published manifest URL is:

```text
https://nani-samireddy.github.io/praise-catalog/catalog/manifest.json
```

Use that URL for application builds:

```powershell
flutter build apk
```

The production URL is the app default. A `CATALOG_MANIFEST_URL` dart-define is
needed only when intentionally overriding it for development or staging.

## Publishing behavior

- Every push to the application repository's `main` branch runs validation and
  synchronization.
- Only the destination repository's `catalog/` directory is replaced. Its
  README and other root files are preserved.
- The workflow creates a commit only when the published catalogue changed.
- The destination commit records the source application repository and short
  commit SHA.
- The deploy key is scoped to the one server repository and does not expire.

If the server repository protects `main` against direct pushes, allow this
deploy key to push or publish through an unprotected deployment branch instead.
