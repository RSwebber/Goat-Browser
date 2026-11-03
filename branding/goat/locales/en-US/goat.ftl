# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

## Goat Browser strings (loaded as branding/goat.ftl).

## About dialog

goat-about-desc = { -brand-full-name } is a privacy-focused browser built on <label data-l10n-name="goat-firefox-link">Firefox ESR by Mozilla</label>, thanks to its <label data-l10n-name="goat-credits-link">global community</label>.
goat-about-project = Source code and project page: <label data-l10n-name="goat-project-link">github.com/RSwebber/Goat-Browser</label>

## Settings: navigation and pane

pane-goat-title = Goat
    .title = Goat
goat-pane-header =
    .heading = Goat

## Settings: Appearance

goat-appearance-group =
    .label = Appearance
    .description = Goat’s look and layout. Each option is a normal preference you can change back at any time.
goat-theme =
    .label = Theme
goat-theme-dark =
    .label = Goat Dark
goat-theme-light =
    .label = Goat Light
goat-theme-system =
    .label = System (follow Windows light/dark)
goat-vertical-tabs =
    .label = Vertical tabs
    .description = Show tabs in the sidebar instead of across the top.
goat-compact =
    .label = Compact density
    .description = Smaller toolbars and tabs.
goat-bookmarks-toolbar =
    .label = Bookmarks toolbar
goat-bookmarks-toolbar-always =
    .label = Always show
goat-bookmarks-toolbar-newtab =
    .label = Only on new tab
goat-bookmarks-toolbar-never =
    .label = Never show

## Settings: Privacy level

goat-privacy-level-group =
    .label = Privacy level
    .description = Maximum forces light mode on websites and shows them UTC times. Balanced keeps dark mode and your local time with slightly weaker fingerprinting protection.
goat-privacy-level =
    .label = Fingerprinting protection
goat-privacy-level-maximum =
    .label = Maximum (resist fingerprinting)
    .description = Websites see a standardized browser: light mode, UTC time zone, rounded window size.
goat-privacy-level-balanced =
    .label = Balanced (fingerprinting protection)
    .description = Blocks known fingerprinting techniques but keeps dark mode and your local time zone.
goat-rfp-exempt =
    .label = Sites exempt from Maximum protection
    .description = Comma-separated, e.g. example.com, *.example.org. These sites see dark mode and your local time, and get no resist-fingerprinting protection at all.
    .placeholder = example.com, *.example.org

## Settings: Privacy toggles

goat-privacy-toggles-group =
    .label = Privacy
goat-https-only =
    .label = HTTPS-Only Mode
    .description = Only connect to websites over secure HTTPS, and ask before loading an insecure site.
goat-clear-on-close =
    .label = Clear cookies and site data when { -brand-short-name } closes
    .description = Signs you out of websites every time you quit. History is not affected.
goat-ublock-dashboard =
    .label = Open uBlock Origin dashboard

## Settings: Translator

goat-translator-group =
    .label = Translator
    .description = Translates into English on this computer, so the text you translate is never sent to a server. Each language model is downloaded once from Mozilla the first time you use it.
goat-translate-pages =
    .label = Translate web pages
    .description = Shows a translate button in the address bar on pages that aren’t in English.
goat-translate-offer =
    .label = Offer to translate automatically
    .description = Open the translation panel as soon as a page in another language loads.
goat-translate-selection =
    .label = Translate selected text
    .description = Right-click highlighted text and choose Translate Selection.
goat-translate-text =
    .label = Translate text you paste or type
goat-translate-languages =
    .label = Languages and downloads
    .description = Pick languages to always or never translate, and download or remove language models.

## Settings: Keyboard shortcuts

goat-shortcuts-group =
    .label = Keyboard shortcuts
goat-shortcuts-link =
    .label = Customize keyboard shortcuts
