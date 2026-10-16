import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../services"

/**
 * The blurred scene that Glass refracts, for one layer-shell window.
 *
 * A Wayland client can't read what lies beneath its own surface, so the scene
 * is rebuilt here in monitor coordinates: the output's wallpaper (cropped the
 * way the daemon fills the screen) plus a live screencopy of each window on
 * the monitor's active workspace that `region` overlaps, stacked like
 * Hyprland stacks them. It is rendered at a quarter of the monitor's size and
 * blurred with two Gaussian passes.
 *
 * Place one inside every window that shows glass and set `screen` and
 * `origin` (the window's top-left on its monitor). The item positions itself
 * at -origin so its coordinates are the monitor's; Glass maps itself onto it.
 * Textures can't cross windows, which is why each window needs its own.
 *
 * Captures exist only while `region` actually overlaps a window: a margin
 * around the glass once kept a window streaming behind a resting bar and the
 * whole overlay redrawing at 120 fps.
 *
 * They are refreshed at `captureFps`, not `live`: a live capture is answered
 * on Hyprland's next repaint, which our own redraw triggers, so live views
 * looped at the display's full rate (120 fps, ~15% CPU) behind a menu at
 * rest. Under the blur a slower refresh doesn't show.
 */
Item {
    id: root

    required property ShellScreen screen
    /** Window's top-left in monitor coordinates. */
    property point origin: Qt.point(0, 0)
    /** Glass footprint in monitor coordinates; windows under it get captured. */
    property rect region: Qt.rect(0, 0, 0, 0)
    /** Backdrop blur, standard deviation in points. */
    property real blur: Tokens.glass.regular.blur
    property bool captureWindows: true
    /** How often windows under the glass are re-captured. */
    property int captureFps: 30

    readonly property alias texture: blurredV
    readonly property bool ready: wallpaper.status === Image.Ready
    readonly property real dpr: monitor ? monitor.scale : 1
    readonly property int captures: windows.length

    x: -origin.x
    y: -origin.y
    width: screen ? screen.width : 0
    height: screen ? screen.height : 0
    enabled: false

    readonly property size quarter: Qt.size(Math.max(2, Math.round(width / 4)), Math.max(2, Math.round(height / 4)))
    readonly property real sigmaTexels: blur / 4

    readonly property var monitor: {
        const all = Hyprland.monitors.values;
        for (let i = 0; i < all.length; i++)
            if (screen && all[i].name === screen.name)
                return all[i];
        return null;
    }

    /**
     * Windows to capture, bottom to top: tiled before floating, older focus
     * before newer. Geometry comes from lastIpcObject, refreshed on events.
     */
    readonly property var windows: {
        const mon = monitor;
        const r = region;
        if (!captureWindows || !mon || r.width <= 0 || r.height <= 0)
            return [];
        const workspace = mon.activeWorkspace ? mon.activeWorkspace.id : -1;
        const list = [];
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.at || !o.size || !t.wayland || o.hidden || o.mapped === false)
                continue;
            if (o.monitor !== mon.id || !o.workspace || o.workspace.id !== workspace)
                continue;
            const x = o.at[0] - mon.x, y = o.at[1] - mon.y, w = o.size[0], h = o.size[1];
            const overlaps = x < r.x + r.width && x + w > r.x && y < r.y + r.height && y + h > r.y;
            if (overlaps)
                list.push({ source: t.wayland, x, y, w, h, floating: !!o.floating, focus: o.focusHistoryID ?? 0 });
        }
        list.sort((a, b) => (a.floating - b.floating) || (b.focus - a.focus));
        return list;
    }

    Component.onCompleted: Hyprland.refreshToplevels()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            switch (event.name) {
            case "openwindow": case "closewindow": case "movewindow": case "movewindowv2":
            case "changefloatingmode": case "workspace": case "workspacev2":
            case "fullscreen": case "activewindowv2": case "resizewindow":
                refreshSoon.restart();
            }
        }
    }

    // One refresh per burst of events (a workspace switch fires several).
    Timer {
        id: refreshSoon
        interval: 60
        onTriggered: Hyprland.refreshToplevels()
    }

    Item {
        id: scene
        anchors.fill: parent

        Image {
            id: wallpaper
            anchors.fill: parent
            source: {
                const path = root.screen ? Wallpaper.pathFor(root.screen.name) : "";
                return path.length ? "file://" + path : "";
            }
            // The blur works at quarter size; decoding more is wasted memory.
            sourceSize: Qt.size(Math.max(2, Math.round(root.width / 2)), Math.max(2, Math.round(root.height / 2)))
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
        }

        Repeater {
            id: captureViews
            model: root.windows
            delegate: ScreencopyView {
                required property var modelData
                x: modelData.x
                y: modelData.y
                width: modelData.w
                height: modelData.h
                captureSource: modelData.source
                live: false
                constraintSize: Qt.size(Math.max(1, Math.round(modelData.w / 2)), Math.max(1, Math.round(modelData.h / 2)))
            }
        }
    }

    Timer {
        interval: 1000 / root.captureFps
        repeat: true
        running: captureViews.count > 0 && root.Window.visibility !== Window.Hidden
        onTriggered: {
            for (let i = 0; i < captureViews.count; i++)
                captureViews.itemAt(i).captureFrame();
        }
    }

    ShaderEffectSource {
        id: downsampled
        anchors.fill: parent
        sourceItem: scene
        textureSize: root.quarter
        smooth: true
        hideSource: true
        visible: false
    }

    ShaderEffect {
        id: passH
        anchors.fill: parent
        visible: false
        property var source: downsampled
        property vector2d texelStep: Qt.vector2d(1 / root.quarter.width, 0)
        property real sigma: root.sigmaTexels
        fragmentShader: Qt.resolvedUrl("../shaders/blur.frag.qsb")
    }

    ShaderEffectSource {
        id: blurredH
        anchors.fill: parent
        sourceItem: passH
        textureSize: root.quarter
        smooth: true
        hideSource: true
        visible: false
    }

    ShaderEffect {
        id: passV
        anchors.fill: parent
        visible: false
        property var source: blurredH
        property vector2d texelStep: Qt.vector2d(0, 1 / root.quarter.height)
        property real sigma: root.sigmaTexels
        fragmentShader: Qt.resolvedUrl("../shaders/blur.frag.qsb")
    }

    ShaderEffectSource {
        id: blurredV
        anchors.fill: parent
        sourceItem: passV
        textureSize: root.quarter
        smooth: true
        hideSource: true
        visible: false
    }
}
