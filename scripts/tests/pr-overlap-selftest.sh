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
# --candidates: PRs sharing no file with another PR; --status keeps only CLEAN ones.
cand=$(bash "$script" --offline "$tmp/files.tsv" --candidates)
[ "$(grep '^candidate' <<<"$cand")" = "candidate: #30" ] || fail "candidates without status"
printf '%s\t%s\n' 1 a.swift 2 b.swift 3 c.swift > "$tmp/three.tsv"
printf '%s\t%s\n' 1 CLEAN 2 UNSTABLE 3 CLEAN > "$tmp/status.tsv"
cand=$(bash "$script" --offline "$tmp/three.tsv" --candidates --status "$tmp/status.tsv")
[ "$(grep '^candidate' <<<"$cand" | tr '\n' ' ')" = "candidate: #1 candidate: #3 " ] || fail "candidates with status"
tail -1 <<<"$cand" | grep -qx "summary: 2 merge candidates (no shared files, merge state CLEAN)" || fail "candidates summary"
# Empty and whitespace-only snapshots are valid (no open PRs).
printf '\n  \n' > "$tmp/empty.tsv"
bash "$script" --offline "$tmp/empty.tsv" --json | grep -qx '{"summary":{"open_prs":0,"overlapping_pairs":0,"shared_files":0}}' || fail "empty snapshot"
bash "$script" --offline /dev/null | grep -qx "summary: 0 PRs with changes; 0 overlapping pairs; 0 shared files" || fail "/dev/null snapshot"
# A failing gh must fail the script, not report an empty queue.
mkdir "$tmp/bin"; printf '#!/bin/sh\nexit 4\n' > "$tmp/bin/gh"; chmod +x "$tmp/bin/gh"
if PATH="$tmp/bin:$PATH" bash "$script" --repo o/r >/dev/null 2>&1; then fail "gh failure must not exit 0"; fi
echo "pr-overlap self-test passed"
