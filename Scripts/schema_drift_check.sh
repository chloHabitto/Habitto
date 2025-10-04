#!/usr/bin/env bash
set -euo pipefail
# Fail if Models/ changed AND migrations.md didn't in this commit
changed=$(git diff --name-only HEAD~1 | grep -E 'Core/.+Models|Core/Data/SwiftData|@Model' || true)
if [[ -n "$changed" ]]; then
  if ! git diff --name-only HEAD~1 | grep -q 'docs/data/migrations.md'; then
    echo "Schema changed but docs/data/migrations.md not updated"; exit 1
  fi
fi
echo "Schema drift check ok"
