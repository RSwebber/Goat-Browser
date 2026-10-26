#!/bin/bash
# Move engine/ to a new Firefox ESR release and re-apply the Goat overlay.
#
#   scripts/update-esr.sh 153.6.0esr
#
# Run from the MozillaBuild shell. Steps:
#   1. reverse Goat's patches so engine/ is back to clean upstream (stops if
#      engine/ has any other local changes)
#   2. shallow-fetch tag FIREFOX_<ver>esr_RELEASE and check it out
#   3. dry-run every patch in patches/ (git apply --check), stop on conflicts
#   4. run scripts/apply.sh and update ESR_VERSION
#   5. print the build and package commands
#
# Safe to rerun with the same version (it is then a no-op apart from step 4).

set -euo pipefail

GOAT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$GOAT/engine"
REMOTE_URL="https://github.com/mozilla-firefox/firefox"

die() {
  echo "update-esr: $*" >&2
  exit 1
}

[ $# -eq 1 ] || die "usage: scripts/update-esr.sh <version>, e.g. 153.6.0esr"
version="$1"
case "$version" in
  *esr) ;;
  *) version="${version}esr" ;;
esac
base="${version%esr}"                       # 153.6.0
[[ "$base" =~ ^[0-9]+(\.[0-9]+)+$ ]] || die "not an ESR version: $1"
tag="FIREFOX_${base//./_}esr_RELEASE"       # FIREFOX_153_6_0esr_RELEASE
major="${base%%.*}"
[ -d "$ENGINE/.git" ] || die "no git checkout at $ENGINE (see README)"

echo "update-esr: target $version (tag $tag)"

# 1. Back to clean upstream.
rm -rf "$ENGINE/browser/branding/goat"
patches=("$GOAT"/patches/*.patch)
for ((i = ${#patches[@]} - 1; i >= 0; i--)); do
  p="${patches[$i]}"
  [ -e "$p" ] || continue
  if git -C "$ENGINE" apply --check --reverse "$p" 2>/dev/null; then
    git -C "$ENGINE" apply --reverse "$p"
    echo "update-esr: reverted $(basename "$p")"
  fi
done
if [ -n "$(git -C "$ENGINE" status --porcelain --untracked-files=no)" ]; then
  git -C "$ENGINE" status --short --untracked-files=no | head -20 >&2
  die "engine/ has local changes that are not Goat patches; commit, move or discard them first"
fi

# 2. Fetch and check out the release tag.
echo "update-esr: fetching $tag (shallow)..."
git -C "$ENGINE" fetch --depth 1 "$REMOTE_URL" "refs/tags/$tag:refs/tags/$tag" ||
  die "could not fetch tag $tag; check the version number"
git -C "$ENGINE" -c advice.detachedHead=false checkout "$tag"
commit="$(git -C "$ENGINE" rev-parse HEAD)"
display="$(tr -d '[:space:]' < "$ENGINE/browser/config/version_display.txt")"
[ "$display" = "$version" ] ||
  echo "update-esr: warning: version_display.txt says $display, expected $version" >&2

# 3. Dry-run all patches before touching anything else.
failed=()
for p in "${patches[@]}"; do
  [ -e "$p" ] || continue
  if git -C "$ENGINE" apply --check "$p" 2>/dev/null; then
    echo "update-esr: ok:       $(basename "$p")"
  else
    echo "update-esr: CONFLICT: $(basename "$p")" >&2
    failed+=("$(basename "$p")")
  fi
done
if [ ${#failed[@]} -gt 0 ]; then
  echo >&2
  echo "update-esr: ${#failed[@]} patch(es) no longer apply to $version:" >&2
  printf '  %s\n' "${failed[@]}" >&2
  echo "engine/ is now at clean $tag with NO Goat patches applied." >&2
  echo "Rework each failing patch (see 'git -C engine apply --reject' output)," >&2
  echo "regenerate it with 'git -C engine diff -- <files>', then rerun this script." >&2
  echo "ESR_VERSION was not changed." >&2
  exit 2
fi

# 4. Apply the overlay and record the new base.
bash "$GOAT/scripts/apply.sh"
cat > "$GOAT/ESR_VERSION" <<EOF
$version
tag: $tag
branch: esr$major
commit: $commit
source: $REMOTE_URL
EOF
echo "update-esr: ESR_VERSION updated to $version ($commit)"

# 5. Next steps.
cat <<EOF

Next, from the MozillaBuild shell:
  cd $GOAT && source scripts/apply.sh
  cd engine
  ./mach build                  # incremental; ./mach clobber first for a major ESR
  ./mach package                # also builds the installer
The installer is engine/obj-x86_64-pc-windows-msvc/dist/goat-<ver>.en-US.win64.installer.exe.
Test it (see README) and commit ESR_VERSION.
EOF
