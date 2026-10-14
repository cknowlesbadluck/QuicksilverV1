# Release freeze criteria (Quicksilver 1.0, SideStore)

A build is release-ready only when **every** box is ticked. Automated items are checked by
`bash scripts/release-readiness.sh --ci` (read-only) and by **Quicksilver CI**. Human gates are owner-only.

## Automated (agent / CI)
- [ ] Quicksilver CI green on `main`: Structure & Contracts (incl. gateway tests), SwiftLint `--strict`, SPM Unit Tests, iOS Simulator Build (AppTests), iOS UI Smoke (a11y audit)
- [ ] Architecture invariants pass (`Tests/ArchitectureInvariantTests.swift`, added in #254): one MercuryBrain path, CloudContextPolicy choke point, aspects not modes, no secrets
- [ ] No secret-shaped strings or env files tracked (`scripts/release-readiness.sh`)
- [ ] `PrivacyInfo.xcprivacy`: tracking false, no tracking domains, only `OtherUserContent` (sent to the bound AI provider), not tracked
- [ ] Reproducible: gateway `package-lock.json` committed; no unpinned SPM remotes; runner image pinned (`macos-15`). Pinning the Xcode version explicitly is an open follow-up and not checked yet
- [ ] No temporary write workflows; no workflow commits to the repo
- [ ] *Archive IPA* run on the release commit (checked by `--ci`) produced `Quicksilver-unsigned.ipa` (artifact kept with the SHA)

## Human gates (owner)
- [ ] HG2/HG3: gateway deployed on Cloudflare Workers Free; GEMINI_API_KEY / GROQ_API_KEY / DEVICE_TOKEN set as gateway secrets (never in the repo)
- [ ] HG1/HG4: IPA installed via SideStore on iPhone 16e → launch to Sanctum → bind gateway in Codex → Ask round-trip → aspect change visible → remember → Archive shows it → force-quit + relaunch keeps memory, binding and aspect
- [ ] HG5: on-device model works offline/keyless; Siri/Shortcuts cold start
- [ ] Hardening on device: airplane mode, invalid device token, exhausted budget → clear message, no crash; Reduce Motion honoured
- [ ] No critical crashes across one 7-day SideStore refresh cycle
- [ ] HG-P / HG-V: voice and visual sign-off

The **known-good sideload artifact** is the IPA from the commit where all of the above are ticked; record its SHA here.
