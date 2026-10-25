# Goat Browser

Goat Browser is a privacy-, security- and customization-focused web browser
built as a fork of **Firefox ESR**. The current base is Firefox
**153.5.1esr** (see [`ESR_VERSION`](ESR_VERSION)).

> Status: step 1. An unmodified Firefox ESR builds and runs from this layout.
> No Goat-specific changes have been made yet.

## Layout

```
goat/
├── engine/          upstream Firefox ESR source (local checkout, NOT committed)
├── scripts/         build/setup notes and helper scripts
│   └── setup.md     toolchain versions used
├── ESR_VERSION      exact upstream version, tag and commit we build on
├── LICENSE          MPL-2.0
└── README.md
```

`engine/` is a plain checkout of upstream Firefox at the tag in
`ESR_VERSION`. It is gitignored. Our own changes will live in this repo as:

- **patches/**: patches applied on top of `engine/`
- **prefs/**: default preference overrides (privacy/security hardening)
- **branding/**: Goat Browser name, icons and branding files

(These directories will be added as the work begins.)

## Building on Windows

These are the steps used for the first build (Windows 11, i7-12700H, 16 GB RAM).

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
   ./mach --no-interactive bootstrap --application-choice browser
   ./mach build
   ./mach run
   ```

On the first machine, bootstrap took about 12 minutes and the full build took
**about 69 minutes** (4155 s), with Windows Defender left at its defaults.
Adding Defender exclusions for `C:\goat`, `C:\mozilla-build` and
`%USERPROFILE%\.mozbuild` should make builds faster.

The build output is in `engine/obj-x86_64-pc-windows-msvc/dist/bin/firefox.exe`.
Until our branding is added, the unbranded build shows the name "Nightly".

## License

Goat Browser is licensed under the [Mozilla Public License 2.0](LICENSE), the
same license as the Firefox source it is based on. "Firefox" is a Mozilla
trademark, and Goat Browser is not affiliated with or endorsed by Mozilla.
