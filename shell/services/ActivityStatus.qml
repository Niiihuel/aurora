pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../core"
import "../core/activity.mjs" as Parse

/**
 * What the computer is doing, for the activity extra and its menu, read from
 * /proc and /sys.
 *
 * What the bar shows — the CPU load (and its last minute, for the menu), how
 * busy the GPU is and memory — is sampled every 2 s from files, no process
 * per tick. Temperatures, network, disk and the processes are read only
 * while the menu shows them (`watchers`).
 * The discrete GPU is never woken to ask how busy it is: only its runtime
 * power state is read.
 */
Singleton {
    id: root

    readonly property int interval: 2000
    readonly property int historyLength: 30

    /** 0–1 over the last sample. */
    property real cpu: 0
    /** The last minute of `cpu`, oldest first. */
    property var history: []

    /** How many views show the details (the activity menu). */
    property int watchers: 0
    readonly property bool watching: watchers > 0

    /** Bytes. */
    property real memUsed: 0
    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real diskUsed: 0
    property real diskTotal: 0
    /** °C; NaN when the machine doesn't report it. */
    property real cpuTemp: NaN
    property real gpuTemp: NaN
    /** 0–1; -1 when the GPU doesn't report it. */
    property real gpuBusy: -1
    /** The discrete GPU's power state: "active", "suspended", or "" without one. */
    property string dgpu: ""
    /** Bytes per second down and up; -1 until there are two samples. */
    property real rxRate: -1
    property real txRate: -1
    /** One row per process name (see activity.mjs groups()); empty until two samples. */
    property var processes: []
    readonly property var topCpu: Parse.top(processes, "cpu", 3)
    readonly property var topMemory: Parse.top(processes, "rss", 3)

    /**
     * A row as people know it, { name, icon }: the app of a window one of its
     * processes owns, else an installed app of that name, else the process
     * name with the icon theme's icon for it, or its Terminal icon for a
     * command run in a terminal, or its generic program icon.
     */
    function app(row) {
        if (!row)
            return { name: "", icon: "" };
        if (appCache[row.name])
            return appCache[row.name];
        const windows = {};
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (o && o.pid)
                windows[o.pid] = (t.wayland && t.wayland.appId) || o.class || "";
        }
        const pid = row.pids.find(p => windows[p]);
        const id = pid ? windows[pid] : "";
        const entry = (id.length ? (DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id)) : null) ?? DesktopEntries.heuristicLookup(row.name);
        const found = {
            name: entry ? entry.name : row.name,
            icon: entry ? Apps.iconFor(entry)
                : Quickshell.iconPath(row.name, true) || Quickshell.iconPath(row.tty ? "utilities-terminal" : "application-x-executable", true)
        };
        appCache[row.name] = found;
        return found;
    }
    // Per name, for one opening of the menu (windows come and go between them).
    property var appCache: ({})

    function find(name) {
        return processes.find(row => row.name === name) ?? null;
    }

    /** Ask a row's processes to quit, or kill them (`force`). */
    function quit(row, force) {
        Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM"].concat(row.pids.map(String)));
    }

    /** "1,2 GB"-style size in the interface's locale. */
    function bytes(n) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (n >= 1000 && i < units.length - 1) {
            n /= 1000;
            i++;
        }
        return I18n.locale.toString(n, "f", i > 1 && n < 10 ? 1 : 0) + " " + units[i];
    }

    /** A number read from a sysfs file; NaN without one. */
    function readNumber(file) {
        if (!file.path.length)
            return NaN;
        file.reload();
        return parseFloat(file.text());
    }

    // --- What the bar shows, always ------------------------------------------------

    property var lastCpu: null

    Timer {
        running: Settings.activityExtra
        interval: root.interval
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            const now = Parse.cpuTimes(stat.text());
            if (root.lastCpu) {
                root.cpu = Parse.cpuLoad(root.lastCpu, now);
                root.history = root.history.concat([root.cpu]).slice(-root.historyLength);
            }
            root.lastCpu = now;

            meminfo.reload();
            const m = Parse.memory(meminfo.text());
            root.memUsed = m.used;
            root.memTotal = m.total;
            root.swapUsed = m.swapUsed;
            root.swapTotal = m.swapTotal;

            const busy = root.readNumber(gpuBusyFile);
            root.gpuBusy = isNaN(busy) ? -1 : busy / 100;
        }
    }

    FileView { id: stat; path: "/proc/stat"; blockLoading: true }
    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: gpuBusyFile; blockLoading: true }

    // --- The rest, while the menu is open -------------------------------------------

    // The first two reads come 0.5 s apart, so rates and processes show at once.
    property int detailTicks: 0
    property var lastNet: null
    property var lastProcs: null
    onWatchingChanged: {
        detailTicks = 0;
        appCache = {};
        lastNet = null;
        lastProcs = null;
        if (watching && !disk.running)
            disk.running = true;
    }

    Timer {
        running: root.watching
        interval: root.detailTicks < 2 ? 500 : root.interval
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.detailTicks++;
            const now = Date.now();

            root.cpuTemp = root.readNumber(cpuTempFile) / 1000;
            root.gpuTemp = root.readNumber(gpuTempFile) / 1000;
            if (dgpuFile.path.length) {
                dgpuFile.reload();
                root.dgpu = dgpuFile.text().trim() === "suspended" ? "suspended" : "active";
            }

            netdev.reload();
            const net = Parse.netBytes(netdev.text());
            if (root.lastNet) {
                const s = (now - root.lastNet.time) / 1000;
                root.rxRate = Math.max(0, (net.rx - root.lastNet.rx) / s);
                root.txRate = Math.max(0, (net.tx - root.lastNet.tx) / s);
            }
            root.lastNet = { rx: net.rx, tx: net.tx, time: now };

            if (!procs.running)
                procs.running = true;
        }
    }

    FileView { id: netdev; path: "/proc/net/dev"; blockLoading: true }
    FileView { id: cpuTempFile; blockLoading: true }
    FileView { id: gpuTempFile; blockLoading: true }
    FileView { id: dgpuFile; blockLoading: true }

    Process {
        id: procs
        command: ["sh", "-c", "cd /proc && cat [0-9]*/stat 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now();
                const sample = Parse.processes(this.text);
                if (root.lastProcs)
                    root.processes = Parse.groups(root.lastProcs.sample, sample, (now - root.lastProcs.time) / 1000);
                root.lastProcs = { sample, time: now };
            }
        }
    }

    Process {
        id: disk
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split("\n").pop().trim().split(/\s+/).map(Number);
                root.diskUsed = f[0] || 0;
                root.diskTotal = f[1] || 0;
            }
        }
    }

    // hwmon and DRM numbering changes between boots: find the sensors by name once.
    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do echo \"hwmon $(cat $h/name) $h\"; done; for c in /sys/class/drm/card*; do case $c in *-*) continue;; esac; echo \"drm $(cat $c/device/vendor) $c/device\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of this.text.trim().split("\n")) {
                    const [kind, name, path] = line.split(" ");
                    if (kind === "hwmon" && ["k10temp", "coretemp", "zenpower"].includes(name) && !cpuTempFile.path.length)
                        cpuTempFile.path = path + "/temp1_input";
                    else if (kind === "hwmon" && name === "amdgpu" && !gpuTempFile.path.length)
                        gpuTempFile.path = path + "/temp1_input";
                    // AMD reports how busy it is; NVIDIA only through its driver tools, which would wake it.
                    else if (kind === "drm" && name === "0x1002" && !gpuBusyFile.path.length)
                        gpuBusyFile.path = path + "/gpu_busy_percent";
                    else if (kind === "drm" && name === "0x10de")
                        dgpuFile.path = path + "/power/runtime_status";
                }
            }
        }
    }
}
