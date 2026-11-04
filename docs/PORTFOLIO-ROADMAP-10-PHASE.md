# Portfolio 10-phase roadmap — refreshed 2026-11-04 01:00 UTC (full audit + harden + stabilize + hygiene prune + innovate)

**Canonical source:** This file (in Resonance; mirrors in others for discoverability). Companion full audit: docs/AUDIT-2026-11-04-FULL-PORTFOLIO.md

**Live probe evidence (2026-11-04 ~01:00Z):**
- Conduit https://conduit-feco.onrender.com/ready : **ready OK** (0.8.0, postgres, production true, contractRevision 2026-10-03-ready-surface). Warm (recovered).
- Resonance https://resonancenexus.netlify.app/api/ready : **ready OK** (missingRequired=[], production true, githubAdapterConfigured=false, posture=contract_passed, contractRevision=2026-10-03-owner-gate, timestamp ~2026-11-04T01:01:31Z). Owner gate cleared. Warm.
- Vercel aliases: resonance.vercel.app 200 (stranger_occupant / Detail Framework risk confirmed); resonancenexus.vercel.app 404. Drift persists; never gate on non-owned.
- Open PR counts (post-prune): QuicksilverV1 ~16, Conduit ~16, Resonance ~22. Residual entropy; target <10. Green non-overlapping hardens remain merge candidates. Bolt micro-opts pruned this pass.
- CHR-55: In Review Urgent. Device Archive IPA on iPhone 16e/iOS 27 sole critical path. deviceAcceptance=not_recorded.
- CI: main green across planes when warm. Free-tier cold starts recoverable.
- Portfolio maturity ~7.6/10 when both warm. Scores: QS ~7.8, Conduit ~7.8, Resonance ~7.3. Dominant risks: CHR-55 device evidence + residual PR entropy + alias drift + githubAdapterConfigured=false + free-tier cold starts (recoverable).
- No secrets invented. No device claim. Classifier ≠ proof. See docs/AUDIT-2026-11-04-FULL-PORTFOLIO.md.

Brutal assessment: Stabilization holds. Fail-closed posture confirmed and sustained when warm. Architecture solid. Hygiene improved via prune. Not production-ready for Quicksilver until real device IPA evidence. Residual entropy is the highest operational lever.

## Phase 1 — Immediate Hygiene Prune
Partial exit met. Closed pure Bolt/Jules micro-opts and superseded docs. Continue merging green hardens. Target open PRs <10/repo.

## Phase 2 — CHR-55 sole device gate
Archive IPA on target iPhone 16e / iOS 27 only. Simulator/CI/Swift package tests insufficient. Linear CHR-55 In Review. deviceAcceptance stays not_recorded until owner records real IPA.

## Phase 3 — Auth Fail-Closed Complete
Land remaining early-401 PRs, log redaction. Confirm anonymous always 401 on non-public routes.

## Phase 4 — Adapter Configuration
Owner sets GITHUB_TOKEN + webhook secret on Resonance Netlify. Verify githubAdapterConfigured=true.

## Phase 5 — Memory and conversation budgets
Bounded, on-device first. AppTests green. Resilience tests progressing. Finish #410.

## Phase 6 — Gateway free-tier contract
No paid bindings. Cold-start recoverable. Free-only AI path. Probe tools distinguish cold.

## Phase 7 — Hygiene prune sustained
Target open PRs <10/repo sustained. Docs-only superseded closed. One canonical roadmap. **Innovate:** entropy dashboard script + close-candidate prioritization. Score PRs by age, CI status, file overlap, and docs-only/Jules/Bolt flag for automated close candidates. Continuous probe refresh already in practice.

## Phase 8 — Observability & Probe Hardening
Cold-start classifier in every probe. Entropy trend gate. Deploy-parity check.

## Phase 9 — Privacy and logging strict
Manifest enforced. No body logging. Redact errors and credentials. Early-401 hardens in flight.

## Phase 10 — Cross-plane acceptance
Probe + device evidence + low entropy. Production verdict only after all gates. Unified acceptance harness that never invents owner evidence. Warm ready is the confirmed baseline.

Binding: CHR-55 remains the production gate for Quicksilver. Entropy must stay pruned. Free-tier cold starts OK if they recover to ready. No auto-merge of overlapping or untested.

Highest-value next: merge green non-overlapping hardens after CI (QS #392/#412/#410), configure Resonance githubAdapter on host, then record CHR-55 device IPA on real iPhone. Stabilization holds. Innovate under constraints. Do not invent owner evidence. Entropy reduced this pass.
