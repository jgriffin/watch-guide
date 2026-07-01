#!/usr/bin/env bash
# Vercel build wrapper.
# build-site.sh needs `jq`, which isn't in Vercel's build image. Bootstrap a
# pinned static jq onto PATH, then run the normal build. Locally jq is already
# installed, so this wrapper is a no-op there — build-site.sh stays the source
# of truth for the actual site generation.
set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found in build image — fetching pinned static binary…"
  curl -fsSL https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64 -o /tmp/jq
  chmod +x /tmp/jq
  export PATH="/tmp:$PATH"
fi

jq --version
exec bash build-site.sh
