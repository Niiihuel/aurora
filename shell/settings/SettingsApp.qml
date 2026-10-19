import QtQuick
import QtQuick.Effects
import "../core"
import "../components"
import "../services"
import "../core/search.mjs" as Search
import "panes"

/**
 * aurora's Settings, after macOS System Settings: a sidebar floating inside
 * the window — a search field and the sections, each with a plain
 * icon — and the chosen section's groups of rows on the right under its
 * title.
 *
 * No liquid glass here, as in System Settings: the sidebar is a veil over
 * Hyprland's blur of what's behind the window (the window is transparent
 * exactly under the sidebar and opaque everywhere else), and the controls
 * in the panes are solid (they get no backdrop).
 */
Item {
    id: root

    required property var window
    property string page: "wifi"
    property string query: ""

    // i18n-keys: settings.page.wifi settings.page.bluetooth settings.page.battery settings.page.general settings.page.accessibility settings.page.appearance settings.page.controlCenter settings.page.wallpaper settings.page.displays settings.page.notifications settings.page.sound settings.page.lockScreen settings.page.keyboard settings.page.language settings.page.apps
    readonly property var sections: [
        [
            { id: "wifi", glyph: Glyphs.wifi(3), pane: wifiPane },
            { id: "bluetooth", glyph: Glyphs.bluetooth("on"), pane: bluetoothPane }
        ],
        [
            { id: "battery", glyph: Glyphs.bolt, pane: batteryPane, hidden: !BatteryStatus.present },
            { id: "general", glyph: Glyphs.gear, pane: generalPane },
            { id: "accessibility", glyph: Glyphs.person, pane: accessibilityPane },
            { id: "appearance", glyph: Glyphs.darkMode, pane: appearancePane },
            { id: "controlCenter", glyph: Glyphs.controlCenter, pane: controlCenterPane },
            { id: "wallpaper", glyph: Glyphs.photo, pane: wallpaperPane },
            { id: "displays", glyph: Glyphs.sun, pane: displaysPane }
        ],
        [
            { id: "notifications", glyph: Glyphs.bell, pane: notificationsPane },
            { id: "sound", glyph: Glyphs.speaker(3), pane: soundPane }
        ],
        [
            { id: "lockScreen", glyph: Glyphs.lock, pane: lockPane },
            { id: "keyboard", glyph: Glyphs.keyboard, pane: keyboardPane },
            { id: "language", glyph: Glyphs.globe, pane: languagePane }
        ],
        [
            { id: "apps", glyph: Glyphs.apps, pane: appsPane }
        ]
    ]
    readonly property var all: [].concat(...sections).filter(s => !s.hidden)
    readonly property var current: all.find(s => s.id === page) ?? all[0]

    function titleOf(s) {
        return I18n.tr("settings.page." + s.id);
    }

    // The window's background, with a hole where the sidebar sits.
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

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: Settings.reduceTransparency ? Tokens.solidFill : Tokens.sidebarFill
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
                                Item {
                                    x: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 20
                                    height: 20
                                    Icon {
                                        id: entryIcon
                                        anchors.centerIn: parent
                                        glyph: entry.modelData.glyph
                                        size: 16
                                        color: entry.on ? "white" : Tokens.secondaryLabel
                                        dimColor: Qt.alpha(entryIcon.color, 0.35)
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
