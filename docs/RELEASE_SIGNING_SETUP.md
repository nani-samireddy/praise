# Android Release Signing Setup

Praise uses one long-term Android signing identity for its Play and GitHub APK
distribution channels. Provide this key to Play App Signing when the app is
created so installations from GitHub and Play retain a compatible application
identity.

## Local files

Release builds read `android/key.properties`:

```properties
storeFile=release-keystore.jks
storePassword=REPLACE_WITH_STORE_PASSWORD
keyAlias=praise-release
keyPassword=REPLACE_WITH_KEY_PASSWORD
```

The referenced keystore is `android/release-keystore.jks`. Both files are
ignored by Git and must never be committed.

Create and verify the key with the JDK `keytool` command. Use a strong unique
password, a long validity period, and the alias `praise-release`.

After creation:

1. Keep the working copy outside Git history.
2. Back up the keystore and credentials in two encrypted locations.
3. Keep one backup offline.
4. Record the SHA-256 certificate fingerprint privately.
5. Never send the keystore or passwords through chat, email, or an issue.

## GitHub Actions secrets

The `release.yml` workflow requires these secrets in the `praise` repository:

| Secret | Value |
| --- | --- |
| `ANDROID_RELEASE_KEYSTORE_BASE64` | Base64 representation of the complete keystore file |
| `ANDROID_RELEASE_STORE_PASSWORD` | Keystore password |
| `ANDROID_RELEASE_KEY_ALIAS` | `praise-release` |
| `ANDROID_RELEASE_KEY_PASSWORD` | Private-key password |

Generate the base64 value in PowerShell without changing the keystore:

```powershell
$bytes = [System.IO.File]::ReadAllBytes("android\release-keystore.jks")
[Convert]::ToBase64String($bytes) | Set-Clipboard
```

Add the secrets under **praise > Settings > Secrets and variables > Actions**.
The workflow reconstructs the signing files only for the release job and
removes them in an `always()` cleanup step.

## Production environment

Create a GitHub Actions environment named `production`. Add required reviewers
when another trusted maintainer becomes available. Signing secrets may remain
repository secrets for V1 or be moved into that protected environment.

## Local release verification

```powershell
flutter build apk --release
# Confirm that java --version reports Java 17 or later before invoking Gradle.
Push-Location android
.\gradlew.bat :app:bundleRelease
Pop-Location
python tool\verify_android_artifacts.py `
  --apk build\app\outputs\flutter-apk\app-release.apk `
  --aab build\app\outputs\bundle\release\app-release.aab
```

The direct Gradle bundle command temporarily avoids a Flutter 3.47 Windows
post-build validation regression. The Gradle task still performs the normal
release bundle, optimization, native-symbol, and signing work; the verification
script then requires the native application, Flutter, and SQLite libraries for
every supported ABI.

Verify that both builds succeed and that the APK reports:

```text
package: com.nanisamireddy.praise
application-label: Praise
```

## Play enrollment

For the first Play release, choose the option to provide the existing app
signing key rather than letting Play create an unrelated key. Follow Play's
secure export/import process. Do not upload the raw keystore through an
unsupported form.

If the project later adopts a separate Play upload key, keep the long-term app
signing key for GitHub APKs and configure the release workflow to use the upload
key only for AAB generation.
