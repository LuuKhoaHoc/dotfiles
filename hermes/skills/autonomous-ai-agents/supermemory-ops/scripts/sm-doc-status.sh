#!/usr/bin/env bash
# sm-doc-status.sh — check dreaming status + summary for stored supermemory document IDs.
# Usage: sm-doc-status.sh <docId> [<docId> ...]
# Requires SUPERMEMORY_API_KEY (found in ~/.hermes/.env).
set -euo pipefail

KEY="${SUPERMEMORY_API_KEY:-}"
if [ -z "$KEY" ] && [ -f "$HOME/.hermes/.env" ]; then
  KEY=$(grep -m1 "^SUPERMEMORY_API_KEY=" "$HOME/.hermes/.env" | cut -d= -f2)
fi
if [ -z "$KEY" ]; then
  echo "SUPERMEMORY_API_KEY not found (checked env and ~/.hermes/.env)" >&2
  exit 1
fi

for ID in "$@"; do
  echo "=== $ID ==="
  curl -s -m 10 "https://api.supermemory.ai/v3/documents/$ID" \
    -H "Authorization: Bearer $KEY" -H "x-sm-source: sm-doc-status" \
  | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception as e:
    print('parse error:', e); sys.exit(1)
print('status:', d.get('status'), '| dreamingStatus:', d.get('dreamingStatus'))
print('title:', (d.get('title') or '')[:120])
print('summary:', repr(d.get('summary'))[:600])
"
done
