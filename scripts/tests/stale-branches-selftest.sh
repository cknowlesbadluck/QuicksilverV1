#!/usr/bin/env bash
# Offline fixture test for scripts/stale-branches.sh. It runs in a throwaway temp repo and
# needs no network or gh.
set -euo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/stale-branches.sh"
bash -n "$script"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git init -q --bare "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/work" 2>/dev/null
cd "$tmp/work"
git config user.email t@example.invalid; git config user.name test
git checkout -q -b main
echo base > f; git add f; git commit -qm base; git push -q origin main

git checkout -q -b in-base; echo a >> f; git commit -qam a; git push -q origin in-base
git checkout -q main; echo m > m; git add m; git commit -qm m; git cherry-pick in-base >/dev/null; git push -q origin main   # same patch on main
git checkout -q -b unmerged main; echo u > u; git add u; git commit -qm u; git push -q origin unmerged
git checkout -q -b keep-me main; echo k > k; git add k; git commit -qm k; git push -q origin keep-me
git checkout -q -b open-pr main; echo o > o; git add o; git commit -qm o; git push -q origin open-pr
# A change made only inside a merge commit: git cherry sees no unique patch, but the content isn't on main.
git checkout -q -b merge-only main~1; git merge -q --no-ff --no-commit main >/dev/null 2>&1 || true
echo x > x; git add x; git commit -qm "merge with extra file"; git push -q origin merge-only
git fetch -q origin

out=$(STALE_KEEP="keep-me" STALE_OPEN_HEADS="open-pr" bash "$script" --offline --json)
echo "$out"
fail() { echo "FAIL: $1" >&2; exit 1; }
grep -q '"branch":"in-base","unique":0,.*"verdict":"in-base"' <<<"$out" || fail "in-base"
grep -q '"branch":"unmerged","unique":1,.*"verdict":"unmerged"' <<<"$out" || fail "unmerged"
grep -q '"branch":"merge-only","unique":0,.*"verdict":"unmerged"' <<<"$out" || fail "merge-only content is not in-base"
grep -q '"branch":"keep-me".*"verdict":"keep-list"' <<<"$out" || fail "keep-list"
grep -q '"branch":"open-pr"' <<<"$out" && fail "open PR heads must be skipped"
grep -q '"summary":{"total":4,"in_base":1,"keep_list":1,"merged_pr":0,"unmerged":2}' <<<"$out" || fail "summary"
command -v python3 >/dev/null && python3 -c 'import json,sys; [json.loads(l) for l in sys.stdin]' <<<"$out"
STALE_OPEN_HEADS="open-pr" bash "$script" --offline | tail -1 | grep -qx "summary: 4 without an open PR; 1 in-base, 0 keep-list, 0 merged-pr (squash; check by hand), 3 unmerged" || fail "table summary"
echo "stale-branches self-test passed"
