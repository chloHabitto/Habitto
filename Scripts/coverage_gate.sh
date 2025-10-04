#!/usr/bin/env bash
set -euo pipefail
# Example: parse xccov or use your tool. Minimal stub:
SERVICES=85
REPOSITORIES=82
if [[ $SERVICES -lt 80 || $REPOSITORIES -lt 80 ]]; then
  echo "Coverage gate failed: Services=$SERVICES, Repositories=$REPOSITORIES"; exit 1
fi
echo "Coverage gate ok"
