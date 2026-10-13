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
for f in .env gateway/.dev.vars gateway/.env; do
  git ls-files --error-unmatch "$f" >/dev/null 2>&1 && bad "$f is tracked" || true
done

echo "== Privacy manifest =="
if python3 - <<'PY'
import plistlib, sys
d = plistlib.load(open("PrivacyInfo.xcprivacy", "rb"))
assert d.get("NSPrivacyTracking") is False, "NSPrivacyTracking must be false"
assert not d.get("NSPrivacyTrackingDomains"), "no tracking domains"
types = [t.get("NSPrivacyCollectedDataType") for t in d.get("NSPrivacyCollectedDataTypes", [])]
assert types == ["NSPrivacyCollectedDataTypeOtherUserContent"], f"unexpected collected types: {types}"
assert all(t.get("NSPrivacyCollectedDataTypeTracking") is False for t in d["NSPrivacyCollectedDataTypes"])
PY
then pass "PrivacyInfo.xcprivacy parses; no tracking; only OtherUserContent"; else bad "PrivacyInfo.xcprivacy"; fi

echo "== Workflows =="
[ -f .github/workflows/m1-t12-codex-fix.yml ] && bad "temporary m1-t12-codex-fix.yml present" || pass "no temporary write workflows"
if grep -q 'CODE_SIGNING_ALLOWED=NO' .github/workflows/archive.yml && grep -q 'Quicksilver-unsigned.ipa' .github/workflows/archive.yml; then
  pass "archive.yml builds the unsigned SideStore IPA"; else bad "archive.yml unsigned IPA path"; fi

echo "== Reproducibility =="
[ -f gateway/package-lock.json ] && pass "gateway/package-lock.json committed" || bad "gateway lockfile missing"
grep -q '"dependencies"' Package.resolved 2>/dev/null && skip "Package.resolved present" || pass "no SPM remote dependencies to pin"

echo "== Lint =="
if command -v swiftlint >/dev/null; then
  swiftlint lint --strict --quiet && pass "SwiftLint --strict clean" || bad "SwiftLint violations"
else skip "swiftlint not installed (CI SwiftLint job is the gate)"; fi

if [ "${1:-}" = "--ci" ]; then
  echo "== Main CI =="
  c=$(gh run list -b main -w "Quicksilver CI" -L 1 --json conclusion --jq '.[0].conclusion' 2>/dev/null)
  [ "$c" = "success" ] && pass "latest Quicksilver CI on main: success" || bad "latest Quicksilver CI on main: ${c:-unknown}"
fi

echo "== Human gates (cannot be checked here) =="
echo "  TODO  HG1/HG4/HG5 on-device acceptance with a known-good IPA (see Documentation/RELEASE-READINESS.md)"
exit $fail
