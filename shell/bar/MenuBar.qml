import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../components"
import "../services"

/**
 * The macOS-style menu bar for one screen: 24 pt, full width, on subtle glass.
 *
 * Leading: the system menu (aurora's mark) and the frontmost app's name in
 * bold. Trailing: a stop button while recording the screen, sound, Bluetooth, network and battery extras, Control
 * Center, and the clock. Each slot is a BarItem; its menu arrives in section 3
 * through `clicked`.
 *
 * In full-screen the bar slides away and leaves a 2 pt strip at the top edge;
 * touching it brings the bar back over the full-screen window until the
 * pointer leaves, like macOS.
 */
PanelWindow {
    id: bar

    required property ShellScreen modelData
    screen: modelData

    readonly property real barHeight: Tokens.bar.height

    // --- Full-screen auto-hide -----------------------------------------------

    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool fullscreen: {
        const ws = monitor ? monitor.activeWorkspace : null;
        const o = ws ? ws.lastIpcObject : null;
        return o ? !!o.hasfullscreen : false;
    }
    readonly property bool shown: !fullscreen || reveal.hovered

    SpringValue {
        id: slide
        to: bar.shown ? 0 : 1
        preset: bar.shown ? Motion.smooth : Motion.dismiss
    }

    anchors { top: true; left: true; right: true }
    implicitHeight: barHeight
    exclusiveZone: fullscreen ? 0 : barHeight
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        width: bar.width
        height: bar.shown ? bar.barHeight : 2
    }

    HoverHandler {
        id: reveal
    }

    // --- Content ---------------------------------------------------------------

    Item {
        id: content
        width: bar.width
        height: bar.barHeight
        y: -slide.value * bar.barHeight
        opacity: 1 - slide.value
        // Fully away: nothing to draw (the clock would still redraw every second).
        visible: slide.value < 0.999

        GlassBackdrop {
            id: backdrop
            screen: bar.modelData
            region: Qt.rect(0, 0, bar.width, bar.barHeight)
            // Slid away over a full-screen window, it would keep capturing
            // that window (a video, a game) 30 times a second for nothing.
            captureWindows: bar.shown
        }

        Glass {
            anchors.fill: parent
            backdrop: backdrop
            material: Tokens.glass.bar
            radius: 0
            shadow: false
            edge: false
            track: [content.y]
        }

        // A click on empty bar space closes an open menu, as on macOS.
        MouseArea {
            anchors.fill: parent
            enabled: Menus.isOpen && Menus.screen === bar.modelData.name
            onClicked: Menus.close()
        }

        Row {
            id: leading
            anchors.left: parent.left
            anchors.leftMargin: Tokens.space.m
            height: parent.height

            BarItem {
                menu: "system"
                screenName: bar.modelData.name
                Icon { glyph: Glyphs.aurora; anchors.verticalCenter: parent.verticalCenter }
            }

            BarItem {
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.appName
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                    font.weight: Font.Bold
                }
            }
        }

        Row {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: Tokens.space.m
            height: parent.height

            // Recording the screen: stop, and how long it's been (as macOS does).
            BarItem {
                visible: Capture.state === "recording"
                onClicked: Capture.stop()
                Icon { glyph: Glyphs.stop; color: Tokens.label; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Math.floor(Capture.elapsed / 60)}:${String(Capture.elapsed % 60).padStart(2, "0")}`
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                    font.features: ({ "tnum": 1 })
                }
            }

            BarItem {
                visible: AudioStatus.ready
                menu: "sound"
                screenName: bar.modelData.name
                Icon { glyph: Glyphs.speaker(AudioStatus.waves); anchors.verticalCenter: parent.verticalCenter }
            }

            BarItem {
                visible: BluetoothStatus.present
                menu: "bluetooth"
                screenName: bar.modelData.name
                Icon { glyph: Glyphs.bluetooth(BluetoothStatus.kind); anchors.verticalCenter: parent.verticalCenter }
            }

            BarItem {
                menu: "network"
                screenName: bar.modelData.name
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: NetworkStatus.kind === "wired" ? Glyphs.ethernet
                         : NetworkStatus.kind === "wifi" ? Glyphs.wifi(NetworkStatus.bars)
                         : NetworkStatus.kind === "wifi-off" ? Glyphs.wifiOff
                         : Glyphs.wifi(0)
                }
            }

            BarItem {
                visible: BatteryStatus.present
                menu: "battery"
                screenName: bar.modelData.name
                Text {
                    visible: Settings.batteryPercent
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("common.percent", { n: Math.round(BatteryStatus.level * 100) })
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                    font.features: ({ "tnum": 1 })
                }
                BatteryIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    level: BatteryStatus.level
                    charging: BatteryStatus.charging
                    low: BatteryStatus.low
                }
            }

            BarItem {
                menu: "controlCenter"
                screenName: bar.modelData.name
                Icon { glyph: Glyphs.controlCenter; anchors.verticalCenter: parent.verticalCenter }
            }

            BarItem {
                menu: "notifications"
                screenName: bar.modelData.name
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bar.clockText
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }

    // ←/→ in an open menu walks this bar's menus in on-screen order, wrapping.
    Connections {
        target: Menus
        function onStepRequested(direction) {
            if (Menus.screen !== bar.modelData.name)
                return;
            const items = [];
            for (const row of [leading, trailing])
                for (const child of row.children)
                    if (child.visible && child.menu && child.menu.length)
                        items.push(child);
            const i = items.findIndex(item => item.menu === Menus.active);
            if (i < 0 || items.length < 2)
                return;
            const next = items[(i + direction + items.length) % items.length];
            Menus.open(next.menu, bar.modelData.name, next.anchor(), next.width);
        }
    }

    // Open a menu on request (IPC, shortcuts) when this is the focused screen.
    Connections {
        target: Menus
        function onRequestSerialChanged() {
            const focused = Hyprland.focusedMonitor;
            if (!focused || focused.name !== bar.modelData.name)
                return;
            const find = row => {
                for (const child of row.children)
                    if (child.menu === Menus.requested && child.visible)
                        return child;
                return null;
            };
            const item = find(leading) ?? find(trailing);
            if (item)
                Menus.toggle(item.menu, bar.modelData.name, item.anchor(), item.width);
        }
    }

    // --- Data ------------------------------------------------------------------

    /**
     * The frontmost app's name, from its desktop entry when there is one.
     * With nothing focused it reads "aurora", the way macOS shows Finder.
     */
    readonly property string appName: {
        const t = Hyprland.activeToplevel;
        const id = t && t.wayland ? t.wayland.appId : "";
        if (!id.length)
            return "aurora";
        const entry = DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
        return entry && entry.name ? entry.name : id;
    }

    SystemClock {
        id: clock
        precision: Settings.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property string clockText: I18n.locale.toString(clock.date, Settings.clockSeconds ? "ddd d MMM H:mm:ss" : "ddd d MMM H:mm")
}
