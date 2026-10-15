#!/usr/bin/env bash
# Read-only PR queue report: CI state, mergeability, and a recommended merge order.
# Never merges, approves, reruns or edits anything.
#   bash scripts/pr-queue-status.sh [--limit N]
# Order: green and mergeable first (docs/tests before code, then oldest first), then
# pending, then failing/conflicting. A PR whose base isn't the default branch is listed after its base.
set -euo pipefail
limit=50
[ "${1:-}" = "--limit" ] && limit="${2:-50}"
command -v gh >/dev/null || { echo "gh CLI required" >&2; exit 2; }

gh pr list --state open --limit "$limit" \
  --json number,title,isDraft,mergeable,baseRefName,headRefName,statusCheckRollup \
  --jq '
  def ci: [.statusCheckRollup[]? | (.conclusion // .state // .status // "" | ascii_upcase)] as $s
    | if ($s | length) == 0 then "none"
      elif any($s[]; . == "FAILURE" or . == "ERROR" or . == "TIMED_OUT" or . == "CANCELLED" or . == "ACTION_REQUIRED" or . == "STARTUP_FAILURE") then "red"
      elif any($s[]; . == "PENDING" or . == "QUEUED" or . == "IN_PROGRESS" or . == "EXPECTED" or . == "WAITING" or . == "") then "pending"
      else "green" end;
  def kind: if (.title | test("^(docs|test|chore|ci)[(:]"; "i")) then 0 else 1 end;
  map(. + {ci: ci}
      | . + {rank: (if .ci == "green" and .mergeable == "MERGEABLE" then 0
                    elif .ci == "pending" or .ci == "none" then 1 else 2 end)})
  | sort_by(.rank, kind, .number)
  | (["#", "CI", "MERGEABLE", "DRAFT", "BASE", "TITLE"] | @tsv),
    (.[] | ["#\(.number)", .ci, .mergeable, (if .isDraft then "draft" else "" end),
            (if .baseRefName == "main" then "main" else "on:\(.baseRefName)" end),
            (.title[0:70])] | @tsv)
  ' | awk -F'\t' '{ printf "%-6s %-8s %-12s %-6s %-14s %s\n", $1, $2, $3, $4, $5, $6 }'

echo
echo "Order above = recommended merge order (top first). Re-run after each merge; later PRs may need a rebase."
