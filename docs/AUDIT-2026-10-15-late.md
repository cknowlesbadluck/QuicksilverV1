# Quicksilver audit — 2026-10-15, 11 PM (delta to AUDIT-2026-10-15.md)

Baseline: main `24521e8`, plus the open PRs #284, #308, #309, #310 and #311. Scores are 1–10.
**Overall 7.0 on main** (was 6.9), or **7.3 if the open PRs land**. Blunt summary: the code keeps improving, but release readiness hasn't moved, because there is still no device evidence and no IPA from current main.

## Delta
| Area | 10-15 | Now (main) | If open PRs land | Why |
|---|---|---|---|---|
| Architecture | 8 | 8 | 8 | Unchanged. `Nexus/Integration/*` is dead at runtime (used only by tests); keeping or pruning it is the owner's call. |
| Privacy | 7 | 7 | 7 | The privacy floor (#305) is on main. The English-only heuristic gate and the `aiServiceEnabled` default (off) are unchanged. |
| Concurrency | 8 | 8 | **9** | #284 retires the last `@unchecked Sendable` and the ratchet (#306) holds it at 0. #309 runs all 459 SPM tests under TSan, clean on its first run. |
| Tests | 8 | 8 | 8 | #311 adds fake-gateway budget tests. Still no snapshot tests; on-device is tested only through fakes. |
| CI | 7 | 7 | **8** | The TSan job (#309) and the header-separator contrast fix (#310). Still a 25–40 min cycle, and the accessibility check is still intermittently flaky on new nodes. |
| Deps & security | 8 | 8 | 8 | `release.yml` is still unpinned (#250, needs owner OK). |
| Cost / free tier | n/a | 5 | **7** | #311: budget headers, a Codex row, and leaning on-device near the limit. |
| Code hygiene | n/a | 7 | 8 | #308 prunes unused UI (RuneGlyph, glass/pill surfaces). |
| SideStore readiness | 4 | **4** | **4** | No IPA from current main; CHR-55, HG1 and HG5 are open. |
| UX | 6 | 6 | 6 | Never validated on a phone. |
| Performance | 6 | 6 | 6 | No device numbers. |

## Risks
1. No device IPA from current main; CHR-55 is open. Every device claim is unproven.
2. The new budget headers need a gateway deploy (HG2, owner) before the Codex row shows anything real.
3. The `aiServiceEnabled` default is off.
4. The accessibility check finds new contrast and clipping nodes intermittently, so CI noise is likely to continue.
