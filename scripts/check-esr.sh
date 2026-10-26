#!/bin/bash
# Compare the Firefox ESR version Goat is built on (ESR_VERSION) with the
# latest ESR published by Mozilla.
#
#   scripts/check-esr.sh
#
# Prints the result. Exit code: 0 = up to date, 10 = update available,
# 1 = error. With GITHUB_OUTPUT set (in GitHub Actions), also writes
# current=, latest= and update= outputs.

set -euo pipefail

GOAT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="https://product-details.mozilla.org/1.0/firefox_versions.json"

current="$(head -n 1 "$GOAT/ESR_VERSION" | tr -d '[:space:]')"
latest="$(curl -fsSL "$URL" |
  sed -n 's/.*"FIREFOX_ESR"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
  head -n 1)"

if [ -z "$latest" ]; then
  echo "check-esr: could not read FIREFOX_ESR from $URL" >&2
  exit 1
fi

if [ "$current" = "$latest" ]; then
  update=false
  echo "Goat is on the latest Firefox ESR: $current"
else
  update=true
  echo "New Firefox ESR available: $latest (Goat is on $current)"
  echo "Update with: scripts/update-esr.sh $latest"
fi

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "current=$current"
    echo "latest=$latest"
    echo "update=$update"
  } >> "$GITHUB_OUTPUT"
fi

[ "$update" = true ] && exit 10
exit 0
