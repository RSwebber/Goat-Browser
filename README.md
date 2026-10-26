# Goat Browser

Goat Browser is a privacy-, security- and customization-focused web browser
built as a fork of **Firefox ESR**. The current base is Firefox
**153.5.1esr** (see [`ESR_VERSION`](ESR_VERSION)).

> Status: step 3. Goat branding, privacy defaults, policies, a bundled uBlock
> Origin, Goat themes and a Goat settings pane are applied on top of upstream
> Firefox ESR.

![Goat settings pane](docs/screenshots/goat-settings.png)

![Goat Dark with vertical tabs](docs/screenshots/goat-dark-vertical-tabs.png)

## Layout

```
goat/
├── engine/                upstream Firefox ESR source (local checkout, NOT committed)
├── branding/
│   ├── GOAT.png           original logo
│   ├── goat-logo.png      transparent, square-cropped logo (generated)
│   └── goat/              branding dir -> engine/browser/branding/goat
│       ├── pref/firefox-branding.js   built-in privacy defaults
│       ├── content/goat-settings.mjs  the Goat settings pane
│       ├── content/themes/            Goat Dark and Goat Light themes
│       └── locales/en-US/goat.ftl     Goat UI strings
├── settings/
│   ├── policies.json      enterprise policies -> dist/bin/distribution/
│   ├── distribution/extensions/uBlock0@raymondhill.net.xpi   signed, from AMO
│   └── moz.build          installs the two above during the build
├── patches/               source patches against engine/ (git-apply format)
├── scripts/
│   ├── apply.sh           stages the overlay onto engine/ and sets MOZCONFIG
│   ├── make_branding.py   regenerates all branding images from GOAT.png
│   └── setup.md           toolchain versions used
├── docs/screenshots/      screenshots used in this README
├── mozconfig              build options
├── ESR_VERSION            exact upstream version, tag and commit we build on
└── LICENSE                MPL-2.0
```

`engine/` is a plain checkout of upstream Firefox at the tag in `ESR_VERSION`,
and it is gitignored. All Goat changes live in this repo and are copied or
applied onto `engine/` by `scripts/apply.sh`, which is safe to rerun.

### What Goat changes

- **Branding**: name "Goat" / "Goat Browser", vendor "Goat", executable
  `goat.exe`, and the goat logo for every icon, the About dialog and the
  installer bitmaps. Private-browsing icons use an inverted logo.
- **Build options** (`mozconfig`): updater, crash reporter and default-browser
  agent disabled; release build on the `esr` update channel; optimized and
  non-debug.
- **Privacy defaults** (`branding/goat/pref/firefox-branding.js`): strict
  Enhanced Tracking Protection, `privacy.resistFingerprinting`, HTTPS-Only
  Mode, telemetry, data reporting and studies off, sponsored content,
  Firefox Suggest, add-on recommendations and discovery off, no default-browser
  prompt. These are ordinary defaults, so users can change them in
  `about:config`.
- **Policies** (`settings/policies.json`): DisableTelemetry,
  DisableFirefoxStudies, DisablePocket, DuckDuckGo as the default search
  engine, uBlock Origin installed as `normal_installed` (the user can
  disable it, but it is reinstalled if removed), and UserMessaging to hide
  the Firefox Labs and More from Mozilla settings pages.
- **Goat settings pane** (`about:preferences#goat`): every control is bound
  to a real pref, so everything is reversible in `about:config`.
  - Appearance: theme (Goat Dark, Goat Light, or follow Windows), vertical
    tabs, compact density, bookmarks toolbar.
  - Privacy level: *Maximum* (`privacy.resistFingerprinting`, which forces
    light mode and UTC times on websites) or *Balanced* (RFP off and
    Firefox's fingerprinting protection, on via strict ETP, which keeps dark
    mode and local time). Under Maximum, a list of exempt sites
    (`privacy.resistFingerprinting.exemptedDomains`).
  - Privacy: HTTPS-Only Mode, clear cookies and site data on close (same
    semantics as Firefox's own checkbox; history is not cleared), and a button
    for the uBlock Origin dashboard.
  - Keyboard shortcuts: a link to Firefox's built-in editor, `about:keyboard`.
- **Themes**: Goat Dark (the default on new profiles) and Goat Light are
  built-in themes and appear in Add-ons → Themes.
- **About dialog**: Goat's own text and project link instead of Mozilla's
  donate and get-involved links, with credit to Firefox ESR by Mozilla.
- **Patches** (`patches/`):
  - `0001-set-app-vendor-goat.patch`: sets the build vendor to "Goat" (this
    ESR doesn't allow it in a mozconfig). The Firefox app ID is kept, so
    add-ons from addons.mozilla.org remain compatible.
  - `0002-honour-default-etp-category.patch`: makes a built-in default
    tracking-protection category ("strict") take effect on new profiles.
    Upstream recalculates the category from its sub-prefs, so a plain default
    would be ignored. Users can still switch to Standard or Custom.
  - `0003-windows-company-name-goat.patch`: "Goat" instead of "Mozilla
    Corporation" in the Windows file properties of goat.exe.
  - `0004-about-dialog-goat-credit.patch`: the About dialog text above.
  - `0005-goat-settings-pane.patch`: registers the Goat settings pane and
    its nav entry. The pane's code and strings live in `branding/goat`.
  - `0006-goat-builtin-themes.patch`: registers Goat Dark and Goat Light as
    built-in themes and switches new profiles to Goat Dark once. After that,
    the user's theme choice is left alone.

### Known leftovers

- The profile folder is `%APPDATA%\Goat\Firefox`. Changing the internal app
  basename (`--with-app-basename=Goat`) would also change the user-agent to
  "Goat/…" unless more configure options were patched. That breaks
  addons.mozilla.org installs and makes users more fingerprintable, and it
  needs a near-full rebuild, so it is left as is.
- The About dialog's "Terms of Use" and "Privacy Notice" links still point
  to Mozilla's Firefox documents.

## Building on Windows

These are the steps used on the first machine (Windows 11, i7-12700H, 16 GB RAM).

1. **Install MozillaBuild** to `C:\mozilla-build` from
   <https://ftp.mozilla.org/pub/mozilla/libraries/win32/MozillaBuildSetup-Latest.exe>.
   Visual Studio is *not* needed: `mach bootstrap` downloads clang-cl, the
   MSVC libraries and the Windows SDK itself.
2. **Enable long paths in git**: `git config --global core.longpaths true`
3. **Clone this repo** to a path with no spaces, e.g. `C:\goat`.
4. **Fetch the engine** at the tag listed in `ESR_VERSION` (shallow clone):

   ```bash
   git clone --depth 1 --branch FIREFOX_153_5_1esr_RELEASE \
       https://github.com/mozilla-firefox/firefox C:/goat/engine
   ```

5. **Open the MozillaBuild shell** (`C:\mozilla-build\start-shell.bat`) and run:

   ```bash
   cd /c/goat/engine
   ./mach --no-interactive bootstrap --application-choice browser   # first time only
   cd /c/goat
   source scripts/apply.sh          # stage the overlay, export MOZCONFIG
   cd engine
   ./mach build
   ./mach run --temp-profile
   ```

   Always `source scripts/apply.sh` in a new shell before building, so that
   `MOZCONFIG` points at `C:\goat\mozconfig`.

On the first machine, bootstrap took about 12 minutes and the first
unmodified build took about 69 minutes (4155 s). The first Goat build is
listed in `scripts/setup.md`. Windows Defender was left at its defaults; adding
Defender exclusions for `C:\goat`, `C:\mozilla-build` and
`%USERPROFILE%\.mozbuild` should make builds faster.

The build output is `engine/obj-x86_64-pc-windows-msvc/dist/bin/goat.exe`.

### Regenerating the branding images

If `branding/GOAT.png` changes:

```bash
python -m venv .venv-tools
.venv-tools/Scripts/python -m pip install Pillow
.venv-tools/Scripts/python scripts/make_branding.py
```

### Updating uBlock Origin

Download the latest signed `.xpi` from addons.mozilla.org
(<https://addons.mozilla.org/firefox/addon/ublock-origin/>), replace
`settings/distribution/extensions/uBlock0@raymondhill.net.xpi`, and check its
SHA-256 against the hash published by the AMO API. The policy's `install_url`
also points at AMO's latest version, so a removed copy is reinstalled online.

### Packaging (step 4)

`policies.json` and the bundled `.xpi` are installed by the build into
`dist/bin/distribution/`. The installer's package manifest already ships
`@RESPATH@/distribution/*`. **The packaging step must verify that both are
present in the installer and the zip.**

## License

Goat Browser is licensed under the [Mozilla Public License 2.0](LICENSE), the
same license as the Firefox source it is based on. uBlock Origin is GPLv3 and
is redistributed unmodified. "Firefox" is a Mozilla trademark, and Goat
Browser is not affiliated with or endorsed by Mozilla.
