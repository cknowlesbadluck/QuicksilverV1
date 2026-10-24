#!/usr/bin/env bash
# Read-only stale-branch report: every remote branch with no open PR, and whether its work is
# already on the default branch. Never deletes, pushes, closes or edits anything.
#   bash scripts/stale-branches.sh [--remote origin] [--base main] [--fetch]
# --fetch runs `git fetch --prune <remote>` first (it updates local remote-tracking refs only).
#
# Columns:
#   unique  commits whose patch is not on base (git cherry). 0 means everything is already in base.
#   ahead/behind  raw commit counts versus base. Squash merges keep "ahead" above 0, so trust "unique".
#   last    date of the branch tip.  pr  last closed/merged PR for the branch, if any.
# Verdict: "in-base" means safe to delete by hand, after a human check. Keep-list branches are never
# suggested for deletion.
set -euo pipefail

remote=origin base=main fetch=0
while [ $# -gt 0 ]; do
  case "$1" in
    --remote) remote="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --fetch) fetch=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
# Owner keep list; override with STALE_KEEP="a b c".
keep_list="${STALE_KEEP:-feat/cutover-lattice-1000 hygiene-audit-2026-10-21 feat/m35-memory-entity}"

command -v gh >/dev/null || { echo "gh CLI required" >&2; exit 2; }
[ "$fetch" = 1 ] && git fetch --quiet --prune "$remote"
git rev-parse --verify --quiet "$remote/$base" >/dev/null || { echo "no $remote/$base" >&2; exit 2; }

open_heads=$(gh pr list --state open --limit 200 --json headRefName --jq '.[].headRefName')

printf '%-44s %6s %6s %6s  %-10s  %-6s  %s\n' branch unique ahead behind last pr verdict
git for-each-ref --format='%(refname:strip=3)' "refs/remotes/$remote" | while read -r branch; do
  case "$branch" in HEAD|"$base") continue ;; esac
  grep -Fxq -- "$branch" <<<"$open_heads" && continue
  ref="$remote/$branch"
  unique=$(git cherry "$remote/$base" "$ref" | grep -c '^+' || true)
  read -r behind ahead < <(git rev-list --left-right --count "$remote/$base...$ref")
  last=$(git log -1 --format=%cs "$ref")
  pr=$(gh pr list --state all --head "$branch" --limit 1 --json number,state \
    --jq '.[0] | if . then "#\(.number)" + (if .state == "MERGED" then "m" else "c" end) else "-" end')
  if tr ' ' '\n' <<<"$keep_list" | grep -Fxq -- "$branch"; then verdict="keep-list"
  elif [ "$unique" = 0 ]; then verdict="in-base"
  elif [ "${pr%m}" != "$pr" ]; then verdict="merged-pr (squash; check unique by hand)"
  else verdict="unmerged work"
  fi
  printf '%-44s %6s %6s %6s  %-10s  %-6s  %s\n' "$branch" "$unique" "$ahead" "$behind" "$last" "$pr" "$verdict"
done
