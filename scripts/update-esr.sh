#!/bin/bash
# Fetch engine/ for the first time, or move it to a new Firefox ESR release.
#
#   scripts/update-esr.sh [<version>]     e.g. 153.6.0esr (default: ESR_VERSION's)
#
# Run from the MozillaBuild shell.
#
# No engine/ yet: git init, shallow-fetch tag FIREFOX_<ver>esr_RELEASE, then
# run scripts/apply.sh, which builds the local branch "goat" (the tag +
# patches/).
#
# Existing engine/: shallow-fetch the new tag, then
#   git rebase --onto <new tag> <old ESR_VERSION commit> goat
# If a patch conflicts, the rebase stops and ESR_VERSION is left alone:
# resolve and `git -C engine rebase --continue`, then rerun this script; or
# `git -C engine rebase --abort` to get the old goat branch back untouched.
# On success (or on the rerun), patches/ is re-exported with format-patch,
# ESR_VERSION is rewritten and scripts/apply.sh runs.
#
# With the current version this is a no-op. GOAT_ENGINE overrides the engine
# path (default: engine/ next to this repo's scripts/).

set -euo pipefail

GOAT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="${GOAT_ENGINE:-$GOAT/engine}"
export GOAT_ENGINE="$ENGINE"
REMOTE_URL="https://github.com/mozilla-firefox/firefox"

die() {
  echo "update-esr: $*" >&2
  exit 1
}
g() { git -C "$ENGINE" "$@"; }

[ $# -le 1 ] || die "usage: scripts/update-esr.sh [<version>], e.g. 153.6.0esr"
version="${1:-$(head -n 1 "$GOAT/ESR_VERSION" | tr -d '[:space:]')}"
case "$version" in
  *esr) ;;
  *) version="${version}esr" ;;
esac
base="${version%esr}"                       # 153.6.0
[[ "$base" =~ ^[0-9]+(\.[0-9]+)+$ ]] || die "not an ESR version: $version"
tag="FIREFOX_${base//./_}esr_RELEASE"       # FIREFOX_153_6_0esr_RELEASE
major="${base%%.*}"
old_commit="$(sed -n 's/^commit: //p' "$GOAT/ESR_VERSION")"

echo "update-esr: target $version (tag $tag)"

fetch_tag() {
  g rev-parse -q --verify "refs/tags/$tag^{commit}" >/dev/null && return
  echo "update-esr: fetching $tag (shallow)..."
  g fetch --depth 1 "$REMOTE_URL" "refs/tags/$tag:refs/tags/$tag" ||
    die "could not fetch tag $tag; check the version number"
}

write_esr_version() {
  cat > "$GOAT/ESR_VERSION" <<EOF
$version
tag: $tag
branch: esr$major
commit: $1
source: $REMOTE_URL
EOF
}

if [ ! -d "$ENGINE/.git" ]; then
  # First-time setup.
  [ ! -e "$ENGINE" ] || [ -z "$(ls -A "$ENGINE")" ] ||
    die "$ENGINE exists but is not a git checkout; move it away first"
  git init -q "$ENGINE"
  fetch_tag
  g -c advice.detachedHead=false checkout -q "$tag"
  new_commit="$(g rev-parse "$tag^{commit}")"
  [ "$new_commit" = "$old_commit" ] || write_esr_version "$new_commit"
  bash "$GOAT/scripts/apply.sh"
  echo "update-esr: engine/ set up at $version"
  exit 0
fi

if [ -d "$ENGINE/.git/rebase-merge" ] || [ -d "$ENGINE/.git/rebase-apply" ]; then
  die "a rebase is in progress in engine/: resolve the conflicts and run
  git -C engine rebase --continue
then rerun this script; or run
  git -C engine rebase --abort
to return to the old goat branch."
fi
[ "$(g symbolic-ref -q --short HEAD || true)" = goat ] ||
  die "engine/ is not on branch goat; run scripts/apply.sh first"
[ -z "$(g status --porcelain --untracked-files=no)" ] ||
  die "engine/ has uncommitted changes; commit them on branch goat or discard them first"

fetch_tag
new_commit="$(g rev-parse "$tag^{commit}")"
display="$(g show "$new_commit:browser/config/version_display.txt" | tr -d '[:space:]')"
[ "$display" = "$version" ] ||
  echo "update-esr: warning: version_display.txt says $display, expected $version" >&2

# Rebase goat unless it is already on the new tag (same version, or a rerun
# after `rebase --continue`).
if ! g merge-base --is-ancestor "$new_commit" goat; then
  g merge-base --is-ancestor "$old_commit" goat ||
    die "branch goat is not based on the ESR_VERSION commit $old_commit"
  echo "update-esr: rebasing goat onto $tag..."
  if ! g rebase -q --onto "$new_commit" "$old_commit" goat; then
    cat >&2 <<EOF

update-esr: a Goat patch conflicts with $version. ESR_VERSION was not changed.
Either resolve the conflicts in engine/ (git -C engine status lists them),
git -C engine add the files, then run
  git -C engine rebase --continue
and rerun: scripts/update-esr.sh $version
Or return to the old goat branch, untouched:
  git -C engine rebase --abort
EOF
    exit 2
  fi
fi

# Re-export the queue. Fixed options keep an unchanged queue byte-identical.
rm -f "$GOAT"/patches/*.patch
g format-patch -q --zero-commit --no-signature --no-numbered --no-stat \
  --full-index --no-thread --no-cover-letter \
  -o "$GOAT/patches" "$new_commit..goat"
[ "$new_commit" = "$old_commit" ] || write_esr_version "$new_commit"
bash "$GOAT/scripts/apply.sh" --adopt
echo "update-esr: engine/ is at $version ($new_commit) with $(g rev-list --count "$new_commit..goat") Goat patches"

if [ "$new_commit" != "$old_commit" ]; then
  cat <<EOF

Next, from the MozillaBuild shell:
  cd $GOAT/engine
  ./mach build                  # incremental; ./mach clobber first for a major ESR
  ./mach package                # also builds the installer
The installer is engine/obj-x86_64-pc-windows-msvc/dist/goat-<ver>.en-US.win64.installer.exe.
Test it (see README), then commit ESR_VERSION and patches/.
EOF
fi
