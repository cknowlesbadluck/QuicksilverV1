# Portfolio 10-phase roadmap — refreshed 2026-10-26 18:02 UTC (full audit + harden + stabilize + hygiene prune + innovate)

Live probes 2026-10-26T18:02Z:
- Conduit https://conduit-feco.onrender.com/ready : **ready** (HTTP 200, version 0.8.0, contractRevision 2026-10-03-ready-surface, persistence postgres, production true). Warm.
- Resonance https://resonancenexus.netlify.app/api/ready : **ready OK** (HTTP 200, missingRequired=[], production true, authMode required ok, persistenceConfigured true, posture=contract_passed, contractRevision=2026-10-03-owner-gate, githubAdapterConfigured=false). Timestamp 2026-10-26T18:02:32Z.
- Vercel aliases: resonance.vercel.app returns 200 HTML (stranger_occupant). resonancenexus.vercel.app 404 DEPLOYMENT_NOT_FOUND. Drift persists; never treat as gate.
- Open PR counts: QuicksilverV1 ~18+, Conduit ~18+, Resonance ~20+. Entropy residual; hygiene prune ongoing, target <10 per repo.
- CHR-55: In Review (Urgent). Device Archive IPA on iPhone 16e/iOS 27 remains sole critical path. deviceAcceptance=not_recorded.
- CI: recent main runs green. No new regressions observed.
- Portfolio maturity (probe classification): ~7.3/10 when both warm. Both planes stamped ready. Remaining: CHR-55 device evidence + alias drift + residual PR entropy + Resonance github adapter config.
- No secrets invented. No device claim. Classifier ≠ production proof. Activity prune removed 0.

Brutal maturity: portfolio ~7.3/10. Dominant risks now: CHR-55 device Archive IPA + open-PR entropy (~18-20 each) + Vercel alias drift + incomplete githubAdapter on Resonance host. Stabilization holds; fail-closed posture confirmed. Scores: QS ~7.6, Conduit ~7.5, Resonance ~7.0.

## Phase 1 — Owner gate cleared (external key set)
SUPABASE_SERVICE_ROLE_KEY no longer missing. Exit met: live ready body stamped, missingRequired=[], posture contract_passed. Do not invent keys.

## Phase 2 — Alias and stranger classification stay strict
404 and unexpected 200 occupants are never the gate. Exit: tests reject treating them as owner action, device recorded, or production ready. Drift on Vercel aliases prioritized for cleanup (non-blocking, elevated).

## Phase 3 — Device fence immutable
claimDeviceAcceptance() rejects. Exit: health body keeps deviceAcceptance=not_recorded and acceptanceGate=CHR-55.

## Phase 4 — CHR-55 remains the only device gate
Simulator, CI, or workers.dev 200 is not acceptance. Exit: Linear CHR-55 open until archive IPA installed and validated on iPhone 16e.

## Phase 5 — Conversation and Memory budget stay
Bounded windows and on-device embeddings continue. Exit: AppTests green; no unbounded history leakage.

## Phase 6 — Gateway contract and free-tier stay
No paid Workers bindings (KV/R2/D1/Queues). Exit: wrangler.toml / equivalent clean. Cold-start 503 on Conduit is expected and retryable.

## Phase 7 — Hygiene prune executed
One roadmap file. No hourly audit artifacts. Held PRs not merged without verification. Archived Quicksilver remains non-product. Superseded docs-refresh PRs targeted for close. Open PR count target below 10 per repo via prioritized merge of green non-overlapping hardens and close of superseded/docs-only. Audit note mirrored across repos. Current: ~18+/~18+/~20+.

## Phase 8 — Resonance control plane stamped and adapters
Live Netlify ready body carries contract stamp. Configure githubAdapter on host. Second client or iOS Resonance surface may advance under existing constraints (no device claim, privacy floor).

## Phase 9 — Privacy and logging stay strict
Privacy manifest enforced. Gateway logs metadata only. Exit: no request/response body logging.

## Phase 10 — Cross-plane acceptance proof
Single probe covers Conduit ready (true), Resonance ready (stamped + adapter), and real device archive evidence. Exit: production verdict accepted. Fixture or classifier test is insufficient. Device remains open. Cold-start must be distinguished from not-ready.

Binding constraints: CHR-55 device archive remains. Residual open-PR entropy and alias drift are current operational risks and must be pruned/cleaned. Free-tier cold starts are non-blocking if retry recovers. Resonance githubAdapterConfigured=false is residual gap.

## Innovation Track (advanced — no gates violated)
1. Pure PortfolioPosture classifier holds. Fail-closed. Maturity score added to probe; advance to owned-only scoring.
2. portfolio-probe tools with cold-start backoff (retry on 503) — landed; both planes warm.
3. Open PR entropy reporting advances quantitative hygiene tracking; automate close of docs-only superseded.
4. Hygiene prune priority: close superseded docs-only PRs; merge only CI-green non-overlapping hardens.
5. Adversarial review of recent hardens continues.
6. Cross-plane readiness contract v1 alignment across repos (both ready).
7. Lockfile / Dependabot residual hygiene.
8. Cross-repo consistency: this evidence block is canonical; mirror key notes.
9. Chamber and capability plane advances unblocked by Resonance gate; configure remaining adapters.
10. On-device diagnostics post CHR-55 only. Fresh probe confirms both planes ready. No regression. Implement entropy dashboard next (in flight on Conduit #333 etc.).

Highest-value next: aggressively reduce open PR entropy (close docs-only superseded first, merge green non-overlapping hardens), clean Vercel alias drift, configure Resonance github adapter, then CHR-55 device IPA evidence. Stabilization holds. Innovate continues under constraints. Both planes ready is baseline.
