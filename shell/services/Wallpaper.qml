pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * Which image is on each output, for glass to refract. Settings.wallpaper wins
 * when set; otherwise the wallpaper daemon is asked (`awww query`, which prints
 * "<output>: …, currently displaying: image: <path>" per output). The daemon
 * has no change events, so the answer is refreshed on a slow timer and on
 * demand; aurora's own picker updates it at once when it applies one.
 *
 * `files` lists ~/wallpapers (subfolders too), newest first. `apply` sets one
 * on every output with a growing-circle transition that starts at `fx,fy`
 * (fractions of the screen, from its top-left) — the picker passes the
 * chosen thumbnail's centre, so the new wallpaper spreads out of it like a
 * drop — and publishes a copy for the login screen, which can't read $HOME
 * (/var/lib/aurora/login, writable by the user and readable by the greeter).
 * `next` (Super+B) applies another one at random.
 */
Singleton {
    id: root

    /** output name → absolute image path, from the daemon. */
    property var byOutput: ({})
    readonly property string dir: Quickshell.env("HOME") + "/wallpapers"
    /** Image paths, newest first. */
    property var files: []

    function rescan() {
        if (!scan.running)
            scan.running = true;
    }

    function apply(path, fx, fy) {
        const map = {};
        for (const s of Quickshell.screens)
            map[s.name] = path;
        byOutput = map;
        Quickshell.execDetached(["sh", "-c",
            "awww img \"$1\" --transition-type grow --transition-pos \"$2,$3\" --transition-duration 1.1 --transition-fps 120 --transition-bezier .32,.72,0,1",
            "_", path, Math.max(0, Math.min(1, fx)).toFixed(3), Math.max(0, Math.min(1, 1 - fy)).toFixed(3)]);
        publish(path);
    }

    /** Another wallpaper from ~/wallpapers, at random, growing from the middle. */
    function next() {
        const current = pathFor(Quickshell.screens.length ? Quickshell.screens[0].name : "");
        const others = files.filter(f => f !== current);
        if (others.length)
            apply(others[Math.floor(Math.random() * others.length)], 0.5, 0.5);
    }

    /** The login screen's copy: at most 4K, plain JPEG, swapped in whole. */
    function publish(path) {
        if (path.length)
            Quickshell.execDetached(["sh", "-c",
                "d=/var/lib/aurora/login; [ -w \"$d\" ] || exit 0; " +
                "magick \"$1\" -auto-orient -resize '3840x2160>' -strip -quality 90 \"$d/wallpaper.jpg.tmp\" && " +
                "chmod 644 \"$d/wallpaper.jpg.tmp\" && mv -f \"$d/wallpaper.jpg.tmp\" \"$d/wallpaper.jpg\"",
                "_", path]);
    }

    Process {
        id: scan
        running: true
        command: ["sh", "-c", "find \"$1\" -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) -printf '%T@ %p\\n' 2>/dev/null | sort -rn | cut -d' ' -f2-", "_", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const files = this.text.split("\n").filter(l => l.length);
                // Same folder as before: keep the list (and the picker's tiles).
                if (files.join("\n") !== root.files.join("\n"))
                    root.files = files;
            }
        }
    }

    function pathFor(output) {
        if (Settings.wallpaper.length)
            return Settings.wallpaper;
        return byOutput[output] || "";
    }

    function refresh() {
        if (!query.running)
            query.running = true;
    }

    Process {
        id: query
        command: ["awww", "query"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                // Unchanged: don't wake every binding that reads the wallpaper.
                if (this.text === root.lastQuery)
                    return;
                root.lastQuery = this.text;
                const map = {};
                for (const line of this.text.split("\n")) {
                    const m = line.match(/^:?\s*([^:\s]+):.*image:\s*(.+)$/);
                    if (m)
                        map[m[1]] = m[2].trim();
                }
                root.byOutput = map;
                // The first answer after login: make sure the login screen has it.
                if (!root.published && Quickshell.screens.length) {
                    root.published = true;
                    root.publish(root.pathFor(Quickshell.screens[0].name));
                }
            }
        }
    }

    property string lastQuery: ""
    property bool published: false

    // A safety net only: apply() already knows, and anything else that changes
    // the wallpaper can say so (`qs ipc call aurora wallpaperChanged`).
    Timer {
        interval: 120000
        running: !Settings.wallpaper.length
        repeat: true
        onTriggered: root.refresh()
    }
}
