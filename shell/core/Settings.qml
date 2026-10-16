pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * User preferences, persisted as JSON in $XDG_STATE_HOME/aurora/settings.json.
 * Everything visual reads its appearance from here through Tokens and Motion;
 * nothing else should touch this file. Writes are debounced by FileView, and
 * an external edit to the file is picked up live.
 */
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/aurora"

    /** "dark" or "light". */
    property alias appearance: adapter.appearance
    /** Accent color as "#RRGGBB"; empty uses the system blue for the appearance. */
    property alias accent: adapter.accent
    /** Replace movement with cross-fades (macOS Reduce Motion). */
    property alias reduceMotion: adapter.reduceMotion
    /** Replace glass with opaque fills (macOS Reduce Transparency). */
    property alias reduceTransparency: adapter.reduceTransparency
    /** Tint strength of the menu bar's glass, 0 (clear) to 1 (opaque veil). */
    property alias barTint: adapter.barTint
    /** Wallpaper path; empty means "ask the wallpaper daemon". */
    property alias wallpaper: adapter.wallpaper
    /** Interface language ("en", "es"…); empty follows the system. See I18n. */
    property alias language: adapter.language
    /** Region for dates and numbers, e.g. "es_AR"; empty uses the language's default. */
    property alias locale: adapter.locale
    /** Show the battery percentage next to its menu bar icon. */
    property alias batteryPercent: adapter.batteryPercent

    readonly property bool dark: appearance !== "light"

    FileView {
        path: root.stateDir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // First run: the file doesn't exist yet, so write the defaults.
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property string appearance: "dark"
            property string accent: ""
            property bool reduceMotion: false
            property bool reduceTransparency: false
            property real barTint: 0.25
            property string wallpaper: ""
            property string language: "es"
            property string locale: ""
            property bool batteryPercent: true
        }
    }
}
