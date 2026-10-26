#!/usr/bin/env bash
# Read-only report: pairs of open PRs that change the same files, so merge order and rebases can
# be planned before conflicts happen. Never pushes, comments, closes or edits anything.
#   bash scripts/pr-overlap.sh [--repo owner/name] [--json] [--offline FILE] [--candidates [--status FILE]]
# --repo     defaults to the repository behind the `origin` remote.
# --offline  reads "PR<TAB>path" lines from FILE instead of calling gh (used by the self-test).
# Output: one line per overlapping pair, lowest PR first, then a summary line.
#   --json   one JSON object per pair ({"a":N,"b":M,"files":[...]}) then {"summary":{...}}.
# --candidates  instead list PRs that share no file with any other open PR ("candidate: #N").
#   Online it also requires GitHub's merge state CLEAN (green, no conflict, not blocked);
#   offline, --status FILE gives "PR<TAB>STATE" lines (no FILE: overlap check only).
#   With --json: {"candidate":N} lines then {"summary":{"candidates":N}}.
# --entropy  one hygiene score: open PRs + 2*overlapping pairs + behind main + 2*conflicted
#   + PRs with unresolved review threads (lower is better). Online it reads merge state and
#   threads with one read-only GraphQL query; offline, --status FILE gives
#   "PR<TAB>STATE[<TAB>UNRESOLVED_THREADS]" lines. BEHIND counts as behind, DIRTY as conflicted.
set -euo pipefail
repo="" json=0 offline="" candidates=0 entropy=0 status_file=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --json) json=1; shift ;;
    --offline) offline="$2"; shift 2 ;;
    --candidates) candidates=1; shift ;;
    --entropy) entropy=1; shift ;;
    --status) status_file="$2"; shift 2 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ "$candidates" = 1 ] && [ "$entropy" = 1 ] && { echo "--candidates and --entropy are exclusive" >&2; exit 2; }
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

# JSON string with backslash, quote and every C0 control character escaped.
json_str() {
  local LC_ALL=C s=$1 out="" c i
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    case "$c" in
      '"') out+='\"' ;;
      '\') out+='\\' ;;
      [$'\x01'-$'\x1f']) out+=$(printf '\\u%04x' "'$c") ;;
      *) out+=$c ;;
    esac
  done
  printf '"%s"' "$out"
}

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

if [ "$candidates" = 1 ]; then
  overlapping=$(cut -f1,2 <<<"$overlaps" | tr '\t' '\n' | grep . | sort -u || true)
  if [ -z "$offline" ] && [ -z "$status_file" ]; then
    status_file="$pairs_file.status"
    for pr in $(cut -f1 "$pairs_file" | sort -un); do
      # GitHub computes merge state lazily and answers UNKNOWN at first; ask again briefly.
      for _ in 1 2 3; do
        state=$(gh pr view "$pr" --repo "$repo" --json mergeStateStatus --jq .mergeStateStatus) \
          || { echo "gh pr view failed for PR #$pr" >&2; exit 3; }
        [ "$state" = UNKNOWN ] || break
        sleep 2
      done
      printf '%s\t%s\n' "$pr" "$state"
    done > "$status_file"
  fi
  count=0
  for pr in $(cut -f1 "$pairs_file" | grep . | sort -un); do
    grep -qx "$pr" <<<"$overlapping" && continue
    if [ -n "$status_file" ]; then
      state=$(awk -F'\t' -v p="$pr" '$1 == p { print $2 }' "$status_file")
      [ "$state" = CLEAN ] || continue
    fi
    if [ "$json" = 1 ]; then printf '{"candidate":%s}\n' "$pr"; else echo "candidate: #$pr"; fi
    count=$((count + 1))
  done
  if [ "$json" = 1 ]; then
    printf '{"summary":{"candidates":%s}}\n' "$count"
  else
    echo "summary: $count merge candidates (no shared files${status_file:+, merge state CLEAN})"
  fi
  exit 0
fi

if [ "$entropy" = 1 ]; then
  if [ -z "$offline" ] && [ -z "$status_file" ]; then
    status_file="$pairs_file.status"
    owner=${repo%%/*} name=${repo#*/}
    gh api graphql -F owner="$owner" -F name="$name" -f query='query($owner:String!,$name:String!){
      repository(owner:$owner,name:$name){pullRequests(states:OPEN,first:100){nodes{
        number mergeStateStatus reviewThreads(first:100){nodes{isResolved}}}}}}' \
      --jq '.data.repository.pullRequests.nodes[] |
        "\(.number)\t\(.mergeStateStatus)\t\([.reviewThreads.nodes[] | select(.isResolved | not)] | length)"' \
      > "$status_file" || { echo "gh api graphql failed for $repo" >&2; exit 3; }
  fi
  open=$(cat "$pairs_file" ${status_file:+"$status_file"} | awk -F'\t' 'NF && !seen[$1]++ { n++ } END { print n + 0 }')
  pairs=$(awk -F'\t' 'NF && !seen[$1 FS $2]++ { n++ } END { print n + 0 }' <<<"$overlaps")
  behind=0 dirty=0 threads=0
  if [ -n "$status_file" ]; then
    behind=$(awk -F'\t' '$2 == "BEHIND"' "$status_file" | grep -c . || true)
    dirty=$(awk -F'\t' '$2 == "DIRTY"' "$status_file" | grep -c . || true)
    threads=$(awk -F'\t' '$3 + 0 > 0' "$status_file" | grep -c . || true)
  fi
  score=$((open + 2 * pairs + behind + 2 * dirty + threads))
  if [ "$json" = 1 ]; then
    printf '{"entropy":{"score":%s,"open_prs":%s,"overlapping_pairs":%s,"behind":%s,"conflicted":%s,"unresolved_thread_prs":%s}}\n' \
      "$score" "$open" "$pairs" "$behind" "$dirty" "$threads"
  else
    echo "entropy: $score (open $open, overlapping pairs $pairs, behind $behind, conflicted $dirty, unresolved-thread PRs $threads)"
  fi
  exit 0
fi

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
