#!/usr/bin/env bash
# Read-only stale-branch report: every remote branch with no open PR, and whether its work is
# already on the default branch. Never deletes, pushes, closes or edits anything.
#   bash scripts/stale-branches.sh [--remote origin] [--base main] [--fetch] [--json] [--offline]
# --fetch    runs `git fetch --prune <remote>` first (it updates local remote-tracking refs only).
# --json     prints one JSON object per branch (JSON Lines) instead of the table.
# --offline  skips gh: no PR lookups, and every branch counts as having no open PR.
#            STALE_OPEN_HEADS="a b" lists open PR heads by hand (used by the self-test).
#
# Columns:
#   unique  commits whose patch is not on base (git cherry). 0 means no patch is missing; in-base also needs
#           merging the branch into base to leave base's tree unchanged (this catches merge-only changes).
#   ahead/behind  raw commit counts versus base. Squash merges keep "ahead" above 0, so trust "unique".
#   last    date of the branch tip.  pr  last closed (c) or merged (m) PR for the branch, if any.
# Verdict: "in-base" means safe to delete by hand, after a human check. Keep-list branches are never
# suggested for deletion. A summary line (table) or {"summary":...} object (JSON) comes last.
set -euo pipefail

remote=origin base=main fetch=0 json=0 offline=0
while [ $# -gt 0 ]; do
  case "$1" in
    --remote) remote="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --fetch) fetch=1; shift ;;
    --json) json=1; shift ;;
    --offline) offline=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
# Owner keep list; override with STALE_KEEP="a b c".
keep_list="${STALE_KEEP:-feat/cutover-lattice-1000 hygiene-audit-2026-10-21 feat/m35-memory-entity}"

# Bind every gh query to the repository behind --remote, not the gh default repo.
repo=$(git remote get-url "$remote" 2>/dev/null | sed -E 's#^(git@[^:]+:|[a-z]+://([^@/]+@)?[^/]+/)##; s#\.git$##')
[ "$offline" = 1 ] || command -v gh >/dev/null || { echo "gh CLI required (or --offline)" >&2; exit 2; }
[ "$fetch" = 1 ] && git fetch --quiet --prune "$remote"
git rev-parse --verify --quiet "$remote/$base" >/dev/null || { echo "no $remote/$base" >&2; exit 2; }

if [ -n "${STALE_OPEN_HEADS+set}" ]; then
  open_heads=$(tr ' ' '\n' <<<"$STALE_OPEN_HEADS")
elif [ "$offline" = 1 ]; then
  open_heads=""
else
  open_heads=$(gh pr list --repo "$repo" --state open --limit 10000 --json headRefName --jq '.[].headRefName')
fi

json_str() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '"%s"' "$s"; }

[ "$json" = 1 ] || printf '%-44s %6s %6s %6s  %-10s  %-6s  %s\n' branch unique ahead behind last pr verdict
total=0 in_base=0 keep=0 merged=0 unmerged=0
while read -r branch; do
  case "$branch" in HEAD|"$base"|"") continue ;; esac
  grep -Fxq -- "$branch" <<<"$open_heads" && continue
  ref="$remote/$branch"
  unique=$(git cherry "$remote/$base" "$ref" | grep -c '^+' || true)
  # git cherry compares patches, so it misses changes made only in merge commits. Only call a
  # branch in-base when merging it into base would leave base's tree unchanged.
  merge_only=0
  if [ "$unique" = 0 ]; then
    merged_tree=$(git merge-tree --write-tree "$remote/$base" "$ref" 2>/dev/null | head -1) || merged_tree=""
    [ "$merged_tree" = "$(git rev-parse "$remote/$base^{tree}")" ] || merge_only=1
  fi
  read -r behind ahead < <(git rev-list --left-right --count "$remote/$base...$ref")
  last=$(git log -1 --format=%cs "$ref")
  pr="-"
  if [ "$offline" = 0 ]; then
    pr=$(gh pr list --repo "$repo" --state all --head "$branch" --limit 1 --json number,state \
      --jq '.[0] | if . then "#\(.number)" + (if .state == "MERGED" then "m" elif .state == "OPEN" then "o" else "c" end) else "-" end')
    [ "${pr%o}" != "$pr" ] && continue  # open PR missed by the list above
  fi
  total=$((total + 1))
  if tr ' ' '\n' <<<"$keep_list" | grep -Fxq -- "$branch"; then verdict="keep-list"; keep=$((keep + 1))
  elif [ "$unique" = 0 ] && [ "$merge_only" = 0 ]; then verdict="in-base"; in_base=$((in_base + 1))
  elif [ "${pr%m}" != "$pr" ]; then verdict="merged-pr"; merged=$((merged + 1))
  else verdict="unmerged"; unmerged=$((unmerged + 1))
  fi
  if [ "$json" = 1 ]; then
    printf '{"branch":%s,"unique":%s,"ahead":%s,"behind":%s,"last":%s,"pr":%s,"verdict":%s}\n' \
      "$(json_str "$branch")" "$unique" "$ahead" "$behind" "$(json_str "$last")" "$(json_str "$pr")" "$(json_str "$verdict")"
  else
    printf '%-44s %6s %6s %6s  %-10s  %-6s  %s\n' "$branch" "$unique" "$ahead" "$behind" "$last" "$pr" "$verdict"
  fi
done < <(git for-each-ref --format='%(refname:strip=3)' "refs/remotes/$remote")

if [ "$json" = 1 ]; then
  printf '{"summary":{"total":%s,"in_base":%s,"keep_list":%s,"merged_pr":%s,"unmerged":%s}}\n' \
    "$total" "$in_base" "$keep" "$merged" "$unmerged"
else
  echo "summary: $total without an open PR; $in_base in-base, $keep keep-list, $merged merged-pr (squash; check by hand), $unmerged unmerged"
fi
