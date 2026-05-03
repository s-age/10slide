#!/bin/bash
# Checks if a session name already exists in perclst.
# Usage: check-session-name.sh <name>
# Exit 0: name is available. Exit 1: name already taken (prints warning).
set -euo pipefail

NAME="${1:-}"
if [[ -z "$NAME" ]]; then
  echo "Usage: $0 <session-name>" >&2
  exit 2
fi

if perclst show "$NAME" >/dev/null 2>&1; then
  echo "WARNING: Session name '$NAME' already exists." >&2
  echo "  In 'perclst analyze', the newer session's UUID takes precedence for name lookups." >&2
  exit 1
fi

echo "OK: Session name '$NAME' is available."
