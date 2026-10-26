/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this file,
 * You can obtain one at http://mozilla.org/MPL/2.0/. */

// Goat settings pane for about:preferences (registered as "goat" in
// preferences.js by patches/0005). Every control reads and writes a real pref,
// so everything here can also be changed or reset in about:config.
//
// Settings talk to Services.prefs directly instead of registering
// Preferences.add() entries, because the stock panes register some of the
// same prefs and Preferences.add() throws on duplicates.

import { Preferences } from "chrome://global/content/preferences/Preferences.mjs";
import { SettingGroupManager } from "chrome://browser/content/preferences/config/SettingGroupManager.mjs";

const lazy = {};
ChromeUtils.defineESModuleGetters(lazy, {
  AddonManager: "resource://gre/modules/AddonManager.sys.mjs",
  Sanitizer: "resource:///modules/Sanitizer.sys.mjs",
});

const THEME_DARK = "goat-dark@goat-browser";
const THEME_LIGHT = "goat-light@goat-browser";
const THEME_SYSTEM = "default-theme@mozilla.org";
const UBLOCK_ID = "uBlock0@raymondhill.net";

// Cleaning prefs that "clear cookies and site data on close" must not turn on.
// Mirrors SANITIZE_ON_SHUTDOWN_PREFS_ONLY_V2 in config/privacy.mjs.
const OTHER_SHUTDOWN_CLEANING_PREFS = [
  "privacy.clearOnShutdown_v2.browsingHistoryAndDownloads",
  "privacy.clearOnShutdown_v2.siteSettings",
];

function readPref(name) {
  switch (Services.prefs.getPrefType(name)) {
    case Services.prefs.PREF_BOOL:
      return Services.prefs.getBoolPref(name);
    case Services.prefs.PREF_INT:
      return Services.prefs.getIntPref(name);
    case Services.prefs.PREF_STRING:
      return Services.prefs.getStringPref(name);
  }
  return undefined;
}

function writePref(name, value) {
  switch (typeof value) {
    case "boolean":
      Services.prefs.setBoolPref(name, value);
      break;
    case "number":
      Services.prefs.setIntPref(name, value);
      break;
    default:
      Services.prefs.setStringPref(name, String(value));
  }
}

/**
 * A setting backed by one or more prefs (the first is the main one).
 * `get` maps the main pref's value to the control value; `set` writes prefs.
 */
function addPrefSetting(id, prefs, { get, set, ...rest } = {}) {
  prefs = [].concat(prefs);
  Preferences.addSetting({
    id,
    setup(emitChange) {
      for (let p of prefs) {
        Services.prefs.addObserver(p, emitChange);
      }
      return () => {
        for (let p of prefs) {
          Services.prefs.removeObserver(p, emitChange);
        }
      };
    },
    get: () => {
      let value = readPref(prefs[0]);
      return get ? get(value) : value;
    },
    set: value => {
      if (set) {
        set(value);
      } else {
        writePref(prefs[0], value);
      }
    },
    disabled: () => prefs.some(p => Services.prefs.prefIsLocked(p)),
    ...rest,
  });
}

function topWindow() {
  return window.browsingContext.topChromeWindow;
}

// --- Appearance --------------------------------------------------------------

addPrefSetting("goat-theme", "extensions.activeThemeID", {
  set(themeId) {
    lazy.AddonManager.getAddonByID(themeId)
      .then(addon => addon?.enable())
      .catch(console.error);
  },
});

addPrefSetting("goat-vertical-tabs", ["sidebar.verticalTabs", "sidebar.revamp"], {
  set(enabled) {
    if (enabled) {
      // Vertical tabs live in the new sidebar.
      Services.prefs.setBoolPref("sidebar.revamp", true);
    }
    Services.prefs.setBoolPref("sidebar.verticalTabs", enabled);
  },
});

addPrefSetting("goat-compact", ["browser.uidensity", "browser.compactmode.show"], {
  get: density => density == 1,
  set(enabled) {
    if (enabled) {
      // Also make "Compact" selectable in Customize Toolbar.
      Services.prefs.setBoolPref("browser.compactmode.show", true);
    }
    Services.prefs.setIntPref("browser.uidensity", enabled ? 1 : 0);
  },
});

addPrefSetting("goat-bookmarks-toolbar", "browser.toolbars.bookmarks.visibility");

// --- Privacy level -----------------------------------------------------------

addPrefSetting("goat-privacy-level", "privacy.resistFingerprinting", {
  get: rfp => (rfp ? "maximum" : "balanced"),
  // "Balanced" relies on Fingerprinting Protection (privacy.fingerprintingProtection),
  // which strict Enhanced Tracking Protection already turns on.
  set: level =>
    Services.prefs.setBoolPref(
      "privacy.resistFingerprinting",
      level == "maximum"
    ),
});

addPrefSetting(
  "goat-rfp-exempt",
  "privacy.resistFingerprinting.exemptedDomains",
  {
    deps: ["goat-privacy-level"],
    visible: ({ "goat-privacy-level": level }) => level.value == "maximum",
    set: value =>
      Services.prefs.setStringPref(
        "privacy.resistFingerprinting.exemptedDomains",
        String(value)
          .split(",")
          .map(s => s.trim())
          .filter(Boolean)
          .join(",")
      ),
  }
);

// --- Privacy toggles ---------------------------------------------------------

addPrefSetting("goat-https-only", "dom.security.https_only_mode");

addPrefSetting(
  "goat-clear-on-close",
  [
    "privacy.sanitize.sanitizeOnShutdown",
    "privacy.clearOnShutdown_v2.cookiesAndStorage",
    "privacy.clearOnShutdown_v2.cache",
  ],
  {
    // Same semantics as "Delete cookies and site data when closed" in the
    // Privacy pane (config/privacy.mjs, "deleteOnClose").
    get: () =>
      Services.prefs.getBoolPref("privacy.sanitize.sanitizeOnShutdown") &&
      Services.prefs.getBoolPref("privacy.clearOnShutdown_v2.cookiesAndStorage") &&
      Services.prefs.getBoolPref("privacy.clearOnShutdown_v2.cache"),
    set(enabled) {
      lazy.Sanitizer.maybeMigratePrefs("clearOnShutdown");
      let sanitizeWasOn = Services.prefs.getBoolPref(
        "privacy.sanitize.sanitizeOnShutdown"
      );
      Services.prefs.setBoolPref(
        "privacy.clearOnShutdown_v2.cookiesAndStorage",
        enabled
      );
      Services.prefs.setBoolPref("privacy.clearOnShutdown_v2.cache", enabled);
      if (!sanitizeWasOn) {
        // Don't let sanitizeOnShutdown also clear history etc.
        for (let p of OTHER_SHUTDOWN_CLEANING_PREFS) {
          Services.prefs.setBoolPref(p, false);
        }
      }
      let otherCleaning = OTHER_SHUTDOWN_CLEANING_PREFS.some(p =>
        Services.prefs.getBoolPref(p, false)
      );
      Services.prefs.setBoolPref(
        "privacy.sanitize.sanitizeOnShutdown",
        enabled || otherCleaning
      );
    },
  }
);

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
      { id: "goat-https-only", l10nId: "goat-https-only", control: "moz-toggle" },
      { id: "goat-clear-on-close", l10nId: "goat-clear-on-close", control: "moz-toggle" },
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
        controlAttrs: { href: "about:keyboard" },
      },
    ],
  },
});
