#!/usr/bin/env bash
# Release-freeze readiness check (priority 10). Read-only: it never builds,
# signs, uploads or changes anything. Run from the repo root.
#   bash scripts/release-readiness.sh [--ci]   (--ci also checks main's latest Quicksilver CI run via gh)
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
fail=0; pass() { echo "  PASS  $1"; }; bad() { echo "  FAIL  $1"; fail=1; }; skip() { echo "  SKIP  $1"; }

echo "== Secrets =="
if git ls-files -z | xargs -0 grep -IlE 'AIza[0-9A-Za-z_-]{35}|gsk_[0-9A-Za-z]{40,}|xai-[0-9A-Za-z]{40,}|sk-[0-9A-Za-z]{40,}|-----BEGIN [A-Z ]*PRIVATE KEY-----' 2>/dev/null | grep -v '^scripts/release-readiness.sh$'; then
  bad "secret-shaped strings in tracked files (listed above)"
else pass "no secret-shaped strings in tracked files"; fi
envs=$(git ls-files | grep -E '(^|/)\.env($|\.)|(^|/)\.dev\.vars($|\.)' | grep -vE '\.(example|sample|template)$' || true)
[ -n "$envs" ] && bad "tracked env files: $envs" || pass "no tracked env files"
[ -n "$(git status --porcelain)" ] && echo "  NOTE  working tree is dirty; file checks read the committed tree (HEAD)"

echo "== Privacy manifest =="
if python3 - <<'PY'
import plistlib, sys
import subprocess
d = plistlib.loads(subprocess.check_output(["git", "show", "HEAD:PrivacyInfo.xcprivacy"]))
assert d.get("NSPrivacyTracking") is False, "NSPrivacyTracking must be false"
assert not d.get("NSPrivacyTrackingDomains"), "no tracking domains"
types = [t.get("NSPrivacyCollectedDataType") for t in d.get("NSPrivacyCollectedDataTypes", [])]
assert types == ["NSPrivacyCollectedDataTypeOtherUserContent"], f"unexpected collected types: {types}"
assert all(t.get("NSPrivacyCollectedDataTypeTracking") is False for t in d["NSPrivacyCollectedDataTypes"])
PY
then pass "PrivacyInfo.xcprivacy parses; no tracking; only OtherUserContent"; else bad "PrivacyInfo.xcprivacy"; fi

echo "== Workflows =="
writers=$(git grep -lE 'git (commit|push)|contents: *write' HEAD -- .github/workflows | sed 's/^HEAD://' | grep -vE '/(prune-branches|release)\.yml$' || true)
[ -n "$writers" ] && bad "workflows that can commit/push: $writers" || pass "no workflow commits to the repo (prune-branches deletes only; release.yml is owner-gated)"
arch=$(git show HEAD:.github/workflows/archive.yml)
if grep -q 'CODE_SIGNING_ALLOWED=NO' <<<"$arch" && grep -q 'Quicksilver-unsigned.ipa' <<<"$arch"; then
  pass "archive.yml builds the unsigned SideStore IPA"; else bad "archive.yml unsigned IPA path"; fi

echo "== Reproducibility =="
[ -f gateway/package-lock.json ] && pass "gateway/package-lock.json committed" || bad "gateway lockfile missing"
if git show HEAD:Package.swift | grep -q '\.package('; then
  git ls-files --error-unmatch Package.resolved >/dev/null 2>&1 && pass "SPM remotes pinned by Package.resolved" || bad "Package.swift has remote packages but Package.resolved is not committed"
else pass "no SPM remote dependencies"; fi

echo "== Lint =="
if command -v swiftlint >/dev/null; then
  swiftlint lint --strict --quiet && pass "SwiftLint --strict clean" || bad "SwiftLint violations"
else skip "swiftlint not installed (CI SwiftLint job is the gate)"; fi

if [ "${1:-}" = "--ci" ]; then
  echo "== Main CI =="
  sha=$(git rev-parse HEAD)
  c=$(gh run list -w "Quicksilver CI" -c "$sha" -L 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null)
  [ "$c" = "success" ] && pass "Quicksilver CI on $sha: success" || bad "Quicksilver CI on $sha: ${c:-no run}"
  a=$(gh run list -w "Archive IPA" -c "$sha" -L 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null)
  [ "$a" = "success" ] && pass "Archive IPA built for $sha" || bad "no successful Archive IPA run for $sha (${a:-none})"
fi

echo "== Human gates (cannot be checked here) =="
echo "  TODO  HG1/HG4/HG5 on-device acceptance with a known-good IPA (see Documentation/RELEASE-READINESS.md)"
exit $fail
