# Toolchain setup notes

Recorded when the first unmodified Firefox ESR build was done on the
Windows 11 dev machine ("Silky": i7-12700H, 16 GB RAM), 2026-10-25.

## Installed manually

| Tool | Version | Source |
| --- | --- | --- |
| MozillaBuild | 4.2.1 | `MozillaBuildSetup-Latest.exe` from ftp.mozilla.org (not on winget), installed to `C:\mozilla-build` |
| Git for Windows | 2.56.0.windows.2 | already present |

Git setting: `git config --global core.longpaths true` (the Firefox tree has
very long paths).

Visual Studio / Build Tools were **not** installed. The current Mozilla guide
no longer requires them: `mach bootstrap` downloads clang-cl, the MSVC
headers/libs and the Windows SDK into `%USERPROFILE%\.mozbuild`.

## Installed by `./mach bootstrap`

| Tool | Version |
| --- | --- |
| Python (bundled with MozillaBuild) | 3.12.10 |
| Rust (rustup, stable, x86_64-pc-windows-msvc) | rustc / cargo 1.99.1 |
| clang / clang-cl | 21.1.8 |
| MSVC tools (in `~/.mozbuild/vs`) | 14.50.35717 |
| Windows SDK (in `~/.mozbuild/vs`) | 10.0.26100.0 |
| cbindgen | 0.29.4 |
| Node.js | 22.16.0 |
| NASM | 3.01 |

Plus mozmake, sccache, nsis, upx, dump_syms and other helpers under
`%USERPROFILE%\.mozbuild`.

## Branding tools

`C:\goat\.venv-tools` (gitignored) is a Python 3.12 venv with Pillow 13.0.0,
used by `scripts/make_branding.py`.

## Antivirus

Windows Defender settings were left unchanged. If builds are slow, consider
adding exclusions for `C:\goat`, `C:\mozilla-build` and
`%USERPROFILE%\.mozbuild` (Mozilla's guide recommends this).
