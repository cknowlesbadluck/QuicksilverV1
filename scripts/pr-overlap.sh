#!/usr/bin/env bash
# Read-only report: pairs of open PRs that change the same files, so merge order and rebases can
# be planned before conflicts happen. Never pushes, comments, closes or edits anything.
#   bash scripts/pr-overlap.sh [--repo owner/name] [--json] [--offline FILE]
# --repo     defaults to the repository behind the `origin` remote.
# --offline  reads "PR<TAB>path" lines from FILE instead of calling gh (used by the self-test).
# Output: one line per overlapping pair, lowest PR first, then a summary line.
#   --json   one JSON object per pair ({"a":N,"b":M,"files":[...]}) then {"summary":{...}}.
set -euo pipefail
repo="" json=0 offline=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --json) json=1; shift ;;
    --offline) offline="$2"; shift 2 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

pairs_file=$(mktemp); trap 'rm -f "$pairs_file"' EXIT
if [ -n "$offline" ]; then
  [ -r "$offline" ] || { echo "cannot read $offline" >&2; exit 2; }
  { grep -v '^[[:space:]]*$' "$offline" || true; } | sort -u > "$pairs_file"
else
  command -v gh >/dev/null || { echo "gh CLI required (or --offline FILE)" >&2; exit 2; }
  if [ -z "$repo" ]; then
    repo=$(git remote get-url origin 2>/dev/null | sed -E 's#^(git@[^:]+:|[a-z]+://([^@/]+@)?[^/]+/)##; s#\.git$##')
  fi
  [ -n "$repo" ] || { echo "no --repo and no origin remote" >&2; exit 2; }
  # Listed first, outside a substitution in the loop header, so a gh failure (auth, network)
  # stops the script instead of looking like an empty queue.
  open_prs=$(gh pr list --repo "$repo" --state open --limit 10000 --json number --jq '.[].number') \
    || { echo "gh pr list failed for $repo" >&2; exit 3; }
  for pr in $open_prs; do
    # --paginate: the files endpoint returns 30 per page by default (at most 3000 files in total).
    gh api --paginate "repos/$repo/pulls/$pr/files?per_page=100" --jq ".[] | \"$pr\t\" + .filename" \
      || { echo "gh api failed for PR #$pr" >&2; exit 3; }
  done > "$pairs_file.raw"
  sort -u "$pairs_file.raw" > "$pairs_file"; rm -f "$pairs_file.raw"
fi

json_str() { local s=${1//\\/\\\\}; s=${s//\"/\\\"}; printf '"%s"' "$s"; }

# Group by file, then emit every PR pair that shares it.
overlaps=$(awk -F'\t' '
  { prs[$2] = prs[$2] " " $1 }
  END {
    for (f in prs) {
      n = split(prs[f], list, " ")
      for (i = 1; i <= n; i++) for (j = 1; j <= n; j++)
        if (list[i] + 0 < list[j] + 0) print list[i] "\t" list[j] "\t" f
    }
  }' "$pairs_file" | sort -t$'\t' -k1,1n -k2,2n -k3,3)

total_prs=$(cut -f1 "$pairs_file" | sort -u | grep -c . || true)
pair_count=0 file_count=0
current="" files=()
flush() {
  [ -n "$current" ] || return 0
  pair_count=$((pair_count + 1))
  local a=${current%:*} b=${current#*:}
  if [ "$json" = 1 ]; then
    local list="" f
    for f in "${files[@]}"; do list="$list${list:+,}$(json_str "$f")"; done
    printf '{"a":%s,"b":%s,"files":[%s]}\n' "$a" "$b" "$list"
  else
    printf '#%s x #%s (%s): %s\n' "$a" "$b" "${#files[@]}" "${files[*]}"
  fi
}
while IFS=$'\t' read -r a b f; do
  [ -n "$a" ] || continue
  if [ "$a:$b" != "$current" ]; then flush; current="$a:$b"; files=(); fi
  files+=("$f")
done <<<"$overlaps"
flush
[ -n "$overlaps" ] && file_count=$(cut -f3 <<<"$overlaps" | sort -u | grep -c .)

if [ "$json" = 1 ]; then
  printf '{"summary":{"open_prs":%s,"overlapping_pairs":%s,"shared_files":%s}}\n' "$total_prs" "$pair_count" "$file_count"
else
  echo "summary: $total_prs PRs with changes; $pair_count overlapping pairs; $file_count shared files"
fi
