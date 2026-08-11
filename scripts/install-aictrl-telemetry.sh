#!/usr/bin/env bash
set -euo pipefail

# Install AICTRL telemetry tooling for local development.
#
# Required:
#   - curl
# Optional env:
#   - AICTRL_TOOL (default: codex)
#
# This intentionally uses the vendor installer endpoint. Review before running
# in a sensitive environment.

if ! command -v curl >/dev/null 2>&1; then
  echo "curl not found. Install curl first."
  exit 1
fi

AICTRL_TOOL="${AICTRL_TOOL:-codex}"

curl -sL https://aictrl.dev/api/telemetry/install | AICTRL_TOOL="$AICTRL_TOOL" bash
