# patches/

Goat's source patches against `engine/` (upstream Firefox ESR) live here as a
`git format-patch` queue, numbered so they apply in order
(e.g. `0001-something.patch`).

`scripts/apply.sh` turns them into commits on a local branch `goat` in
`engine/`: the commit from `ESR_VERSION` + `git am --3way patches/*.patch`.
It rebuilds the branch only when that commit or a patch changed, so it is safe
to rerun.

To change a patch, or add one:

1. Edit the files in `engine/` and commit on branch `goat`
   (`git -C engine commit --amend`, `git -C engine rebase -i`, or a new
   commit). The subject becomes the file name: subject
   `goat settings pane` gives `0005-goat-settings-pane.patch`.
2. Re-export with `scripts/update-esr.sh`. With no version argument it stays
   on the current ESR and only rewrites `patches/` (an unchanged queue gives
   byte-identical files). Until then, `apply.sh` refuses to rebuild the
   branch over the unexported commits.
3. Commit the changed `patches/`.

Prefer prefs (`branding/goat/pref/`) and policies
(`branding/goat/distribution/policies.json`) over source patches where
possible, because patches have to be rebased on every ESR update.
