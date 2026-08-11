#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper to install both AICTRL telemetry tooling and the Cursor plugin.
#
# Required env:
#   - AICTRL_API_KEY
# Optional env:
#   - AICTRL_TOOL
#   - AICTRL_ORG
#   - AICTRL_EDITORS

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$DIR/install-aictrl-telemetry.sh"
"$DIR/install-aictrl-cursor-plugin.sh"

cat <<'EOF'
AICTRL setup complete.

Suggested verification:
  which codex || true
  npx @aictrl/plugin --help >/dev/null
  restart Cursor
EOF
