# patches/

Future source patches against `engine/` (upstream Firefox ESR) go here as
`*.patch` files in `git diff` format, named with a numeric prefix so they apply
in order (e.g. `0001-something.patch`).

`scripts/apply.sh` applies each one with `git apply` and skips any that are
already applied, so it is safe to rerun.

Prefer prefs (`branding/goat/pref/`) and policies (`settings/`) over source
patches where possible, because patches have to be rebased on every ESR update.
