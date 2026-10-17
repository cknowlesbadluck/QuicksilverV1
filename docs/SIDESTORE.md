# Installing Quicksilver with SideStore (owner steps)

Target: iPhone 16e running iOS 27. Everything here is done by the owner on their own Mac and phone; CI never signs. For the cloud path (the Archive IPA workflow) and the first-run checklist, see `Documentation/SIDESTORE.md`.

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
- prints its SHA-256 and the commit

Keep that output: it's the evidence for which build went onto the phone.

## 2. Get the IPA onto the iPhone
AirDrop it to the phone and save it to Files (or use iCloud Drive).

## 3. Install with SideStore
1. Open SideStore. Make sure its pairing and the on-device VPN/LocalDevVPN are active, as SideStore requires.
2. **My Apps → +**, then pick the IPA from Files.
3. SideStore re-signs it with your Apple ID and installs it. Free accounts last 7 days; refresh in SideStore before they expire.
4. Installing over an existing Quicksilver keeps its data, as long as the bundle ID (`com.quicksilver.core`) is unchanged.

## 4. Accept (CHR-55)
Run the first-run checklist in `Documentation/SIDESTORE.md` on the phone. Record:
- the IPA SHA-256 and commit
- the iOS build number
- screenshots of the Sanctum, an on-device answer in airplane mode, and the Codex
- a diagnostics export (Codex → Export diagnostics; it holds no content) once #327 lands

CHR-55 closes only with this real device evidence.

## Troubleshooting
- **"Not a device build":** you passed a `Debug-iphonesimulator` app. Archive or build for `generic/platform=iOS`.
- **App crashes on launch after a SideStore refresh:** reinstall the same IPA, then attach a diagnostics export to the issue.
- **Too many apps on a free account:** SideStore allows three sideloaded apps at once. Remove one, or use an app-ID slot you already have.
