# Installing Quicksilver with SideStore (owner steps)

Target: iPhone 16e running iOS 27. This page is the **local, diagnostic-only** path: the owner builds on their own Mac with no CI and no signing. The cloud path (Actions → Archive IPA) may sign when signing secrets are configured; it and the first-run checklist are in `Documentation/SIDESTORE.md`.

## 1. Build an unsigned IPA locally (Mac)
Needs Xcode (latest stable) and XcodeGen (`brew install xcodegen`). No Apple certificate or profile is needed.

```sh
git checkout main && git pull
scripts/build-unsigned-ipa.sh                 # archive from source (Release, unsigned)
# or, from an archive or device .app you already have:
scripts/build-unsigned-ipa.sh --archive ~/Library/Developer/Xcode/Archives/…/Quicksilver.xcarchive
scripts/build-unsigned-ipa.sh --app path/to/Release-iphoneos/Quicksilver.app
```

The script:
- refuses a simulator `.app`
- strips any leftover signature
- writes `build/ipa/Quicksilver-<version>-<build>-unsigned.ipa`
- prints its SHA-256 and the commit — only for a clean from-source build; `--archive`/`--app` or a dirty tree print `unverified`

This output identifies a local test build only; it is not CHR-55 evidence.

## 2. Get the IPA onto the iPhone
AirDrop it to the phone and save it to Files (or use iCloud Drive).

## 3. Install with SideStore
1. Open SideStore. Make sure its pairing and the on-device VPN/LocalDevVPN are active, as SideStore requires.
2. **My Apps → +**, then pick the IPA from Files.
3. SideStore re-signs it with your Apple ID and installs it. Free accounts last 7 days; refresh in SideStore before they expire.
4. Installing over an existing Quicksilver keeps its data, as long as the bundle ID (`com.quicksilver.app`) is unchanged.

## 4. Accept (CHR-55)
Acceptance requires the IPA from the **Actions → Archive IPA** workflow artifact, not a local build from this page. Install that artifact, run the first-run checklist in `Documentation/SIDESTORE.md` on the phone, and record:
- the workflow run URL, the artifact's IPA SHA-256 and its commit
- the iOS build number
- screenshots of the Sanctum, an on-device answer in airplane mode, and the Codex
- a diagnostics export (Codex → Export diagnostics; it holds no content) once #327 lands

CHR-55 closes only with this real device evidence from the workflow artifact. A locally built IPA is diagnostic only.

## Troubleshooting
- **"Not a device build":** you passed a `Debug-iphonesimulator` app. Archive or build for `generic/platform=iOS`.
- **App crashes on launch after a SideStore refresh:** reinstall the same IPA, then attach a diagnostics export to the issue.
- **Too many apps on a free account:** SideStore allows three sideloaded apps at once. Remove one, or use an app-ID slot you already have.
