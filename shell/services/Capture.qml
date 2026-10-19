pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../core"

/**
 * Screenshots and screen recordings, after macOS's Screenshot (⇧⌘5): Super+D
 * opens the capture toolbar (capture/CaptureLayer) on the focused screen;
 * the mode — capture or record, the entire screen or a selection — and the
 * options persist in Settings (capture*).
 *
 * States: "idle"; "choosing" (toolbar up, selection editable); "countdown"
 * (the timer); "recording"; "busy" (taking a screenshot or finishing a
 * recording). The UI hides before anything is captured, so it never shows
 * in the result.
 *
 * Screenshots are grim (to a file, or the clipboard); recordings are
 * gpu-screen-recorder (-w <monitor> or -w region), stopped with SIGINT so it
 * finalizes the file. When one is done, `finished(file, thumb, kind)` hands
 * the floating thumbnail its picture: the screenshot itself, or a frame of
 * the recorded area taken just before stopping.
 *
 * Rects are in the screen's own logical points; grim and gsr get them in
 * the global layout (screen origin added).
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cache: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/aurora/capture"

    property string state: "idle"
    readonly property bool active: state !== "idle"
    property string screenName: ""
    /** The selection, in the screen's logical points. */
    property rect selection: Qt.rect(0, 0, 0, 0)
    property int countdown: 0
    property int elapsed: 0

    readonly property string mode: Settings.captureMode
    readonly property bool recordMode: mode.startsWith("record")
    readonly property bool selectionMode: mode.endsWith("Selection")
    readonly property var screen: Quickshell.screens.find(s => s.name === screenName) ?? Quickshell.screens[0] ?? null

    /** A screenshot or recording is ready: the thumbnail shows it. */
    signal finished(string file, string thumb, string kind)

    /** Super+D: open the toolbar, or stop a recording, or close. */
    function toggle() {
        if (state === "recording")
            stop();
        else if (state === "choosing" || state === "countdown")
            cancel();
        else if (state === "idle")
            open();
    }

    function open() {
        screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens[0]?.name ?? "");
        selection = restoredSelection();
        state = "choosing";
    }

    function cancel() {
        tick.stop();
        state = "idle";
    }

    function setMode(m) {
        Settings.captureMode = m;
    }

    function setSelection(r) {
        selection = r;
        if (Settings.captureRemember)
            Settings.captureSelection = `${screenName} ${Math.round(r.x)} ${Math.round(r.y)} ${Math.round(r.width)} ${Math.round(r.height)}`;
    }

    /** The remembered selection on this screen, or a centered one. */
    function restoredSelection() {
        const w = screen ? screen.width : 1280;
        const h = screen ? screen.height : 800;
        const f = Settings.captureRemember ? Settings.captureSelection.split(" ") : [];
        if (f.length === 5 && f[0] === screenName) {
            const r = Qt.rect(Number(f[1]), Number(f[2]), Number(f[3]), Number(f[4]));
            if (r.width >= 8 && r.height >= 8 && r.x + r.width <= w && r.y + r.height <= h)
                return r;
        }
        return Qt.rect(Math.round(w * 0.2), Math.round(h * 0.2), Math.round(w * 0.6), Math.round(h * 0.6));
    }

    /** The Capture / Record button: the timer first, if any. */
    function go() {
        if (state !== "choosing")
            return;
        if (selectionMode && (selection.width < 8 || selection.height < 8))
            return;
        countdown = Settings.captureTimer;
        if (countdown > 0) {
            state = "countdown";
            tick.restart();
        } else {
            begin();
        }
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0) {
                stop();
                root.begin();
            }
        }
    }

    // The UI has to be gone from the screen before anything is captured.
    function begin() {
        state = "busy";
        afterHide.restart();
    }
    Timer {
        id: afterHide
        interval: 180
        onTriggered: root.recordMode ? root.startRecording() : root.takeScreenshot()
    }

    // --- Where things go ------------------------------------------------------

    function stamp() {
        const now = new Date();
        return {
            date: Qt.formatDate(now, "yyyy-MM-dd"),
            time: Qt.formatTime(now, "HH.mm.ss")
        };
    }

    function folderFor(kind) {
        switch (Settings.captureSaveTo) {
        case "desktop":
            return home + "/Desktop";
        case "documents":
            return home + "/Documents";
        default:
            return kind === "shot" ? home + "/Pictures/Screenshots" : home + "/Videos/Recordings";
        }
    }

    /** "X,Y WxH" for grim, "WxH+X+Y" for gsr, in the global layout. */
    function globalRect() {
        const s = screen;
        const r = selection;
        return { x: Math.round((s ? s.x : 0) + r.x), y: Math.round((s ? s.y : 0) + r.y), w: Math.round(r.width), h: Math.round(r.height) };
    }

    function grimTarget() {
        if (!selectionMode)
            return ["-o", screenName];
        const g = globalRect();
        return ["-g", `${g.x},${g.y} ${g.w}x${g.h}`];
    }

    // --- Screenshots ----------------------------------------------------------

    property string pendingFile: ""
    property string pendingThumb: ""

    function takeScreenshot() {
        const t = stamp();
        const toClipboard = Settings.captureSaveTo === "clipboard";
        const thumb = cache + `/shot-${Date.now()}.png`;
        const file = toClipboard ? "" : folderFor("shot") + "/" + I18n.tr("capture.shotFile", t) + ".png";
        pendingFile = file;
        pendingThumb = toClipboard ? thumb : file;
        // PNG level 1: grim's default (6) takes ~0.8 s for a 2880×1800 screen, this ~0.2 s.
        const grim = ["grim", "-l", "1"].concat(Settings.capturePointer ? ["-c"] : []).concat(grimTarget());
        // Into the cache first, then to its place (or the clipboard).
        shotProc.command = ["bash", "-c",
            'mkdir -p "$(dirname "$1")" && "${@:3}" "$1" && if [ -n "$2" ]; then mkdir -p "$(dirname "$2")" && cp "$1" "$2"; else wl-copy -t image/png < "$1"; fi',
            "_", thumb, file].concat(grim);
        shotProc.running = true;
    }

    Process {
        id: shotProc
        onExited: code => {
            root.state = "idle";
            if (code === 0)
                root.finished(root.pendingFile, root.pendingThumb, "shot");
            else
                root.fail();
        }
    }

    // --- Recordings -----------------------------------------------------------

    property string recordFile: ""

    function startRecording() {
        const file = folderFor("record") + "/" + I18n.tr("capture.recordingFile", stamp()) + ".mp4";
        recordFile = file;
        let target = ["-w", screenName];
        if (selectionMode) {
            const g = globalRect();
            // Encoders want even sizes.
            target = ["-w", "region", "-region", `${g.w - g.w % 2}x${g.h - g.h % 2}+${g.x}+${g.y}`];
        }
        const audio = [];
        if (Settings.captureSystemAudio)
            audio.push("default_output");
        if (Settings.captureMic)
            audio.push("default_input");
        const gsr = ["gpu-screen-recorder"].concat(target).concat([
            "-f", "60", "-q", "very_high", "-cursor", Settings.capturePointer ? "yes" : "no"
        ]).concat(audio.length ? ["-a", audio.join("|")] : []).concat(["-o", file]);
        recorder.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && shift && exec "$@"', "_", file].concat(gsr);
        elapsed = 0;
        recorder.running = true;
        state = "recording";
    }

    /** Stop recording: a frame of the area for the thumbnail, then SIGINT (gsr saves). */
    function stop() {
        if (state !== "recording")
            return;
        state = "busy";
        recordThumb = cache + `/rec-${Date.now()}.png`;
        thumbProc.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && shift && exec "$@"', "_", recordThumb, "grim", "-l", "1"].concat(grimTarget()).concat([recordThumb]);
        thumbProc.running = true;
    }

    property string recordThumb: ""

    Process {
        id: thumbProc
        onExited: recorder.signal(2)
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.state === "recording"
        onTriggered: root.elapsed += 1
    }

    property string recorderError: ""
    Process {
        id: recorder
        stderr: StdioCollector {
            onStreamFinished: root.recorderError = this.text
        }
        onExited: code => {
            const stopped = root.state === "busy";
            root.state = "idle";
            // gsr exits 0 on SIGINT after writing the file; anything else failed.
            if (stopped && (code === 0 || code === 130 || code === 2))
                root.finished(root.recordFile, root.recordThumb, "recording");
            else
                root.fail();
        }
    }

    function fail() {
        Quickshell.execDetached(["notify-send", "-a", "aurora", I18n.tr("capture.failed"), I18n.tr("capture.failedBody")]);
    }

    function openFile(file) {
        if (file)
            Quickshell.execDetached(["xdg-open", file]);
    }

    GlobalShortcut {
        appid: "aurora"
        name: "capture"
        description: "Screenshots and screen recording"
        onPressed: root.toggle()
    }
}
