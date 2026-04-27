# Releasing your Hex fork

This is the step-by-step guide for taking this codebase, branding it as your own, and shipping signed + notarized DMGs to end users.

If you just want a personal build that runs on your own Mac, you don't need any of this — see the "Level 1" section in earlier setup docs (Xcode → ⌘R with your free Apple ID team is enough). This doc is for **distribution to other users**.

For the existing upstream-Hex release process, see [release-process.md](release-process.md). This doc focuses on the fork-specific changes you need to make.

---

## What's currently real vs aspirational

The upstream repo's CLAUDE.md mentions a `bun run tools/src/cli.ts release` orchestrator. **That CLI does not exist in this checkout** — only the changeset author script (`tools/scripts/add-changeset.ts`) is present. Likewise, the `.github/workflows/README.md` describes `ci.yml`, `build-and-release.yml`, and `release.yml` workflows that aren't actually committed.

Your options:

- **Manual release** (works today): the checklist in [Step 6](#step-6--manual-release-checklist) below. ~30 min per release once set up.
- **Add GitHub Actions** (recommended for ongoing distribution): the template in [Step 7](#step-7--github-actions-workflow-template) below. ~1 hour to set up, then push a tag and walk away.

Either way, you go through Steps 1–5 once.

---

## Prerequisites

- **Apple Developer Program membership** ($99/yr) — required for Developer ID Application certificate, which is the only way to ship outside the Mac App Store without users seeing scary "unidentified developer" dialogs. https://developer.apple.com/programs/
- **An Apple ID + app-specific password** for notarization. Generate at https://appleid.apple.com/account/manage → "App-Specific Passwords".
- **A place to host the DMG and Sparkle appcast** — an S3 bucket, GitHub Releases + GitHub Pages, Cloudflare R2, or any static-hosted directory served over HTTPS.
- **Sparkle CLI tools** for the EdDSA keypair: `brew install --cask sparkle` (gives you `generate_keys` and `sign_update`).
- Xcode 16+, the project building cleanly with your team in Signing & Capabilities.

---

## Step 1 — Brand your fork

Search-replace the upstream identifiers across the project. From the repo root:

```bash
# Pick your reverse-DNS bundle id, e.g. com.example.YourApp
OLD_BUNDLE_ID="com.enginecy.voixe"
NEW_BUNDLE_ID="com.example.YourApp"

# Replace the bundle id everywhere (Info.plist, entitlements, project.pbxproj)
git grep -l "$OLD_BUNDLE_ID" | xargs sed -i '' "s|$OLD_BUNDLE_ID|${NEW_BUNDLE_ID}|g"

# Confirm only your new string remains
git grep -n "$OLD_BUNDLE_ID" || echo "All references migrated"
```

Files that should now contain only your bundle id:

- `Hex/Info.plist`
- `Hex/Hex.entitlements`
- `Hex.xcodeproj/project.pbxproj` (every `PRODUCT_BUNDLE_IDENTIFIER`)
- `HexCore/Sources/HexCore/StoragePaths.swift` (the `com.enginecy.voixe` directory name — this is where settings + models live; changing it means existing installs are treated as fresh, which is what you want for a fork)
- `Hex/Hex.swift` (the `XDG_CACHE_HOME` path used for Parakeet)

Replace the app icon by dropping your icon set into `Hex/AppIcon.icon/`. Update the display name in `Hex/Info.plist` (`CFBundleDisplayName`, `CFBundleName`) if you want something other than "Hex".

Update `package.json` `name` to your fork name.

---

## Step 2 — Apple Developer signing

In Xcode → Hex target → **Signing & Capabilities**:

- **Automatically manage signing**: ON.
- **Team**: pick your paid Apple Developer team (not the free Personal Team — that one is fine for local development but can't notarize).

Then store notarization credentials in your keychain. Run once:

```bash
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "your@email.com" \
  --team-id "YOURTEAMID" \
  --password "abcd-efgh-ijkl-mnop"
```

The `AC_PASSWORD` profile name is what later commands reference.

---

## Step 3 — Sparkle keypair

Sparkle verifies updates by signing each DMG with an EdDSA keypair you generate once and embed the public half into Info.plist. Lose the private half and you can't ship updates anymore.

```bash
# Generate (writes to ~/Library/Application Support/Sparkle/...)
generate_keys

# Print the public key
generate_keys -p
```

In `Hex/Info.plist`, replace:

- `SUFeedURL` with your appcast URL, e.g. `https://updates.example.com/hex/appcast.xml`
- `SUPublicEDKey` with the public key you just printed

Back up the private key somewhere safe (1Password vault, encrypted USB drive, etc.). It does not live in the repo.

---

## Step 4 — Add the MLX dependency (one-time, only if you want bundled refine)

Without this, the Refine feature only works in Ollama mode and shows a clear setup error in bundled mode.

In Xcode:

1. **File → Add Package Dependencies**.
2. URL: `https://github.com/ml-explore/mlx-swift-examples`.
3. When the product picker appears, link **MLXLLM** and **MLXLMCommon** to the **Hex** target.
4. ⌘B to verify.

This adds ~80 MB to the resulting `.app` bundle (the MLX framework + its dependencies). Worth it for end users who don't have Ollama installed.

---

## Step 5 — Pick a hosting strategy

Two common options:

### Option A — S3 + CloudFront

Same as upstream. Create a bucket, e.g. `hex-fork-updates`. Make it public-readable. Set up CloudFront if you want a custom domain. The release workflow will upload `Hex-X.Y.Z.dmg`, `hex-latest.dmg`, and `appcast.xml` here.

You'll need AWS credentials with `s3:PutObject` for the bucket. Either:

- Personal IAM user with an access key (set `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` in your shell or GitHub Secrets), or
- IAM role with OIDC if using GitHub Actions (more secure, no long-lived credentials).

### Option B — GitHub Releases + GitHub Pages (no AWS)

Cheaper and simpler. The DMG goes to a GitHub Release; the appcast.xml lives in a `gh-pages` branch served by GitHub Pages.

- DMG URL: `https://github.com/YOU/yourfork/releases/download/v0.7.4/Hex-0.7.4.dmg`
- Appcast URL: `https://YOU.github.io/yourfork/appcast.xml`

Update `SUFeedURL` in Info.plist accordingly.

---

## Step 6 — Manual release checklist

Until/unless you set up CI (Step 7), this is the minimal sequence per release. Run from repo root.

```bash
# 1. Verify you're on a clean main with the version you want
git status
VERSION="0.7.4"

# 2. Create a changeset for any user-facing changes (one or more)
bun run changeset:add-ai patch "Refine model auto-downloads on first enable"

# 3. Bump version in Hex/Info.plist (CFBundleShortVersionString and CFBundleVersion)
#    Hand-edit, or use the snippet below.
plutil -replace CFBundleShortVersionString -string "$VERSION" Hex/Info.plist
NEW_BUILD=$(($(plutil -extract CFBundleVersion raw Hex/Info.plist) + 1))
plutil -replace CFBundleVersion -string "$NEW_BUILD" Hex/Info.plist

# 4. Archive
xcodebuild archive \
  -scheme Hex \
  -configuration Release \
  -archivePath build/Hex.xcarchive \
  -skipMacroValidation

# 5. Export signed .app
cat > build/ExportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath build/Hex.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/ExportOptions.plist

# 6. Notarize the .app (zip it first because notarytool needs an archive)
ditto -c -k --keepParent build/export/Hex.app build/Hex.app.zip
xcrun notarytool submit build/Hex.app.zip \
  --keychain-profile AC_PASSWORD \
  --wait
xcrun stapler staple build/export/Hex.app

# 7. Build DMG
hdiutil create \
  -volname "Hex" \
  -srcfolder build/export/Hex.app \
  -ov \
  -format UDZO \
  build/Hex-${VERSION}.dmg

# 8. Notarize and staple the DMG
xcrun notarytool submit build/Hex-${VERSION}.dmg \
  --keychain-profile AC_PASSWORD \
  --wait
xcrun stapler staple build/Hex-${VERSION}.dmg

# 9. Sign the DMG for Sparkle (EdDSA signature goes into appcast.xml)
SPARKLE_SIG=$(sign_update build/Hex-${VERSION}.dmg)
echo "Sparkle signature: $SPARKLE_SIG"

# 10. Generate appcast.xml — see template below

# 11. Upload to your bucket (or attach to GitHub Release)
aws s3 cp build/Hex-${VERSION}.dmg s3://hex-fork-updates/Hex-${VERSION}.dmg --acl public-read
aws s3 cp build/Hex-${VERSION}.dmg s3://hex-fork-updates/hex-latest.dmg --acl public-read
aws s3 cp build/appcast.xml s3://hex-fork-updates/appcast.xml --acl public-read

# 12. Tag and push
git add Hex/Info.plist
git commit -m "Release ${VERSION}"
git tag v${VERSION}
git push origin main --tags

# 13. Create GitHub Release
gh release create v${VERSION} build/Hex-${VERSION}.dmg \
  --title "Hex ${VERSION}" \
  --generate-notes
```

### Minimal appcast.xml template

Drop this in `build/appcast.xml`, swapping in the values from the run above:

```xml
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>Hex</title>
    <item>
      <title>Hex 0.7.4</title>
      <pubDate>Sun, 27 Apr 2026 12:00:00 +0000</pubDate>
      <sparkle:version>{NEW_BUILD}</sparkle:version>
      <sparkle:shortVersionString>0.7.4</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <enclosure
        url="https://updates.example.com/hex/Hex-0.7.4.dmg"
        sparkle:edSignature="{SPARKLE_SIG_FROM_STEP_9}"
        length="{DMG_SIZE_BYTES}"
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
```

For multiple historical releases, repeat the `<item>` block. Sparkle reads the latest `pubDate` and offers it to anyone on a lower `sparkle:version`.

---

## Step 7 — GitHub Actions workflow template

Copy the file at `tools/templates/release.yml` into `.github/workflows/release.yml` to automate Steps 6.4 onward whenever you push a `v*` tag.

You'll need these GitHub repository secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
|---|---|
| `MACOS_CERTIFICATE` | Base64 of your `Developer ID Application` `.p12` (`base64 -i cert.p12 \| pbcopy`) |
| `MACOS_CERTIFICATE_PWD` | Password you set when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Any random string, used for the temporary CI keychain |
| `DEVELOPMENT_TEAM` | Your 10-char Apple team ID |
| `APPLE_ID` | Your Apple Developer email |
| `APPLE_ID_PASSWORD` | The app-specific password from Step 2 |
| `SPARKLE_PRIVATE_KEY` | Contents of `~/Library/Application Support/Sparkle/.../Private Key`, base64-encoded |
| `AWS_ACCESS_KEY_ID` | Only if uploading to S3 |
| `AWS_SECRET_ACCESS_KEY` | Only if uploading to S3 |

Once set up, your release flow becomes:

```bash
# Add a changeset
bun run changeset:add-ai minor "Cool new feature"

# Bump version in Info.plist, commit, push tag
git tag v0.7.5 && git push --tags

# CI does the rest. Watch the run at github.com/YOU/yourfork/actions
```

The end user gets the new version through Sparkle automatically the next time they launch the app.

---

## Troubleshooting

- **"Developer cannot be verified"** on launch → notarization didn't staple. Re-run `xcrun stapler staple` on both the .app inside the DMG and the DMG itself.
- **"Hex would like to access [microphone/accessibility/input monitoring]"** loops on every launch → bundle id changed without granting permissions to the new id. Open System Settings → Privacy & Security and re-grant under the new bundle.
- **Sparkle: "Update is improperly signed"** → `SUPublicEDKey` in Info.plist doesn't match the private key that signed the DMG. Re-sign with the right key or update Info.plist and re-release.
- **Sparkle: no update found** → check the appcast URL is reachable in a browser, the `sparkle:version` is higher than what's installed, and the `pubDate` is in the past.
- **Bundled refine "MLX runtime is not compiled in"** → you skipped Step 4. Add the SPM dependency and re-build.
- **`notarytool submit` succeeds but app still shows Gatekeeper warnings** → the notarization log probably has `Hardened Runtime: false` or a missing `--options runtime` flag. Check `xcrun notarytool log <submission-id>`.

---

## Apple-specific gotchas

- **Hardened runtime** is required for notarization. The Hex target already has it on (look in build settings for `ENABLE_HARDENED_RUNTIME = YES`).
- **App Sandbox** is on. Adding new entitlements (e.g. for a feature that needs unsandboxed access) means re-justifying with Apple. Try to avoid.
- **Apple Silicon only**: the project builds arm64 only. Adding x86_64 means rebuilding all the SPM dependencies as universal, which is non-trivial. Don't bother unless you actually have Intel users.
- **App Store distribution**: Sparkle is incompatible with the Mac App Store (Apple disallows third-party update mechanisms). If you want both channels, you'd need a separate target with App Store-specific entitlements and no Sparkle. Out of scope for this guide.

---

## What changes when ms-only end users use the bundled app

For your future users:

1. They download `Hex-X.Y.Z.dmg` from your release URL.
2. Drag Hex.app to /Applications. Open. macOS no longer warns (because notarized).
3. Grant mic + accessibility + input monitoring on first launch — the onboarding wizard walks them through this.
4. Pick a transcription model in Settings → it downloads in the background.
5. Toggle Refine on → if you added the MLX dep in Step 4, the default refine model auto-downloads. Otherwise they get a clear "switch to Ollama or contact developer" message.
6. Use the hotkey. Everything is local.
7. Sparkle delivers the next version automatically when you push another tag.

That's it. No terminal, no Xcode, no SPM clicks for end users.
