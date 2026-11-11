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
# --candidates --json emits JSON only.
cj=$(bash "$script" --offline "$tmp/three.tsv" --candidates --status "$tmp/status.tsv" --json)
[ "$(tr '\n' ' ' <<<"$cj")" = '{"candidate":1} {"candidate":3} {"summary":{"candidates":2}} ' ] || fail "candidates json"
# Control characters in filenames are escaped in --json output.
printf '%s\t%s\n' 1 $'cr\rname.md' 2 $'cr\rname.md' > "$tmp/ctrl.tsv"
cr=$(bash "$script" --offline "$tmp/ctrl.tsv" --json)
grep -qF '"files":["cr\u000dname.md"]' <<<"$cr" || fail "control character escaping"
command -v python3 >/dev/null && python3 -c 'import json,sys; [json.loads(l) for l in sys.stdin]' <<<"$cr"
# --entropy: open + 2*pairs + behind + 2*conflicted + PRs with unresolved threads.
printf '%s\t%s\t%s\n' 9 CLEAN 0 10 BEHIND 2 12 DIRTY 0 30 CLEAN 1 31 BLOCKED 0 > "$tmp/entropy.tsv"
ent=$(bash "$script" --offline "$tmp/files.tsv" --entropy --status "$tmp/entropy.tsv")
[ "$ent" = "entropy: 16 (open 5, overlapping pairs 3, behind 1, conflicted 1, unresolved-thread PRs 2)" ] || fail "entropy: $ent"
bash "$script" --offline "$tmp/files.tsv" --entropy --status "$tmp/entropy.tsv" --json \
  | grep -qx '{"entropy":{"score":16,"open_prs":5,"overlapping_pairs":3,"behind":1,"conflicted":1,"unresolved_thread_prs":2}}' || fail "entropy json"
bash "$script" --offline /dev/null --entropy | grep -qx "entropy: 0 (open 0, overlapping pairs 0, behind 0, conflicted 0, unresolved-thread PRs 0)" || fail "entropy empty"
if bash "$script" --offline /dev/null --entropy --candidates >/dev/null 2>&1; then fail "exclusive flags"; fi
# Empty and whitespace-only snapshots are valid (no open PRs).
printf '\n  \n' > "$tmp/empty.tsv"
bash "$script" --offline "$tmp/empty.tsv" --json | grep -qx '{"summary":{"open_prs":0,"overlapping_pairs":0,"shared_files":0}}' || fail "empty snapshot"
bash "$script" --offline /dev/null | grep -qx "summary: 0 PRs with changes; 0 overlapping pairs; 0 shared files" || fail "/dev/null snapshot"
# A failing gh must fail the script, not report an empty queue.
mkdir "$tmp/bin"; printf '#!/bin/sh\nexit 4\n' > "$tmp/bin/gh"; chmod +x "$tmp/bin/gh"
if PATH="$tmp/bin:$PATH" bash "$script" --repo o/r >/dev/null 2>&1; then fail "gh failure must not exit 0"; fi
if PATH="$tmp/bin:$PATH" bash "$script" --repo o/r --entropy >/dev/null 2>&1; then fail "gh failure must not exit 0 (entropy)"; fi
# A truncated GraphQL page must fail closed, not undercount.
printf '#!/bin/sh\necho TRUNCATED\n' > "$tmp/bin/gh"
printf '#!/bin/sh\ncase "$*" in *graphql*) echo TRUNCATED ;; *) exit 0 ;; esac\n' > "$tmp/bin/gh"
if PATH="$tmp/bin:$PATH" bash "$script" --repo o/r --entropy >/dev/null 2>&1; then fail "truncated entropy must not exit 0"; fi
echo "pr-overlap self-test passed"
