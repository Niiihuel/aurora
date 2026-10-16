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
 * demand; once aurora sets wallpapers itself this becomes push-based.
 */
Singleton {
    id: root

    /** output name → absolute image path, from the daemon. */
    property var byOutput: ({})

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
                const map = {};
                for (const line of this.text.split("\n")) {
                    const m = line.match(/^:?\s*([^:\s]+):.*image:\s*(.+)$/);
                    if (m)
                        map[m[1]] = m[2].trim();
                }
                root.byOutput = map;
            }
        }
    }

    Timer {
        interval: 10000
        running: !Settings.wallpaper.length
        repeat: true
        onTriggered: root.refresh()
    }
}
