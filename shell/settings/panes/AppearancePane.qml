import QtQuick
import "../../core"
import "../../components"
import "../../components/menu"
import "../../services"
import ".."

/**
 * Appearance: light or dark, the accent colour (the wallpaper's, as by
 * default, or one of Apple's), and how much the menu bar is tinted.
 */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.xl

    // i18n-keys: settings.accent.wallpaper settings.accent.blue settings.accent.purple settings.accent.pink settings.accent.red settings.accent.orange settings.accent.yellow settings.accent.green settings.accent.graphite
    readonly property var accents: [
        { name: "wallpaper", color: "" },
        { name: "blue", color: "#0A84FF" },
        { name: "purple", color: "#BF5AF2" },
        { name: "pink", color: "#FF375F" },
        { name: "red", color: "#FF453A" },
        { name: "orange", color: "#FF9F0A" },
        { name: "yellow", color: "#FFD60A" },
        { name: "green", color: "#30D158" },
        { name: "graphite", color: "#8E8E93" }
    ]

    SettingsGroup {
        SettingsRow {
            title: I18n.tr("settings.appearance.mode")
            SegmentedControl {
                width: 220
                backdrop: root.backdrop
                options: [I18n.tr("settings.appearance.light"), I18n.tr("settings.appearance.dark")]
                selected: Settings.dark ? 1 : 0
                onActivated: i => Settings.appearance = i === 1 ? "dark" : "light"
            }
        }
        SettingsRow {
            height: 64
            title: I18n.tr("settings.appearance.accent")
            subtitle: I18n.tr("settings.accent." + (root.accents.find(a => a.color.toLowerCase() === Settings.accent.toLowerCase()) ?? root.accents[0]).name)
            Row {
                spacing: Tokens.space.s
                Repeater {
                    model: root.accents
                    delegate: Item {
                        required property var modelData
                        readonly property bool on: modelData.color.toLowerCase() === Settings.accent.toLowerCase()
                        width: 22
                        height: 22
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            // The wallpaper's colour is shown as the colour it gives today.
                            color: modelData.color.length ? modelData.color : (WallpaperAccent.tone ?? "#0A84FF")
                            border.width: parent.on ? 2 : 0
                            border.color: Tokens.label
                        }
                        Rectangle {
                            visible: !modelData.color.length
                            anchors.centerIn: parent
                            width: 8
                            height: 8
                            radius: 4
                            color: "white"
                            opacity: 0.85
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: Settings.accent = modelData.color
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("settings.appearance.menuBar")
        SettingsRow {
            title: I18n.tr("settings.appearance.barTint")
            MenuSlider {
                width: 240
                backdrop: root.backdrop
                value: Settings.barTint
                onMoved: v => Settings.barTint = v
            }
        }
    }
}
