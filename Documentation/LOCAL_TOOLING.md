# Local Tooling Setup

This repository includes optional local helper scripts for AICTRL and opencode-based development tooling.

## AICTRL

Do not commit live credentials. Use environment variables locally.

### 1. Export your API key

```bash
export AICTRL_API_KEY='your-key-here'
```

Optional:

```bash
export AICTRL_ORG='personal-nbc0e8asuafhnamcky5222qilrm1'
export AICTRL_TOOL='codex'
export AICTRL_EDITORS='cursor'
```

### 2. Install telemetry tooling

```bash
bash scripts/install-aictrl-telemetry.sh
```

### 3. Install the Cursor plugin

```bash
bash scripts/install-aictrl-cursor-plugin.sh
```

### 4. Or run both

```bash
bash scripts/install-aictrl-all.sh
```

## Verification

```bash
which codex || true
npx @aictrl/plugin --help >/dev/null
```

Then restart Cursor.

## Security notes

- Prefer environment variables over inline CLI secrets.
- Do not commit `.env` files or shell history containing live keys.
- Review remote installer scripts before piping them into a shell in sensitive environments.
