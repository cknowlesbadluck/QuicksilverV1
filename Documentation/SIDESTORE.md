# Quicksilver → SideStore (iPhone-only path)

**Primary device:** iPhone 16e / **iOS 27**  
**Build floor (CI):** iOS 18.0 — the Archive workflow produces a binary that installs and runs on iOS 27.  
**Current ship:** 0.2.0 (**build 7**)  
**Goal:** Install Quicksilver via SideStore with zero Mac required.

> **Mandatory distribution path:** `Actions → Archive IPA → Run workflow` → download **Quicksilver-unsigned-IPA** → install in SideStore.  
> Fastlane / TestFlight (if present) is optional and never replaces this path.

## Why the deployment target is not 27.0 yet

GitHub-hosted `macos-15` runners currently ship Xcode with the iOS 18 SDK. Setting `IPHONEOS_DEPLOYMENT_TARGET = 27.0` would make every Archive job fail until an Xcode with the iOS 27 SDK is available on the runner. A lower deployment target is the standard, correct way to keep producing SideStore IPAs that still run on newer OS versions.

When CI gains an iOS 27 SDK, raise `Package.swift`, `project.yml`, and `AppConfiguration.minimumOSVersion` together.

## Prerequisites

1. SideStore (or SideStore + LiveContainer) already installed and working on the device.  
2. LocalDevVPN installed from the App Store and connected whenever you refresh or install.  
3. Free or paid Apple ID signed into SideStore.  
4. GitHub account that can trigger Actions on this repository.  
5. Device running **iOS 27** (or any version ≥ the build floor).

## Produce the IPA (cloud) — Unsigned path (no secrets needed)

1. On your iPhone, open the repository:  
   https://github.com/cknowlesbadluck/QuicksilverV1
2. Go to **Actions** → **Archive IPA** → **Run workflow**.
3. Choose configuration (`Release` recommended).
4. Wait for the job to finish (usually 4–8 minutes on macos-15 runners).
5. Download the artifact named **Quicksilver-unsigned-IPA**.

The workflow always builds for generic iOS device with code signing disabled and packages a proper unsigned IPA (`Payload/Quicksilver.app`). SideStore will re-sign it with your Apple ID when you install.

Post-build checks verify:
- `Quicksilver.app` exists
- Persona prompt files are present (or warn if missing)
- PrivacyInfo.xcprivacy is present (or warn)
- IPA contains `Payload/Quicksilver.app`
- Version/build banner is printed in the job log and as a GitHub notice

### Optional: Signed IPA (better reliability)

If you add these repository secrets (Settings → Secrets and variables → Actions), the same workflow will also produce a development-signed IPA:

| Secret | Purpose |
|--------|---------|
| `BUILD_CERTIFICATE_BASE64` | Base64 of your .p12 development certificate |
| `P12_PASSWORD` | Password for the .p12 |
| `BUILD_PROVISION_PROFILE_BASE64` | Base64 of the matching .mobileprovision |
| `TEAM_ID` | (optional) Your Apple Team ID |
| `KEYCHAIN_PASSWORD` | (optional) Temporary keychain password |

When secrets are present you get both artifacts: unsigned + signed.

## Install on device

1. Download the IPA artifact from the finished workflow run (on your iPhone).
2. Open SideStore (LocalDevVPN must be connected).
3. Use **+** / **Install IPA** (or the equivalent import flow) and select the downloaded Quicksilver IPA.
4. Trust the new developer profile if prompted (Settings → General → VPN & Device Management).
5. Launch Quicksilver.

## First-run checklist (iOS 27) — 0.2.0 build 7

1. Settings → paste your xAI API key → enable AI Service.
2. Sanctum / Home → confirm persona switcher, accent, and Nexus health.
3. Switch personas (Quicksilver / Forge / Eternal) — accent, density, and insight tone should change.
4. Enter Forge → Awaken Forge, capture a note, ask a constructive question.
5. Enter Eternal → Awaken Eternal, capture an observation, ask a reflective question.
6. Diagnostics → live signals + persona-toned insights.
7. Memory → policy label visible (threshold · scope · write); add a note, swipe delete, Clear All, Export.
8. Ask → persona-colored bubbles and send button; send a message with the active persona.
9. Shortcuts: Current Persona, Remember, Ask Nexus, Full Status (and any Slice C phrases if present).
10. Background the app 5–10 minutes, then return — state should survive.
11. Force-quit + relaunch → state intact.
12. Confirm no excessive battery drain while backgrounded.

## Refresh / reinstall

- SideStore certificates last 7 days on free Apple IDs.
- Keep LocalDevVPN connected and refresh Quicksilver from within SideStore before expiry.
- To update: trigger a new Archive IPA run, download the new IPA, install over the existing app in SideStore.

## Notes specific to this project

- Bundle ID: `com.quicksilver.app`
- Display name: Quicksilver (project may surface as Mercury in some places)
- Version: **0.2.0 (build 7)**
- No private APIs, no special entitlements required.
- Persona prompt files ship inside the IPA from `Resources/Personas/`.
- Privacy Manifest (`PrivacyInfo.xcprivacy`) is embedded.
- Build floor: iOS 18.0 | Primary validation device: iPhone 16e / iOS 27
- Built with Swift 6 strict concurrency.
- Memory is warm-loaded at launch so Ask / Intents work without opening Memory first.

## Failure modes

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| Workflow fails to find .app | XcodeGen or build error | Check build-logs artifact |
| SideStore rejects unsigned IPA | Rare packaging issue | Re-run workflow or try signed path |
| App crashes on launch | Signing / trust issue | Trust the profile again, reboot |
| Keychain / AI fails | First-run permission or key missing | Re-enter key in Settings |
| Install fails with OS version error | Extremely rare for lower-floor binary on higher OS | Re-download IPA / check SideStore logs |
| Missing persona personality | Prompt file not embedded | Check Archive logs for resource warnings; fallback prompts still work |

No Mac, no USB, no AltServer required after SideStore itself is installed.
