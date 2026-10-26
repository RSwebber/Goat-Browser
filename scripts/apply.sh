#!/bin/bash
# Apply Goat Browser's overlay onto the upstream engine/ checkout.
#
# Run from the MozillaBuild shell. Safe to run repeatedly: staged files are
# replaced wholesale on every run.
#
#   source scripts/apply.sh   # also exports MOZCONFIG into your shell
#   ./scripts/apply.sh        # stage files only (then export MOZCONFIG yourself)

set -e

GOAT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$GOAT/engine"
BRAND_DST="$ENGINE/browser/branding/goat"

if [ ! -f "$ENGINE/mach" ]; then
  echo "apply.sh: no Firefox checkout at $ENGINE (see README)" >&2
  return 1 2>/dev/null || exit 1
fi

# Branding: replace the staged copy so removed files don't linger.
rm -rf "$BRAND_DST"
cp -r "$GOAT/branding/goat" "$BRAND_DST"

# Distribution (policies + bundled add-ons), installed by the build into
# dist/bin/distribution/.
mkdir -p "$BRAND_DST/distribution/extensions"
cp "$GOAT/settings/moz.build" "$BRAND_DST/distribution/moz.build"
cp "$GOAT/settings/policies.json" "$BRAND_DST/distribution/policies.json"
cp "$GOAT/settings/distribution/extensions/"*.xpi "$BRAND_DST/distribution/extensions/"

# Source patches (none yet). Each is applied only if not already applied.
for p in "$GOAT"/patches/*.patch; do
  [ -e "$p" ] || continue
  if git -C "$ENGINE" apply --check --reverse "$p" 2>/dev/null; then
    echo "apply.sh: already applied: $(basename "$p")"
  else
    git -C "$ENGINE" apply "$p"
    echo "apply.sh: applied: $(basename "$p")"
  fi
done

export MOZCONFIG="$GOAT/mozconfig"
echo "apply.sh: overlay staged in $BRAND_DST"
echo "apply.sh: MOZCONFIG=$MOZCONFIG"
