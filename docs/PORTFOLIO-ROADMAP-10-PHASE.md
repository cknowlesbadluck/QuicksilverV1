# Portfolio 10-phase roadmap — 2026-09-30 12:00 EDT

1. **Stabilize entropy** — close superseded hygiene PRs. Keep only live work open. Exit: QS open set is #195 and at most one rebase of #193; Resonance open set is #131/#133/#134 plus optional #132; Conduit open set is #152/#155 plus frozen drafts #119/#120.
2. **Owner production redeploy (CHR-54)** — SERVICE_ROLE already exists on `resonancenexus` production context. Trigger a GitHub-backed production deploy of current main so the live process loads it. Exit: `GET https://resonancenexus.netlify.app/api/ready` 200. Do not invent the secret. Do not switch hosts.
3. **Land Resonance hardening already written** — rebase/merge #133 and #131 after green `web`+`ios` on current main. Keep #134 as the iOS app-target slice. Recut or close #132 if it stays conflicted.
4. **Durable GitHub adapter evidence on the live host** — scoped `GITHUB_TOKEN` + `GITHUB_WEBHOOK_SECRET` + post-restart proof for `github.repository.read` including deny cases. Blocked by phase 2.
5. **Quicksilver device HG (CHR-55)** from `4f9660ff` or later on the physical iPhone 16e. Simulator CI is not acceptance.
6. **Repair QS verification before more product UI** — make #195 Simulator Build + SPM tests green, or close it and recut a thinner PR. Rebase or close #193. Do not merge red.
7. **Conduit freeze + selected harden** — live 0.8.0 postgres stays. Rebase #152 path-guard onto `cefebc6f`. Hold #155 until Render TLS env is set. #119/#120 stay draft red.
8. **Resonance iOS I1** against a ready host: compose → plan → approve → execute → evidence. Blocked by phase 2.
9. **Chamber form / work / dissolve** with retained project-scoped audit in Supabase, visible on web and iOS. Blocked by phase 2.
10. **Release surface** — SideStore IPA evidence, unskip production-smoke, owner prune leftover `docs/hygiene-*` / `codex/*` / `counsel/*` / `bolt/*`. Archive abandoned `cknowlesbadluck/Quicksilver`. No delete-ref tool on this connector.
