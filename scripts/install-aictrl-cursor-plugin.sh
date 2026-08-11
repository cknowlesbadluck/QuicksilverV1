#!/usr/bin/env bash
set -euo pipefail

# Install the AICTRL Cursor plugin without hardcoding secrets in source.
#
# Required env:
#   - AICTRL_API_KEY
# Optional env:
#   - AICTRL_ORG (default: personal-nbc0e8asuafhnamcky5222qilrm1)
#   - AICTRL_EDITORS (default: cursor)
#
# Requires Node.js / npm with npx available.

if ! command -v npx >/dev/null 2>&1; then
  echo "npx not found. Install Node.js / npm first: https://nodejs.org/"
  exit 1
fi

if [[ -z "${AICTRL_API_KEY:-}" ]]; then
  echo "AICTRL_API_KEY is not set. Export it first and rerun."
  exit 1
fi

AICTRL_ORG="${AICTRL_ORG:-personal-nbc0e8asuafhnamcky5222qilrm1}"
AICTRL_EDITORS="${AICTRL_EDITORS:-cursor}"

npx @aictrl/plugin \
  --org "$AICTRL_ORG" \
  --api-key "$AICTRL_API_KEY" \
  --editors "$AICTRL_EDITORS" \
  --non-interactive
