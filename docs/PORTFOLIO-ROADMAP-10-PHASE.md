# Portfolio 10-Phase Roadmap — Aggressive Refresh 2026-11-12 14:00 UTC

Canonical cross-plane roadmap for QuicksilverV1 + Resonance + Conduit. Living document. Evidence-backed only.

**Current posture:** Stabilized alpha. Open PRs ~12. deviceAcceptance=not_recorded. Both backends warm/ready when probed. Scores ~7.9-8.1. Hygiene archive complete.

| # | Phase | Goal | Concrete Tasks | Exit Criteria | Status |
|---|---|---|---|---|---|
| 1 | Entropy control | Open PRs <10 total, none stale >14d | Merge green non-overlapping hardens (auth matrix #245, early-401, redaction, policy). Close pure noise. Schedule auto-rank. | ≤10 open across portfolio; weekly entropy report green | [in progress] |
| 2 | Device evidence | CHR-55 recorded on real iPhone 16e / iOS 27 | Owner records IPA install + basic surface validation via Diagnostics export (content-free). Add checklist script. | deviceAcceptance=recorded; SideStore path verified | [blocked] owner |
| 3 | Auth hardening complete | Fail-closed everywhere in prod | Merge remaining auth PRs; confirm production authMode=required with no bypass. Auth matrix tests on main. | No raw error leaks; 401 before validation | [in progress] |
| 4 | Contract stability | Versioned MCP + /ready surfaces | Land contract discovery + changelog gate. Pin SHAs on remaining Actions. CI fails on undocumented tool/field change. | ContractRevision frozen; SHA pins enforced | [in progress] |
| 5 | Observability | Cold-start-aware probes, zero false alarms | Complete portfolio-probe with retry timing + classifier. Entropy dashboard. | Probe reports distinguish startup from outage | [in progress] |
| 6 | Hygiene automation | Weekly self-report replaces manual audits | Schedule entropy + archive prune + stale-branch reports. Auto-rank close candidates. | Manual full audits drop to bi-weekly | [partial] |
| 7 | Adapter readiness | githubAdapter live when desired | Owner configures GITHUB_TOKEN + webhook secret on host. Vertical slice succeeds inside chamber. | github.repository.read succeeds; durable evidence | [blocked] owner |
| 8 | Performance baseline | Measured hot paths | Benchmark capability matching, pagination, probe latency, activity prune. Document p95. | Baselines in docs; no premature opts | not started |
| 9 | 1.0 contract | Stable semver + deprecation policy | Freeze contractRevision; publish runbook (cold start, rollback, key rotation). 30 consecutive green main days. | ≤5 open PRs; deprecation policy live | not started |
| 10 | Production claim | Honest ship | Device evidence + all phases 1-7 green. Free-tier constraints documented. | Owner declares production-ready | not started |

## High-leverage innovations
- Cold-start classifier + timing in portfolio-probe (complete this cycle).
- Entropy auto-rank close candidates + weekly schedule (enhance existing scripts).
- Contract SHA-pin gate + Dependabot (close #250).
- Device evidence checklist automation (Diagnostics template).

## Three distinct approaches for next cycle

**Approach 1 (Aggressive entropy):** Merge all green non-overlapping hardens immediately, close drafts >30d, schedule auto-rank. Risk: low if CI green. Impact: frees focus for device gate.

**Approach 2 (Device-first):** Owner records CHR-55 this week; parallel merge only auth matrix. Risk: owner bandwidth. Impact: unblocks honest production claim.

**Approach 3 (Observability + contract):** Finish cold-start probe + SHA-pin CI gate before more features. Risk: medium effort. Impact: reduces false alarms and supply-chain risk.

**Recommended:** Approach 1 + start Approach 2. Highest-value next: Owner records CHR-55. Then merge green hardens. Entropy reduction continues.

## Top risks
1. Device evidence remains the only path to honest Quicksilver production claim.
2. Residual entropy distracts from device gate.
3. Free-tier cold starts require probe retry discipline.

Update with evidence. No invented claims.
