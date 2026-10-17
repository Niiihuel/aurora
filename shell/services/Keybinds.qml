pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core/keys.mjs" as Chord

/**
 * Keyboard shortcuts for Settings' Keyboard page. Hyprland's config
 * (hypr/aurora/binds.lua in this repo) holds every action with an id
 * and its default keys; the user's changes go in ~/.config/hypr/keybinds.conf,
 * which this writes — data only, one per line, tab-separated:
 *
 *     set <TAB> <action id> <TAB> <keys>                 (empty keys = off)
 *     run <TAB> <keys> <TAB> <name> <TAB> <command>       (one of their own)
 *
 * What is really bound is read back from `hyprctl binds -j`: each bind
 * carries its id as the description. Saving reloads Hyprland.
 *
 * While a shortcut is being recorded Hyprland is switched to the empty
 * "aurora-record" submap, so the keys reach Settings instead of firing
 * (Super+Q would close the window); `endRecording` switches back.
 *
 * Only the Settings app uses this, so a single process writes the file.
 */
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/hypr/keybinds.conf"

    /** Every described bind in config order: [{ id, keys }]. */
    property var binds: []
    /** The user's changes to built-in actions: id → keys ("" = off). */
    property var changed: ({})
    /** The user's own shortcuts, in file order: [{ keys, name, command }]. */
    property var own: []
    property bool recording: false

    /**
     * Shown but not changeable here (as binds.lua marks them `fixed`): the
     * mouse, media keys, the switcher (it needs Alt to commit on release),
     * and the spaces, which Spaces' own settings bind.
     */
    function isFixed(id) {
        return /^(switcher|media|space)\./.test(id) || /^window\.(drag|resize)$/.test(id) || /^workspace\.scroll/.test(id);
    }

    function keysOf(id) {
        if (id.startsWith("run.")) {
            const o = own[Number(id.slice(4)) - 1];
            return o ? o.keys : "";
        }
        const b = binds.find(b => b.id === id);
        return b ? b.keys : "";
    }

    function isChanged(id) {
        return changed[id] !== undefined;
    }

    /** The id already bound to `keys` (other than `except`), or "". */
    function usedBy(keys, except) {
        if (!keys)
            return "";
        const hit = binds.find(b => b.id !== except && !b.id.startsWith("run.") && Chord.same(b.keys, keys));
        if (hit)
            return hit.id;
        const i = own.findIndex((o, n) => "run." + (n + 1) !== except && Chord.same(o.keys, keys));
        return i >= 0 ? "run." + (i + 1) : "";
    }

    /** Set several at once: { id: keys }, own shortcuts as "run.<n>". */
    function setMany(map) {
        const c = Object.assign({}, changed);
        const o = own.slice();
        for (const id in map) {
            if (id.startsWith("run.")) {
                const n = Number(id.slice(4)) - 1;
                if (o[n])
                    o[n] = Object.assign({}, o[n], { keys: map[id] });
            } else if (!isFixed(id)) {
                c[id] = map[id];
            }
        }
        changed = c;
        own = o;
        save();
    }

    function set(id, keys) {
        const map = {};
        map[id] = keys;
        setMany(map);
    }

    function reset(id) {
        const c = Object.assign({}, changed);
        delete c[id];
        changed = c;
        save();
    }

    /** Every built-in action back to its default; the user's own stay. */
    function resetAll() {
        changed = {};
        save();
    }

    function addOwn(keys, name, command) {
        const clean = s => String(s).replace(/[\t\r\n]+/g, " ").trim();
        if (!clean(command).length)
            return;
        own = own.concat([{ keys: clean(keys), name: clean(name), command: clean(command) }]);
        save();
    }

    function removeOwn(id) {
        const n = Number(id.slice(4)) - 1;
        own = own.filter((o, i) => i !== n);
        save();
    }

    function text() {
        let out = "# Keyboard shortcuts changed in aurora's Settings (Keyboard). Edit there.\n"
            + "# set<TAB>id<TAB>keys (empty = off) | run<TAB>keys<TAB>name<TAB>command\n";
        for (const id in changed)
            out += `set\t${id}\t${changed[id]}\n`;
        for (const o of own)
            out += `run\t${o.keys}\t${o.name}\t${o.command}\n`;
        return out;
    }

    function save() {
        file.setText(text());
        reload.restart();
    }

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    function beginRecording() {
        if (recording)
            return;
        recording = true;
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.submap("aurora-record")']);
        recordLimit.restart();
    }

    function endRecording() {
        if (!recording)
            return;
        recording = false;
        recordLimit.stop();
        Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.submap("reset")']);
    }

    // Never leave the keyboard without shortcuts for long.
    Timer {
        id: recordLimit
        interval: 15000
        onTriggered: root.endRecording()
    }

    // Writing several changes in a row reloads once; the binds are read back after.
    Timer {
        id: reload
        interval: 150
        onTriggered: {
            Quickshell.execDetached(["hyprctl", "reload"]);
            readSoon.restart();
        }
    }
    Timer {
        id: readSoon
        interval: 500
        onTriggered: root.refresh()
    }

    Process {
        id: reader
        running: true
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.binds = JSON.parse(this.text)
                        .filter(b => b.has_description && b.description && !b.submap)
                        .map(b => ({ id: b.description, keys: Chord.fromBind(b.modmask, b.key, b.keycode) }));
                } catch (e) {}
            }
        }
    }

    FileView {
        id: file
        path: root.path
        printErrors: false // no file until the first change
        onLoaded: {
            const changed = {};
            const own = [];
            for (const line of text().split("\n")) {
                const f = line.split("\t");
                if (f[0] === "set" && f.length === 3 && f[1].length)
                    changed[f[1]] = f[2];
                else if (f[0] === "run" && f.length >= 4)
                    own.push({ keys: f[1], name: f[2], command: f.slice(3).join(" ") });
            }
            root.changed = changed;
            root.own = own;
        }
    }

    Component.onDestruction: endRecording()
}
