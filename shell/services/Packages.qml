pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Installed apps as NixOS sees them, for Settings' Apps page: where each app
 * comes from (which decides how it can be removed), updating everything, and
 * applying changes.
 *
 * NixOS is declarative, so "uninstall" depends on the source:
 * - managed: listed in ~/dotfiles/modules/nixos/packages-managed.json (the
 *   list the desktop owns; a flat array of nixpkgs names, never Nix code) —
 *   removed from the list, then the system is rebuilt;
 * - profile: installed with `nix profile` — `nix profile remove`;
 * - local: a desktop file (and AppImage) in the home folder — deleted;
 * - system: part of the hand-written configuration (packages.nix and the
 *   modules) — can only be removed there.
 *
 * Root work goes through the dotfiles' oneshot units with a polkit rule
 * (modules/nixos/ricelin-system.nix): `systemctl start ricelin-rebuild`
 * blocks until the switch ends and returns its status; the desktop's polkit
 * agent asks for the password. Progress is read from its journal.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string repo: home + "/dotfiles"
    readonly property string managedPath: repo + "/modules/nixos/packages-managed.json"
    readonly property string appliedPath: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/aurora/packages-applied.json"

    /** Desktop id → { kind: "managed" | "profile" | "local" | "system", name, file, appimage }. */
    property var sources: ({})
    property var managed: []
    property var applied: []
    readonly property bool pending: JSON.stringify(managed.slice().sort()) !== JSON.stringify(applied.slice().sort())

    /** "" idle, "updating" (flake inputs), "building" (switch), "done", "failed". */
    property string state: ""
    property string line: ""
    readonly property bool busy: state === "updating" || state === "building"

    function scan() {
        if (!scanner.running)
            scanner.running = true;
        managedFile.reload();
        appliedFile.reload();
    }

    function sourceOf(entry) {
        return sources[entry.id] ?? { kind: "system", name: "" };
    }

    function uninstall(entry) {
        const s = sourceOf(entry);
        if (s.kind === "managed") {
            managed = managed.filter(n => n !== s.name);
            managedFile.setText(JSON.stringify(managed, null, 2) + "\n");
        } else if (s.kind === "profile") {
            Quickshell.execDetached(["sh", "-c", "nix profile remove \"$1\"; true", "_", s.name]);
            rescanSoon.restart();
        } else if (s.kind === "local") {
            Quickshell.execDetached(["sh", "-c", "rm -f -- \"$1\" ${2:+\"$2\"}", "_", s.file, s.appimage || ""]);
            rescanSoon.restart();
        }
    }

    /** Rebuild the system from the dotfiles (asks for the password). */
    function apply() {
        if (busy)
            return;
        run("building", "systemctl start ricelin-rebuild.service");
    }

    /** Pull the newest nixpkgs and everything else the flake follows, then rebuild. */
    function updateAll() {
        if (busy)
            return;
        run("updating", "nix flake update --flake \"$HOME/dotfiles\" 2>&1 | tail -n 20 && echo '@@building' && systemctl start ricelin-rebuild.service");
    }

    function run(first, script) {
        state = first;
        line = "";
        job.command = ["sh", "-c", script];
        job.running = true;
        journal.running = true;
    }

    Timer {
        id: rescanSoon
        interval: 1500
        onTriggered: root.scan()
    }

    Process {
        id: job
        stdout: SplitParser {
            onRead: data => {
                if (data === "@@building")
                    root.state = "building";
                else if (data.trim().length)
                    root.line = data.trim();
            }
        }
        onExited: code => {
            journal.running = false;
            root.state = code === 0 ? "done" : "failed";
            if (code === 0) {
                root.applied = root.managed.slice();
                appliedFile.setText(JSON.stringify(root.applied) + "\n");
                root.scan();
            }
        }
    }

    // The rebuild's live log (the unit runs as root; its journal is readable by wheel).
    Process {
        id: journal
        command: ["journalctl", "-fu", "ricelin-rebuild.service", "-n", "0", "-o", "cat"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim().length)
                    root.line = data.trim();
            }
        }
    }

    FileView {
        id: managedFile
        path: root.managedPath
        atomicWrites: false
        onLoaded: {
            try { root.managed = JSON.parse(text()); } catch (e) { root.managed = []; }
        }
    }
    FileView {
        id: appliedFile
        path: root.appliedPath
        onLoaded: {
            try { root.applied = JSON.parse(text()); } catch (e) { root.applied = root.managed.slice(); }
        }
        onLoadFailed: root.applied = root.managed.slice()
    }

    // Where each desktop file comes from: its folder and the store path it resolves to.
    Process {
        id: scanner
        running: true
        command: ["sh", "-c",
            "IFS=:; for d in ${XDG_DATA_HOME:-$HOME/.local/share}:$XDG_DATA_DIRS; do " +
            "for f in \"$d\"/applications/*.desktop; do [ -e \"$f\" ] || continue; " +
            "id=${f##*/}; id=${id%.desktop}; real=$(readlink -f \"$f\"); " +
            "exe=$(grep -m1 '^Exec=' \"$f\" | sed 's/^Exec=//; s/ .*//'); " +
            "printf '%s\\t%s\\t%s\\t%s\\n' \"$id\" \"$d\" \"$real\" \"$exe\"; done; done; " +
            "echo '@@profile'; nix profile list --json 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [desktop, profileJson] = this.text.split("@@profile\n");
                let profile = [];
                try {
                    profile = Object.keys(JSON.parse(profileJson || "{}").elements ?? {});
                } catch (e) {}
                const map = {};
                for (const row of desktop.split("\n")) {
                    const [id, dir, real, exe] = row.split("\t");
                    if (!id || map[id])
                        continue;
                    // nixpkgs name from the store path: /nix/store/<hash>-<name>-<version>/…
                    const m = (real || "").match(/^\/nix\/store\/[a-z0-9]{32}-(.+?)(-\d[^/]*)?\//);
                    const name = m ? m[1] : "";
                    let kind = "system";
                    if (dir.startsWith(root.home + "/.local"))
                        kind = "local";
                    else if (dir.includes("/.nix-profile") || dir.includes("/.local/state/nix/profile"))
                        kind = profile.includes(name) ? "profile" : "system";
                    else if (root.managed.some(a => a.split(".").pop() === name))
                        kind = "managed";
                    map[id] = {
                        kind,
                        name: kind === "managed" ? root.managed.find(a => a.split(".").pop() === name) : name,
                        file: kind === "local" ? dir + "/applications/" + id + ".desktop" : "",
                        appimage: kind === "local" && /\.AppImage$/i.test(exe || "") ? exe : ""
                    };
                }
                root.sources = map;
            }
        }
    }
}
