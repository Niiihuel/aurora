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
    /** Accent color as "#RRGGBB"; empty follows the wallpaper (system blue if it's grey). */
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
    /** Do Not Disturb: notifications arrive silently, without banners. */
    property alias doNotDisturb: adapter.doNotDisturb
    /** Play a sound when a notification arrives. */
    property alias notificationSounds: adapter.notificationSounds
    /** Show seconds in the menu bar clock. */
    property alias clockSeconds: adapter.clockSeconds
    /** Night light colour temperature, kelvin. */
    property alias nightLightTemperature: adapter.nightLightTemperature
    /** Minutes of inactivity before the screen turns off / the session locks / the computer sleeps; 0 = never. */
    property alias idleScreenOff: adapter.idleScreenOff
    property alias idleLock: adapter.idleLock
    property alias idleSuspend: adapter.idleSuspend
    /**
     * Screenshots and recordings (Super+D): the last mode
     * ("shotScreen" | "shotSelection" | "recordScreen" | "recordSelection"),
     * where they go ("default" = Pictures/Videos, "desktop", "documents",
     * "clipboard" for screenshots), the timer in seconds, sound, the pointer,
     * and the last selection ("screen x y w h", kept when `captureRemember`).
     */
    property alias captureMode: adapter.captureMode
    property alias captureSaveTo: adapter.captureSaveTo
    property alias captureTimer: adapter.captureTimer
    property alias captureMic: adapter.captureMic
    property alias captureSystemAudio: adapter.captureSystemAudio
    property alias capturePointer: adapter.capturePointer
    property alias captureRemember: adapter.captureRemember
    property alias captureSelection: adapter.captureSelection
    /**
     * The screenshot editor (Print): the last tool, each tool's style as JSON
     * ({ tool: { color, width, filled } }), the effects' strength (pixelate
     * cell, blur radius, zoom factor), and saving: keep a copy on disk when
     * copying, ask where to save, the folder ("" = Pictures/Screenshots),
     * and copy to the clipboard when saving.
     */
    property alias annotateTool: adapter.annotateTool
    property alias annotateStyles: adapter.annotateStyles
    property alias annotateMosaic: adapter.annotateMosaic
    property alias annotateBlur: adapter.annotateBlur
    property alias annotateZoom: adapter.annotateZoom
    property alias annotateKeepCopy: adapter.annotateKeepCopy
    property alias annotateAskWhere: adapter.annotateAskWhere
    property alias annotateFolder: adapter.annotateFolder
    property alias annotateCopyOnSave: adapter.annotateCopyOnSave

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
            property bool doNotDisturb: false
            property bool notificationSounds: true
            property bool clockSeconds: true
            property int nightLightTemperature: 4500
            property int idleScreenOff: 10
            property int idleLock: 0
            property int idleSuspend: 0
            property string captureMode: "recordSelection"
            property string captureSaveTo: "default"
            property int captureTimer: 0
            property bool captureMic: false
            property bool captureSystemAudio: true
            property bool capturePointer: true
            property bool captureRemember: true
            property string captureSelection: ""
            property string annotateTool: "rect"
            property string annotateStyles: "{}"
            property int annotateMosaic: 14
            property int annotateBlur: 64
            property real annotateZoom: 2.0
            property bool annotateKeepCopy: false
            property bool annotateAskWhere: false
            property string annotateFolder: ""
            property bool annotateCopyOnSave: false
        }
    }
}
