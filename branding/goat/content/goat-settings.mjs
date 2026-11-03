/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

// Goat settings pane for about:preferences (registered as "goat" in
// preferences.js by patches/0005). Every control reads and writes a real pref,
// so everything here can also be changed or reset in about:config.
//
// HTTPS-Only and "delete cookies and site data when closed" are the Privacy
// pane's own settings (httpsOnlyRadioGroup, deleteOnClose), which
// config/privacy.mjs registers when the page loads. Prefs go through
// Preferences.mjs: one that a stock pane already added is reused, otherwise
// it is added here.

import { Preferences } from "chrome://global/content/preferences/Preferences.mjs";
import { SettingGroupManager } from "chrome://browser/content/preferences/config/SettingGroupManager.mjs";

const lazy = {};
ChromeUtils.defineESModuleGetters(lazy, {
  AddonManager: "resource://gre/modules/AddonManager.sys.mjs",
});

const THEME_DARK = "goat-dark@goat-browser";
const THEME_LIGHT = "goat-light@goat-browser";
const THEME_SYSTEM = "default-theme@mozilla.org";
const UBLOCK_ID = "uBlock0@raymondhill.net";

/** The Preference for `id`, added only if no stock pane has added it. */
function pref(id, type) {
  return Preferences.get(id) ?? Preferences.add({ id, type });
}

pref("extensions.activeThemeID", "string");
pref("sidebar.verticalTabs", "bool");
pref("sidebar.revamp", "bool");
pref("browser.uidensity", "int");
pref("browser.compactmode.show", "bool");
pref("browser.toolbars.bookmarks.visibility", "string");
pref("privacy.resistFingerprinting", "bool");
pref("privacy.resistFingerprinting.exemptedDomains", "string");

function topWindow() {
  return window.browsingContext.topChromeWindow;
}

// --- Appearance --------------------------------------------------------------

Preferences.addSetting({
  id: "goat-theme",
  pref: "extensions.activeThemeID",
  // Enabling the add-on updates the pref; returning a promise tells the
  // setting not to write it as well.
  set: themeId =>
    lazy.AddonManager.getAddonByID(themeId)
      .then(addon => addon?.enable())
      .catch(console.error),
});

Preferences.addSetting({
  id: "goat-vertical-tabs",
  pref: "sidebar.verticalTabs",
  set(enabled) {
    if (enabled) {
      // Vertical tabs live in the new sidebar.
      Preferences.get("sidebar.revamp").value = true;
    }
    return enabled;
  },
  disabled: () => Preferences.get("sidebar.revamp").locked,
});

Preferences.addSetting({
  id: "goat-compact",
  pref: "browser.uidensity",
  get: density => density == 1,
  set(enabled) {
    if (enabled) {
      // Also make "Compact" selectable in Customize Toolbar.
      Preferences.get("browser.compactmode.show").value = true;
    }
    return enabled ? 1 : 0;
  },
});

Preferences.addSetting({
  id: "goat-bookmarks-toolbar",
  pref: "browser.toolbars.bookmarks.visibility",
});

// --- Privacy level -----------------------------------------------------------

Preferences.addSetting({
  id: "goat-privacy-level",
  pref: "privacy.resistFingerprinting",
  get: rfp => (rfp ? "maximum" : "balanced"),
  // "Balanced" relies on Fingerprinting Protection (privacy.fingerprintingProtection),
  // which strict Enhanced Tracking Protection already turns on.
  set: level => level == "maximum",
});

Preferences.addSetting({
  id: "goat-rfp-exempt",
  pref: "privacy.resistFingerprinting.exemptedDomains",
  deps: ["goat-privacy-level"],
  visible: ({ "goat-privacy-level": level }) => level.value == "maximum",
  set: value =>
    String(value)
      .split(",")
      .map(s => s.trim())
      .filter(Boolean)
      .join(","),
});

// --- Privacy toggles ---------------------------------------------------------

Preferences.addSetting({
  id: "goat-ublock-dashboard",
  disabled: () => !WebExtensionPolicy.getByID(UBLOCK_ID),
  onUserClick(e) {
    e.preventDefault();
    let policy = WebExtensionPolicy.getByID(UBLOCK_ID);
    if (policy) {
      topWindow().openTrustedLinkIn(policy.getURL("dashboard.html"), "tab");
    }
  },
});

// --- Keyboard shortcuts ------------------------------------------------------

Preferences.addSetting({
  id: "goat-shortcuts-link",
  onUserClick(e) {
    e.preventDefault();
    topWindow().openTrustedLinkIn("about:keyboard", "tab");
  },
});

SettingGroupManager.registerGroups({
  goatAppearance: {
    l10nId: "goat-appearance-group",
    iconSrc: "chrome://browser/skin/customize.svg",
    headingLevel: 2,
    items: [
      {
        id: "goat-theme",
        l10nId: "goat-theme",
        control: "moz-radio-group",
        options: [
          { value: THEME_DARK, l10nId: "goat-theme-dark" },
          { value: THEME_LIGHT, l10nId: "goat-theme-light" },
          { value: THEME_SYSTEM, l10nId: "goat-theme-system" },
        ],
      },
      { id: "goat-vertical-tabs", l10nId: "goat-vertical-tabs", control: "moz-toggle" },
      { id: "goat-compact", l10nId: "goat-compact", control: "moz-toggle" },
      {
        id: "goat-bookmarks-toolbar",
        l10nId: "goat-bookmarks-toolbar",
        control: "moz-select",
        options: [
          { value: "always", l10nId: "goat-bookmarks-toolbar-always" },
          { value: "newtab", l10nId: "goat-bookmarks-toolbar-newtab" },
          { value: "never", l10nId: "goat-bookmarks-toolbar-never" },
        ],
      },
    ],
  },
  goatPrivacyLevel: {
    l10nId: "goat-privacy-level-group",
    iconSrc: "chrome://browser/skin/preferences/category-privacy-security.svg",
    headingLevel: 2,
    items: [
      {
        id: "goat-privacy-level",
        l10nId: "goat-privacy-level",
        control: "moz-radio-group",
        options: [
          { value: "maximum", l10nId: "goat-privacy-level-maximum" },
          { value: "balanced", l10nId: "goat-privacy-level-balanced" },
        ],
      },
      {
        id: "goat-rfp-exempt",
        l10nId: "goat-rfp-exempt",
        control: "moz-input-text",
      },
    ],
  },
  goatPrivacyToggles: {
    l10nId: "goat-privacy-toggles-group",
    iconSrc: "chrome://browser/skin/controlcenter/3rdpartycookies.svg",
    headingLevel: 2,
    items: [
      // The Privacy pane's settings, with Goat's labels.
      {
        id: "httpsOnlyRadioGroup",
        l10nId: "goat-https-only",
        control: "moz-radio-group",
        controlAttrs: { id: "goat-https-only" },
        options: [
          { value: "enabled", l10nId: "httpsonly-radio-enabled" },
          { value: "privateOnly", l10nId: "httpsonly-radio-enabled-pbm" },
          { value: "disabled", l10nId: "httpsonly-radio-disabled3" },
        ],
      },
      {
        id: "deleteOnClose",
        l10nId: "goat-clear-on-close",
        control: "moz-toggle",
        controlAttrs: { id: "goat-clear-on-close" },
      },
      {
        id: "goat-ublock-dashboard",
        l10nId: "goat-ublock-dashboard",
        control: "moz-box-button",
      },
    ],
  },
  goatShortcuts: {
    l10nId: "goat-shortcuts-group",
    iconSrc: "chrome://global/skin/icons/settings.svg",
    headingLevel: 2,
    items: [
      {
        id: "goat-shortcuts-link",
        l10nId: "goat-shortcuts-link",
        control: "moz-box-link",
      },
    ],
  },
});
