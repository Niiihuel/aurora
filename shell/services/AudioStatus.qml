pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

/**
 * Default output for the menu bar's sound extra and its menu: volume, mute,
 * the output devices people can pick, and the actions to change them.
 */
Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: !!sink && !!sink.audio
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready ? sink.audio.muted : false
    /** 0 = muted/silent, 1–3 = waves, like the macOS speaker glyph. */
    readonly property int waves: muted || volume <= 0.001 ? 0 : volume < 0.34 ? 1 : volume < 0.67 ? 2 : 3

    /** Real output devices (not per-app streams), sorted by name so the list is stable. */
    readonly property var outputs: Pipewire.nodes.values
        .filter(n => n.isSink && !n.isStream && n.audio)
        .sort((a, b) => nameOf(a).localeCompare(nameOf(b)))

    function nameOf(node) {
        return node ? (node.description || node.nickname || node.name || "") : "";
    }

    function setVolume(v) {
        if (!ready)
            return;
        sink.audio.volume = Math.max(0, Math.min(1, v));
        if (sink.audio.muted && v > 0)
            sink.audio.muted = false;
    }

    function setMuted(m) {
        if (ready)
            sink.audio.muted = m;
    }

    function setOutput(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    // A node's audio properties are only live while something tracks it.
    PwObjectTracker {
        objects: root.outputs.concat(root.sink ? [root.sink] : [])
    }
}
