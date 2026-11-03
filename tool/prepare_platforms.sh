#!/usr/bin/env bash
set -euo pipefail

# The repository keeps Flutter's app source as the source of truth.
# Generate platform scaffolding with the same stable Flutter SDK used by CI.
if [[ ! -d android || ! -f web/index.html ]]; then
  flutter create \
    --platforms=android,web \
    --project-name milk_account \
    --org com.milkaccount \
    .
else
  echo "Android and Web platform folders already exist; leaving them unchanged."
fi
