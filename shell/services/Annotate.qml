pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../core"
import "../annotate/geometry.mjs" as G

/**
 * The screenshot editor (Print): freeze the screen, pick a region, a window
 * or a monitor, mark it up, then copy, save or upload it. The windows are
 * annotate/AnnotateLayer (one per screen); this holds the state they share.
 *
 * Phases: "idle"; "selecting" (the frozen screen, a loupe, windows
 * highlighted; drag a region or click a window — in monitor mode a click
 * takes the monitor); "editing" (the selection with its handles, the tools);
 * "away" (hidden while a save dialog is open).
 *
 * Twelve tools: select, rect, ellipse, line, arrow, pen, marker, step, text,
 * blur, pixelate, zoom. Each remembers its own color, width and fill
 * (Settings.annotateStyles). Undo and redo keep up to 100 snapshots.
 *
 * Copy, save and upload ask the selection's layer for the image
 * (`exportRequested`); it renders the screenshot and its marks at the
 * screen's full resolution and hands the file back to `deliver`.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string uploadUrl: "https://litterbox.catbox.moe/resources/internals/api.php"

    property string phase: "idle"
    readonly property bool active: phase !== "idle"
    property string mode: "region"
    /** The screen that had focus when it opened (keyboard), then the selection's. */
    property string screenName: ""
    property rect selection: Qt.rect(0, 0, 0, 0)

    property var items: []
    property var draft: null
    property int selected: -1
    property var past: []
    property var future: []

    /** "" | "color" | "width" | "settings" */
    property string popover: ""
    /** The text being typed, if any (then other keys are off). */
    property bool typing: false

    readonly property var tools: ["select", "rect", "ellipse", "line", "arrow", "pen", "marker", "step", "text", "blur", "pixelate", "zoom"]
    readonly property var toolKeys: ({ v: "select", r: "rect", o: "ellipse", l: "line", a: "arrow", p: "pen", h: "marker", n: "step", t: "text", b: "blur", x: "pixelate", z: "zoom" })
    readonly property var swatches: ["#ff453a", "#ffffff", "#1c1c1e", "#ffd60a", "#30d158", "#0a84ff", "#bf5af2"]

    property string tool: tools.includes(Settings.annotateTool) ? Settings.annotateTool : "rect"
    property var styles: {
        try {
            return JSON.parse(Settings.annotateStyles || "{}");
        } catch (e) {
            return {};
        }
    }
    readonly property var style: Object.assign({ color: "#ff453a", width: 4, filled: false }, styles[tool] ?? {})
    readonly property bool fillable: tool === "rect" || tool === "ellipse"

    signal exportRequested(string action)

    // --- Opening and closing -------------------------------------------------------

    function start(m) {
        if (active)
            return;
        mode = m === "monitor" ? "monitor" : "region";
        screenName = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : (Quickshell.screens[0]?.name ?? "");
        selection = Qt.rect(0, 0, 0, 0);
        items = [];
        draft = null;
        selected = -1;
        past = [];
        future = [];
        popover = "";
        typing = false;
        Hyprland.refreshToplevels();
        Quickshell.execDetached(["mkdir", "-p", folder]);
        phase = "selecting";
    }

    function close() {
        phase = "idle";
        popover = "";
        typing = false;
        draft = null;
    }

    /** The selection is made: on to editing, on `screen`. */
    function choose(screen, rect) {
        screenName = screen;
        selection = rect;
        phase = "editing";
    }

    function resizeSelection(rect) {
        selection = rect;
    }

    /** Esc: the innermost thing first, as rishot does. */
    function back() {
        if (typing) {
            draft = null;
            typing = false;
        } else if (popover.length) {
            popover = "";
        } else if (selected >= 0) {
            selected = -1;
        } else {
            close();
        }
    }

    // --- Tools and their style -------------------------------------------------------

    function setTool(t) {
        if (!tools.includes(t))
            return;
        commitText();
        tool = t;
        Settings.annotateTool = t;
        selected = -1;
        popover = "";
    }

    function setStyle(change) {
        const all = Object.assign({}, styles);
        all[tool] = Object.assign({}, style, change);
        styles = all;
        saveStyles.restart();
        if (draft) {
            const d = Object.assign({}, draft, change);
            if (d.type === "text")
                d.size = G.textSize(d.width);
            draft = d;
        }
    }
    function setColor(c) {
        setStyle({ color: c });
    }
    function setWidth(w) {
        setStyle({ width: Math.max(1, Math.min(20, Math.round(w))) });
    }
    function toggleFill() {
        if (fillable)
            setStyle({ filled: !style.filled });
    }

    Timer {
        id: saveStyles
        interval: 400
        onTriggered: Settings.annotateStyles = JSON.stringify(root.styles)
    }

    // --- The annotations ---------------------------------------------------------------

    function snapshot() {
        past = past.concat([JSON.stringify(items)]).slice(-100);
        future = [];
    }

    /** A new annotation from the tool's style; `extra` sets its geometry. */
    function make(extra) {
        return Object.assign({ type: tool, color: style.color, width: style.width, filled: fillable && style.filled }, extra);
    }

    function add(a) {
        if (!G.worthKeeping(a))
            return;
        snapshot();
        items = items.concat([a]);
    }

    function moveSelected(dx, dy) {
        if (selected < 0 || (dx === 0 && dy === 0))
            return;
        snapshot();
        const list = items.slice();
        list[selected] = G.moved(list[selected], dx, dy);
        items = list;
    }

    function deleteSelected() {
        if (selected < 0)
            return;
        snapshot();
        items = items.filter((a, i) => i !== selected);
        selected = -1;
    }

    function undo() {
        if (!past.length)
            return;
        future = future.concat([JSON.stringify(items)]);
        items = JSON.parse(past[past.length - 1]);
        past = past.slice(0, -1);
        selected = -1;
    }

    function redo() {
        if (!future.length)
            return;
        past = past.concat([JSON.stringify(items)]);
        items = JSON.parse(future[future.length - 1]);
        future = future.slice(0, -1);
        selected = -1;
    }

    function commitText() {
        if (typing && draft) {
            const d = draft;
            draft = null;
            typing = false;
            add(d);
        }
    }

    // --- Keys --------------------------------------------------------------------------

    /** The editor's keyboard; true when handled. */
    function key(event) {
        if (typing)
            return false;
        const ctrl = event.modifiers & Qt.ControlModifier;
        if (event.modifiers & (Qt.AltModifier | Qt.MetaModifier))
            return false;
        if (event.key === Qt.Key_Escape) {
            back();
            return true;
        }
        if (ctrl) {
            const k = event.key;
            if (k === Qt.Key_C) copy();
            else if (k === Qt.Key_S) save();
            else if (k === Qt.Key_U) upload();
            else if (k === Qt.Key_Z && (event.modifiers & Qt.ShiftModifier)) redo();
            else if (k === Qt.Key_Z) undo();
            else if (k === Qt.Key_Y) redo();
            else return false;
            return true;
        }
        if (phase !== "editing" && phase !== "selecting")
            return false;
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && phase === "editing") {
            copy();
            return true;
        }
        if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && selected >= 0) {
            deleteSelected();
            return true;
        }
        const t = event.text;
        if (toolKeys[t]) {
            setTool(toolKeys[t]);
            return true;
        }
        if (phase !== "editing")
            return false;
        if (t === "c") popover = popover === "color" ? "" : "color";
        else if (t === "w") popover = popover === "width" ? "" : "width";
        else if (t === "f") toggleFill();
        else if (t === ",") popover = popover === "settings" ? "" : "settings";
        else return false;
        return true;
    }

    // --- Copy, save, upload -------------------------------------------------------------

    function copy() {
        if (phase === "editing")
            request("copy");
        else
            close();
    }
    function save() {
        if (phase === "editing")
            request("save");
    }
    function upload() {
        if (phase === "editing")
            request("upload");
    }

    function request(action) {
        commitText();
        selected = -1;
        popover = "";
        exportRequested(action);
    }

    function stamp() {
        const now = new Date();
        return { date: Qt.formatDate(now, "yyyy-MM-dd"), time: Qt.formatTime(now, "HH.mm.ss") };
    }
    readonly property string folder: Settings.annotateFolder || home + "/Pictures/Screenshots"
    function savePath() {
        return folder + "/" + I18n.tr("capture.shotFile", stamp()) + ".png";
    }
    /** Where the layer should write the image for an action. */
    function targetFor(action) {
        if (action === "save" || (action === "copy" && Settings.annotateKeepCopy))
            return savePath();
        return runtime + `/aurora-shot-${Date.now()}.png`;
    }

    /** The layer wrote the image to `file`: finish the action. */
    function deliver(action, file) {
        const notify = 'notify() { r=$(notify-send -a aurora -i "$1" -A open="$4" "$2" "$3"); [ "$r" = open ] && xdg-open "$1"; }; ';
        if (action === "copy") {
            if (Settings.annotateKeepCopy) {
                run('wl-copy --type image/png < "$1"; ' + notify + 'notify "$1" "$2" "$3" "$4"',
                    [file, I18n.tr("annotate.copied"), file.replace(home, "~"), I18n.tr("annotate.open")]);
            } else {
                run('wl-copy --type image/png < "$1"; rm -f "$1"; notify-send -a aurora "$2"', [file, I18n.tr("annotate.copiedOnly")]);
            }
            close();
        } else if (action === "save") {
            const copyToo = Settings.annotateCopyOnSave ? 'wl-copy --type image/png < "$1"; ' : "";
            if (Settings.annotateAskWhere) {
                phase = "away";
                askProc.file = file;
                askProc.command = ["kdialog", "--getsavefilename", file, "*.png"];
                askProc.running = true;
                return;
            }
            run(copyToo + notify + 'notify "$1" "$2" "$3" "$4"', [file, I18n.tr("annotate.saved"), file.replace(home, "~"), I18n.tr("annotate.open")]);
            close();
        } else if (action === "upload") {
            run('url=$(curl -sf --proto =https --max-time 30 -A "Mozilla/5.0" -F reqtype=fileupload -F time=72h -F "fileToUpload=@$1" "$2"); rm -f "$1"; '
                + 'case "$url" in http*) printf %s "$url" | wl-copy; notify-send -a aurora "$3" "$url";; *) notify-send -a aurora -u critical "$4";; esac',
                [file, uploadUrl, I18n.tr("annotate.linkCopied"), I18n.tr("annotate.uploadFailed")]);
            close();
        }
    }

    /** Choose the save folder (the editor steps aside for the dialog). */
    function pickFolder() {
        popover = "";
        phase = "away";
        folderProc.command = ["kdialog", "--getexistingdirectory", folder];
        folderProc.running = true;
    }
    Process {
        id: folderProc
        stdout: StdioCollector {
            id: folderOut
        }
        onExited: code => {
            const dir = folderOut.text.trim();
            if (code === 0 && dir.length) {
                Settings.annotateFolder = dir;
                Quickshell.execDetached(["mkdir", "-p", dir]);
            }
            root.phase = "editing";
        }
    }

    function run(script, args) {
        Quickshell.execDetached(["bash", "-c", script, "_"].concat(args));
    }

    // Save with "ask where": the file is written already; move it where the user says.
    Process {
        id: askProc
        property string file: ""
        stdout: StdioCollector {
            id: askOut
        }
        onExited: code => {
            const dest = askOut.text.trim();
            if (code !== 0 || !dest.length) {
                // Cancelled: back to the editor (the auto-saved file stays, as before).
                root.phase = "editing";
                return;
            }
            const copyToo = Settings.annotateCopyOnSave ? 'wl-copy --type image/png < "$2"; ' : "";
            root.run('[ "$1" = "$2" ] || mv -f "$1" "$2"; ' + copyToo + 'notify-send -a aurora "$3" "$4"',
                [askProc.file, dest, I18n.tr("annotate.saved"), dest.replace(root.home, "~")]);
            root.close();
        }
    }

    GlobalShortcut { appid: "aurora"; name: "screenshot"; description: "Screenshot a region and mark it up"; onPressed: root.start("region") }
    GlobalShortcut { appid: "aurora"; name: "screenshotMonitor"; description: "Screenshot a monitor and mark it up"; onPressed: root.start("monitor") }
}
