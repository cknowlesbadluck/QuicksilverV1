#!/usr/bin/env bash
# portfolio-probe.sh — fail-closed cross-plane acceptance probe.
# Exits non-zero unless Conduit is ready+stamped, Resonance is ready+stamped
# with owner key present, and deviceAcceptance is recorded on a real archive.
# Classifier tests and fixtures are not proof. Do not invent secrets.
set -euo pipefail

echo "=== Portfolio probe $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

# Conduit
CONDUIT_READY=$(curl -sS -w "\n%{http_code}" https://conduit-feco.onrender.com/ready || true)
CONDUIT_BODY=$(echo "$CONDUIT_READY" | head -n -1)
CONDUIT_CODE=$(echo "$CONDUIT_READY" | tail -n 1)
if [[ "$CONDUIT_CODE" != "200" ]]; then
  echo "FAIL: Conduit /ready HTTP $CONDUIT_CODE"
  exit 1
fi
if ! echo "$CONDUIT_BODY" | grep -q '"status":"ready"' || ! echo "$CONDUIT_BODY" | grep -q 'contractRevision'; then
  echo "FAIL: Conduit ready body missing status=ready or contractRevision"
  echo "$CONDUIT_BODY"
  exit 1
fi
echo "OK: Conduit ready + stamped"

# Resonance
RES_READY=$(curl -sS -w "\n%{http_code}" https://resonancenexus.netlify.app/api/ready || true)
RES_BODY=$(echo "$RES_READY" | head -n -1)
RES_CODE=$(echo "$RES_READY" | tail -n 1)
if [[ "$RES_CODE" != "200" ]]; then
  echo "FAIL: Resonance /api/ready HTTP $RES_CODE (owner gate or deploy lag)"
  echo "$RES_BODY"
  exit 1
fi
if ! echo "$RES_BODY" | grep -q '"status":"ready"' || ! echo "$RES_BODY" | grep -q 'contractRevision' || ! echo "$RES_BODY" | grep -q 'ownerActionRequired'; then
  echo "FAIL: Resonance ready body missing status=ready, contractRevision, or ownerActionRequired"
  echo "$RES_BODY"
  exit 1
fi
echo "OK: Resonance ready + stamped + owner key present"

# Device fence (placeholder — real proof requires iPhone 16e archive IPA evidence)
echo "NOTE: deviceAcceptance remains not_recorded until CHR-55 archive IPA is installed and validated on iPhone 16e."
echo "Probe fails closed until that evidence exists."
exit 1
