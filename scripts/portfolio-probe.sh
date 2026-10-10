#!/usr/bin/env bash
# portfolio-probe.sh — fail-closed cross-plane acceptance probe.
# Exits non-zero unless Conduit is ready+stamped, Resonance is ready+stamped
# with owner key present, and deviceAcceptance is recorded on a real archive.
# Classifier tests and fixtures are not proof. Do not invent secrets.
# Output is human-readable; use --json for structured summary. grep for FAIL/OK for automation.
set -euo pipefail

JSON=false
if [[ "${1:-}" == "--json" ]]; then
  JSON=true
fi

echo "=== Portfolio probe $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

# Conduit
CONDUIT_READY=$(curl -sS -w "\n%{http_code}" https://conduit-feco.onrender.com/ready || true)
CONDUIT_BODY=$(echo "$CONDUIT_READY" | head -n -1)
CONDUIT_CODE=$(echo "$CONDUIT_READY" | tail -n 1)
CONDUIT_OK=false
if [[ "$CONDUIT_CODE" == "200" ]] && echo "$CONDUIT_BODY" | grep -q '"status":"ready"' && echo "$CONDUIT_BODY" | grep -q 'contractRevision'; then
  CONDUIT_OK=true
  echo "OK: Conduit ready + stamped"
  echo "DETAIL: $CONDUIT_BODY"
else
  echo "FAIL: Conduit /ready HTTP $CONDUIT_CODE or missing fields"
  echo "$CONDUIT_BODY"
fi

# Resonance
RES_READY=$(curl -sS -w "\n%{http_code}" https://resonancenexus.netlify.app/api/ready || true)
RES_BODY=$(echo "$RES_READY" | head -n -1)
RES_CODE=$(echo "$RES_READY" | tail -n 1)
RES_OK=false
if [[ "$RES_CODE" == "200" ]] && echo "$RES_BODY" | grep -q '"status":"ready"' && echo "$RES_BODY" | grep -q 'contractRevision' && echo "$RES_BODY" | grep -q 'ownerActionRequired'; then
  RES_OK=true
  echo "OK: Resonance ready + stamped + owner key present"
  echo "DETAIL: $RES_BODY"
else
  echo "FAIL: Resonance /api/ready HTTP $RES_CODE (owner gate or deploy lag)"
  echo "$RES_BODY"
fi

# Optional diagnostics check (non-blocking but logged)
DIAG=$(curl -sS https://conduit-feco.onrender.com/diagnostics || echo "DIAG_UNAVAILABLE")
DIAG_OK=false
if echo "$DIAG" | grep -q 'scopeParity'; then
  DIAG_OK=true
  echo "INFO: Conduit diagnostics scopeParity present"
else
  echo "WARN: Conduit diagnostics incomplete or unavailable"
fi

# Device fence (placeholder — real proof requires iPhone 16e archive IPA evidence)
echo "NOTE: deviceAcceptance remains not_recorded until CHR-55 archive IPA is installed and validated on iPhone 16e."
echo "Probe fails closed until that evidence exists."

if [[ "$JSON" == true ]]; then
  cat <<EOF
{"timestamp":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","conduit":{"ok":$CONDUIT_OK,"http":$CONDUIT_CODE,"body":$(echo "$CONDUIT_BODY" | jq -c . 2>/dev/null || echo '"parse_failed"')},"resonance":{"ok":$RES_OK,"http":$RES_CODE,"body":$(echo "$RES_BODY" | jq -c . 2>/dev/null || echo '"parse_failed"')},"diagnostics":$DIAG_OK,"deviceAcceptance":"not_recorded","probePassed":false}
EOF
fi

exit 1
