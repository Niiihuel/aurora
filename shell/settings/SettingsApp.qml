import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import "../core"
import "../components"
import "../services"
import "../core/search.mjs" as Search
import "panes"

/**
 * aurora's Settings, after macOS System Settings (Tahoe): a sidebar of liquid
 * glass floating inside the window — the window controls, a search field and
 * the sections, each with its coloured icon — and the chosen section's
 * groups of rows on the right under its title.
 *
 * The sidebar is live liquid glass over whatever is really behind the
 * window (the windows and wallpaper under it, refreshed like every other
 * glass): the window is transparent exactly under the sidebar and opaque
 * everywhere else, and its backdrop leaves this app's own window out. It is
 * placed from the window's position as Hyprland reports it.
 */
Item {
    id: root

    required property var window
    property string page: "wifi"
    property string query: ""

    // i18n-keys: settings.page.wifi settings.page.bluetooth settings.page.battery settings.page.general settings.page.accessibility settings.page.appearance settings.page.controlCenter settings.page.wallpaper settings.page.displays settings.page.notifications settings.page.sound settings.page.lockScreen settings.page.keyboard settings.page.language settings.page.apps
    readonly property var sections: [
        [
            { id: "wifi", glyph: Glyphs.wifi(3), tint: Tokens.accent, pane: wifiPane },
            { id: "bluetooth", glyph: Glyphs.bluetooth("on"), tint: Tokens.accent, pane: bluetoothPane }
        ],
        [
            { id: "battery", glyph: Glyphs.bolt, tint: Tokens.success, pane: batteryPane, hidden: !BatteryStatus.present },
            { id: "general", glyph: Glyphs.gear, tint: Tokens.neutral, pane: generalPane },
            { id: "accessibility", glyph: Glyphs.person, tint: Tokens.accent, pane: accessibilityPane },
            { id: "appearance", glyph: Glyphs.darkMode, tint: Tokens.neutral, pane: appearancePane },
            { id: "controlCenter", glyph: Glyphs.controlCenter, tint: Tokens.neutral, pane: controlCenterPane },
            { id: "wallpaper", glyph: Glyphs.photo, tint: Tokens.accent, pane: wallpaperPane },
            { id: "displays", glyph: Glyphs.sun, tint: Tokens.accent, pane: displaysPane }
        ],
        [
            { id: "notifications", glyph: Glyphs.bell, tint: Tokens.destructive, pane: notificationsPane },
            { id: "sound", glyph: Glyphs.speaker(3), tint: Tokens.destructive, pane: soundPane }
        ],
        [
            { id: "lockScreen", glyph: Glyphs.lock, tint: Tokens.neutral, pane: lockPane },
            { id: "keyboard", glyph: Glyphs.keyboard, tint: Tokens.neutral, pane: keyboardPane },
            { id: "language", glyph: Glyphs.globe, tint: Tokens.accent, pane: languagePane }
        ],
        [
            { id: "apps", glyph: Glyphs.apps, tint: Tokens.accent, pane: appsPane }
        ]
    ]
    readonly property var all: [].concat(...sections).filter(s => !s.hidden)
    readonly property var current: all.find(s => s.id === page) ?? all[0]

    function titleOf(s) {
        return I18n.tr("settings.page." + s.id);
    }

    // --- Where the window is, for the sidebar's glass -----------------------------

    readonly property var toplevel: {
        for (const t of Hyprland.toplevels.values)
            if (t.lastIpcObject && t.lastIpcObject.pid === Quickshell.processId)
                return t;
        return null;
    }
    readonly property var monitor: {
        const o = toplevel?.lastIpcObject;
        return Hyprland.monitors.values.find(m => o && m.id === o.monitor) ?? Hyprland.focusedMonitor;
    }
    readonly property point origin: {
        const o = toplevel?.lastIpcObject;
        return o && o.at ? Qt.point(o.at[0] - (monitor?.x ?? 0), o.at[1] - (monitor?.y ?? 0)) : Qt.point(0, 0);
    }

    GlassBackdrop {
        id: settingsBackdrop
        screen: Quickshell.screens.find(s => s.name === root.monitor?.name) ?? Quickshell.screens[0]
        origin: root.origin
        excludePid: Quickshell.processId
        region: Qt.rect(root.origin.x + sidebar.x, root.origin.y + sidebar.y, sidebar.width, sidebar.height)
    }

    // The window's background, with a hole where the sidebar's glass sits.
    Rectangle {
        anchors.fill: parent
        color: Tokens.windowFill
        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: sidebarShape
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.5
        }
    }
    Item {
        id: sidebarShape
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            x: sidebar.x
            y: sidebar.y
            width: sidebar.width
            height: sidebar.height
            radius: 18
        }
    }

    // --- Sidebar ---------------------------------------------------------------------

    Item {
        id: sidebar
        x: 8
        y: 8
        width: 236
        height: parent.height - 16

        Glass {
            anchors.fill: parent
            backdrop: settingsBackdrop
            material: Tokens.glass.regular
            radius: 18
            shadow: false
            track: [root.origin.x, root.origin.y]
        }

        SearchField {
            id: search
            x: 12
            y: 14
            width: parent.width - 24
            onTextChanged: root.query = text
        }

        Flickable {
            id: sidebarList
            x: 8
            y: search.y + search.height + 10
            width: parent.width - 16
            height: parent.height - y - 8
            contentHeight: items.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: items
                width: parent.width
                spacing: 10

                Repeater {
                    model: root.sections
                    delegate: Column {
                        id: section
                        required property var modelData
                        width: items.width
                        readonly property var shown: modelData.filter(s => !s.hidden && (!root.query.trim().length || Search.score(root.titleOf(s), root.query) > 0))
                        visible: shown.length > 0

                        Repeater {
                            model: section.shown
                            delegate: Item {
                                id: entry
                                required property var modelData
                                readonly property bool on: !!root.current && modelData.id === root.current.id
                                width: section.width
                                height: 30

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: entry.on ? Tokens.accent : "transparent"
                                }
                                Rectangle {
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    height: 20
                                    radius: 5
                                    color: entry.modelData.tint
                                    Icon {
                                        anchors.centerIn: parent
                                        glyph: entry.modelData.glyph
                                        size: 12
                                        color: "white"
                                        dimColor: Qt.rgba(1, 1, 1, 0.45)
                                    }
                                }
                                Text {
                                    x: 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - x - 8
                                    text: root.titleOf(entry.modelData)
                                    color: entry.on ? "white" : Tokens.label
                                    font.family: Tokens.family
                                    font.pixelSize: Tokens.type.body.size
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.page = entry.modelData.id
                                }
                            }
                        }
                    }
                }
            }
        }
        ScrollIndicator { flickable: sidebarList; outside: false }
    }

    // --- Content ---------------------------------------------------------------------
    // The title is a bar floating over the content, which scrolls under it with
    // Tahoe's soft scroll edge effect (the content blurs and fades into the
    // window's background as it passes beneath the title).

    Item {
        id: content
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        readonly property real barHeight: 64

        Flickable {
            id: scroller
            anchors.fill: parent
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            topMargin: content.barHeight
            contentHeight: pane.height + 28
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: pane
                width: scroller.width
                sourceComponent: root.current ? root.current.pane : null
                onLoaded: {
                    item.width = Qt.binding(() => scroller.width);
                    if (item.backdrop !== undefined)
                        item.backdrop = settingsBackdrop;
                    scroller.contentY = -scroller.topMargin;
                }
            }
        }
        ScrollIndicator { flickable: scroller }

        // The scroll edge: what passes under the bar, blurred, fading out downward.
        readonly property real scrolled: Math.max(0, scroller.contentY + scroller.topMargin)
        ShaderEffectSource {
            id: underBar
            x: scroller.x
            width: scroller.width
            height: content.barHeight + 20
            sourceItem: scroller
            sourceRect: Qt.rect(0, 0, scroller.width, content.barHeight + 20)
            visible: false
            live: true
        }
        Item {
            id: edge
            x: scroller.x
            width: scroller.width
            height: content.barHeight + 20
            opacity: Math.min(1, content.scrolled / 24)
            visible: opacity > 0

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Tokens.windowFill }
                    GradientStop { position: 0.62; color: Qt.alpha(Tokens.windowFill, 0.85) }
                    GradientStop { position: 1; color: Qt.alpha(Tokens.windowFill, 0) }
                }
            }
            MultiEffect {
                anchors.fill: parent
                source: underBar
                blurEnabled: true
                blurMax: 32
                blur: 1
                opacity: 0.6
                maskEnabled: true
                maskSource: edgeMask
                maskThresholdMin: 0.0
            }
            Rectangle {
                id: edgeMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                gradient: Gradient {
                    GradientStop { position: 0; color: "white" }
                    GradientStop { position: 0.7; color: "white" }
                    GradientStop { position: 1; color: "transparent" }
                }
            }
        }

        Text {
            id: title
            x: 28
            y: 20
            text: root.current ? root.titleOf(root.current) : ""
            color: Tokens.label
            font.family: Tokens.family
            font.pixelSize: Tokens.type.title2.size
            font.weight: Font.Bold
        }
    }

    Component { id: wifiPane; WifiPane {} }
    Component { id: bluetoothPane; BluetoothPane {} }
    Component { id: batteryPane; BatteryPane {} }
    Component { id: generalPane; GeneralPane {} }
    Component { id: accessibilityPane; AccessibilityPane {} }
    Component { id: appearancePane; AppearancePane {} }
    Component { id: controlCenterPane; ControlCenterPane {} }
    Component { id: wallpaperPane; WallpaperPane {} }
    Component { id: displaysPane; DisplaysPane {} }
    Component { id: notificationsPane; NotificationsPane {} }
    Component { id: soundPane; SoundPane {} }
    Component { id: lockPane; LockScreenPane {} }
    Component { id: keyboardPane; KeyboardPane {} }
    Component { id: languagePane; LanguagePane {} }
    Component { id: appsPane; AppsPane {} }
}
