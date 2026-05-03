#!/bin/bash
# Validates pipeline file naming conventions.
# Usage: validate-name.sh <pipeline-file>
set -euo pipefail

FILE="${1:-}"
if [[ -z "$FILE" ]]; then
  echo "Usage: $0 <pipeline-file>" >&2
  exit 1
fi

BASENAME=$(basename "$FILE")
DIRPATH=$(cd "$(dirname "$FILE")" 2>/dev/null && pwd)
PIPELINES_ABS=$(cd "pipelines" 2>/dev/null && pwd || echo "")

# Must be directly in pipelines/
if [[ -n "$PIPELINES_ABS" && "$DIRPATH" != "$PIPELINES_ABS" ]]; then
  echo "ERROR: Pipeline files must be placed directly in pipelines/, not in subdirectories." >&2
  echo "       Got: $FILE" >&2
  echo "       Tip: use __ instead of / in the filename (e.g. sample__my-task.yaml)" >&2
  exit 1
fi

# Extension check
if [[ ! "$BASENAME" =~ \.(json|yaml|yml)$ ]]; then
  echo "ERROR: '$BASENAME' must end with .json, .yaml, or .yml" >&2
  exit 1
fi

# Strip extension and validate naming pattern
# Segments joined by __, each segment: [a-z][a-z0-9-]*
STEM="${BASENAME%.*}"
if [[ "$STEM" =~ ^[a-z][a-z0-9-]*(__[a-z][a-z0-9-]*)*$ ]]; then
  echo "OK: '$BASENAME' naming is valid"
else
  echo "ERROR: '$BASENAME' has invalid naming." >&2
  echo "       Format: <segment>__<segment>__<name>.(json|yaml|yml)" >&2
  echo "       Rules:  segments are lowercase, digits, hyphens — no underscores within segments" >&2
  exit 1
fi
