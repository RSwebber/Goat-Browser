#!/bin/bash
# Apply Goat Browser onto the upstream engine/ checkout.
#
#   scripts/apply.sh
#   scripts/apply.sh --adopt   # branch goat already matches patches/; record it
#                              # instead of rebuilding (used by update-esr.sh)
#
# Run from the MozillaBuild shell. Safe to run repeatedly.
#
# 1. Goat's source patches are commits on a local branch "goat" in engine/:
#    the commit from ESR_VERSION + `git am --3way patches/*.patch`. The branch
#    is rebuilt only when that commit or patches/ changed (a stamp in
#    engine/.git records both, plus the branch head it built), so an unchanged
#    queue touches no files and incremental builds stay incremental. It is
#    never rebuilt over commits that were added to it but not exported.
# 2. branding/goat is copied to browser/branding/goat.
# 3. mozconfig is copied to engine/mozconfig, where mach finds it by itself.
#
# Nothing here touches obj-* or runs git clean.

set -euo pipefail

GOAT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="${GOAT_ENGINE:-$GOAT/engine}"
BRAND_DST="$ENGINE/browser/branding/goat"
STAMP="$ENGINE/.git/goat-apply.stamp"

die() {
  echo "apply.sh: $*" >&2
  exit 1
}

[ -f "$ENGINE/mach" ] && [ -d "$ENGINE/.git" ] ||
  die "no Firefox checkout at $ENGINE (run scripts/update-esr.sh, see README)"
g() { git -C "$ENGINE" "$@"; }

if [ -d "$ENGINE/.git/rebase-merge" ] || [ -d "$ENGINE/.git/rebase-apply" ]; then
  die "a rebase or am is in progress in engine/; finish it (see scripts/update-esr.sh) or abort it first"
fi
if [ -n "$(g status --porcelain --untracked-files=no)" ]; then
  g status --short --untracked-files=no | head -20 >&2
  die "engine/ has uncommitted changes; commit them on branch goat or discard them first"
fi

# am and rebase need a committer; reuse this repo's identity (never exported).
for key in user.name user.email; do
  g config "$key" >/dev/null ||
    g config "$key" "$(git -C "$GOAT" config "$key" || echo goat)"
done

# Keep the staged overlay and mozconfig out of `git status`.
for pat in /mozconfig /browser/branding/goat/; do
  grep -qxF "$pat" "$ENGINE/.git/info/exclude" 2>/dev/null ||
    echo "$pat" >> "$ENGINE/.git/info/exclude"
done

# 1. Patch queue.
base="$(sed -n 's/^commit: //p' "$GOAT/ESR_VERSION")"
g cat-file -e "$base^{commit}" 2>/dev/null ||
  die "engine/ lacks the ESR_VERSION commit $base (run scripts/update-esr.sh)"
patches=("$GOAT"/patches/*.patch)
want="$base $(cat "${patches[@]}" | sha256sum | cut -d' ' -f1)"
branch="$(g symbolic-ref -q --short HEAD || true)"
old="$(g rev-parse -q --verify refs/heads/goat || true)"
if [ "${1:-}" = --adopt ]; then
  [ "$branch" = goat ] || die "--adopt: engine/ is not on branch goat"
  printf '%s\n%s\n' "$want" "$old" > "$STAMP"
  echo "apply.sh: recorded branch goat as ESR_VERSION commit + ${#patches[@]} patches"
elif [ "$branch" = goat ] && [ "$want" = "$(sed -n 1p "$STAMP" 2>/dev/null)" ]; then
  echo "apply.sh: branch goat is up to date (${#patches[@]} patches)"
else
  built="$(sed -n 2p "$STAMP" 2>/dev/null)"
  if [ -n "$old" ] && [ -n "$built" ] && [ "$old" != "$built" ]; then
    die "branch goat has commits that aren't in patches/; export them first
  (scripts/update-esr.sh), or drop them with: git -C engine reset --hard $built"
  fi
  g -c advice.detachedHead=false checkout -q -B goat "$base"
  if ! g am -q --3way --committer-date-is-author-date "${patches[@]}"; then
    g am --abort
    [ -n "$old" ] && g checkout -q -B goat "$old"
    die "patches/ no longer apply to $base; branch goat was left as it was"
  fi
  printf '%s\n%s\n' "$want" "$(g rev-parse HEAD)" > "$STAMP"
  echo "apply.sh: rebuilt branch goat: ESR_VERSION commit + ${#patches[@]} patches"
fi

# 2. Branding, including distribution/ (policies + bundled add-ons): replace
# the staged copy so removed files don't linger. Timestamps are kept, so an
# unchanged file doesn't look new to the build.
rm -rf "$BRAND_DST"
cp -r --preserve=timestamps "$GOAT/branding/goat" "$BRAND_DST"

# 3. mach uses topsrcdir/mozconfig when MOZCONFIG is unset. Copy only on
# change, so an unchanged mozconfig doesn't trigger a reconfigure.
cmp -s "$GOAT/mozconfig" "$ENGINE/mozconfig" || cp "$GOAT/mozconfig" "$ENGINE/mozconfig"

echo "apply.sh: overlay staged in $BRAND_DST"
echo "apply.sh: mozconfig staged as $ENGINE/mozconfig"
