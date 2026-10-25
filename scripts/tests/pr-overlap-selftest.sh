#!/usr/bin/env bash
# Offline fixture test for scripts/pr-overlap.sh. It needs no network or gh.
set -euo pipefail
script="$(cd "$(dirname "$0")/.." && pwd)/pr-overlap.sh"
bash -n "$script"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
printf '%s\t%s\n' \
  10 "UI/A.swift" 10 "UI/B.swift" 10 'docs/q"uote.md' \
  9 "UI/A.swift" 9 'docs/q"uote.md' \
  12 "UI/B.swift" 12 "UI/A.swift" \
  30 "Core/Only.swift" 30 "Core/Only.swift" > "$tmp/files.tsv"
out=$(bash "$script" --offline "$tmp/files.tsv" --json)
echo "$out"
grep -qx '{"a":9,"b":10,"files":\["UI/A.swift","docs/q\\"uote.md"\]}' <<<"$out" || fail "9x10 (numeric order, JSON escaping)"
grep -qx '{"a":9,"b":12,"files":\["UI/A.swift"\]}' <<<"$out" || fail "9x12"
grep -qx '{"a":10,"b":12,"files":\["UI/A.swift","UI/B.swift"\]}' <<<"$out" || fail "10x12"
grep -q '"a":30\|"b":30' <<<"$out" && fail "a PR never overlaps itself"
grep -qx '{"summary":{"open_prs":4,"overlapping_pairs":3,"shared_files":3}}' <<<"$out" || fail "summary"
command -v python3 >/dev/null && python3 -c 'import json,sys; [json.loads(l) for l in sys.stdin]' <<<"$out"
bash "$script" --offline "$tmp/files.tsv" | tail -1 | grep -qx "summary: 4 PRs with changes; 3 overlapping pairs; 3 shared files" || fail "table summary"
printf '%s\t%s\n' 1 a.swift 2 b.swift > "$tmp/none.tsv"
bash "$script" --offline "$tmp/none.tsv" | grep -qx "summary: 2 PRs with changes; 0 overlapping pairs; 0 shared files" || fail "no overlaps"
echo "pr-overlap self-test passed"
