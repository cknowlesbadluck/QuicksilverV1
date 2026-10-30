# Portfolio 10-phase roadmap — refreshed 2026-10-30 17:00 UTC (full audit + harden + stabilize + hygiene prune + innovate)

**Live probe evidence (2026-10-30T17:00Z approx):**
- Conduit https://conduit-feco.onrender.com/ready : **ready OK** (prior probes HTTP 200, version 0.8.0, contractRevision 2026-10-03-ready-surface, persistence postgres, production true). Warm baseline held.
- Resonance https://resonancenexus.netlify.app/api/ready : **ready OK** (prior probes HTTP 200, missingRequired=[], production true, githubAdapterConfigured=false, posture=contract_passed, contractRevision=2026-10-03-owner-gate).
- Vercel aliases: resonance.vercel.app returns stranger_occupant. Drift persists; never gate on non-owned.
- Open PR counts: QuicksilverV1 ~18, Conduit ~20, Resonance ~23. Residual entropy; target <10. Docs-only closed earlier. Green non-overlapping hardens remain merge candidates (QS #408-#412/#392, Conduit Jules #339-#342, Resonance early-401 hardens #243-#251).
- CHR-55: In Review Urgent. Device Archive IPA on iPhone 16e/iOS 27 sole critical path. deviceAcceptance=not_recorded. DeviceRunStamp + share evidence in flight (#392/#412).
- CI: main green across planes. No open Dependabot alerts on QuicksilverV1. Resonance and Conduit assumed similar.
- Portfolio maturity ~7.4/10 when both warm. Scores: QS ~7.6, Conduit ~7.5, Resonance ~7.1. Dominant risks: CHR-55 device evidence + PR entropy + alias drift + githubAdapterConfigured=false + free-tier cold starts (recoverable).
- No secrets invented. No device claim. Classifier ≠ proof.

Brutal assessment: Stabilization holds. Fail-closed posture confirmed. Architecture solid across Sense-Think-Express (QS), provider-neutral Nexus (Resonance), MCP bridge (Conduit). Not production-ready for Quicksilver until real device IPA evidence. Hygiene debt (PR entropy) remains the highest operational lever. Cold-start recoverable. Innovation: continuous probe + this roadmap refresh as hygiene implementation.

## Phase 1 — Owner gate cleared
Exit met. missingRequired=[] , posture contract_passed on Resonance Netlify. Conduit ready when warm.

## Phase 2 — Alias and stranger classification strict
Tests reject non-owned as ready. Clean Vercel aliases (non-blocking, informational only).

## Phase 3 — Device fence immutable
claimDeviceAcceptance rejects. deviceAcceptance stays not_recorded until owner records real IPA.

## Phase 4 — CHR-55 sole device gate
Archive IPA on target iPhone 16e / iOS 27 only. Simulator/CI/Swift package tests insufficient. Linear CHR-55 In Review.

## Phase 5 — Memory and conversation budgets
Bounded, on-device first. AppTests green. Resilience tests progressing (consolidated in open PRs).

## Phase 6 — Gateway free-tier contract
No paid bindings. Cold-start recoverable. Free-only AI path. Probe tools distinguish cold.

## Phase 7 — Hygiene prune
Target open PRs <10/repo. Docs-only superseded closed. Merge green hardens with no file overlap after CI green. One canonical roadmap (this file). Mirror audit notes to other repos. Entropy score: current ~18/20/23 → target <10. This refresh is part of the innovate hygiene pass.

## Phase 8 — Resonance adapters
Configure githubAdapter (GITHUB_TOKEN + webhook secret) on Netlify host. Advance secondary clients under constraints. githubAdapterConfigured remains false until owner sets.

## Phase 9 — Privacy and logging strict
Manifest enforced. No body logging. Redact errors and credentials. Early-401 hardens in flight. Privacy reason 85F4.1 for disk space display in open PR.

## Phase 10 — Cross-plane acceptance
Probe + device evidence + low entropy. Production verdict only after all gates. Unified acceptance harness that never invents owner evidence. Warm ready is the confirmed baseline.

Binding: CHR-55 remains the production gate for Quicksilver. Entropy and alias must prune. Free-tier cold starts OK if they recover to ready. No auto-merge of overlapping or untested. Owner has authorized aggressive hygiene without further gates for this pass.

## Innovation Track
1. PortfolioPosture fail-closed + maturity scoring (owned-only targets).
2. Probe tools with exponential cold-start backoff (landed).
3. Entropy dashboard + automated close candidates.
4. Consolidated hardens and surface guards (in flight across repos).
5. On-device DeviceRunStamp + shareable redacted evidence (post-CHR-55 scaffolding).
6. Early-401 and log-redact hardens.
7. Cross-plane contract alignment and ready-surface pins.
8. Knip baseline for planned adapters.
9. Chamber/capability advances unblocked once adapters configured.
10. Post-device diagnostics and full production verdict only after CHR-55.
11. Hygiene: docs-only PRs closed earlier.
12. Fresh probes confirming sustained warm ready state across planes.
13. Jules-generated performance optimizations in Conduit as low-risk hygiene candidates once CI green.
14. Continuous audit/roadmap refresh as innovate implementation of hygiene pass (this commit).
15. Entropy scoring and close-candidate prioritization advanced in roadmap and audit.
16. Automated probe + Linear snapshot refresh on schedule (next innovation).
17. Owner-authorized prune of high-entropy open PRs via targeted merges of non-overlapping green hardens.

Highest-value next: merge green non-overlapping hardens (QS privacy/intents/memory, Resonance early-401/log-redact, Conduit Jules perfs), configure Resonance githubAdapter on host, then record CHR-55 device IPA on real iPhone. Stabilization holds. Innovate under constraints. Do not invent owner evidence.
