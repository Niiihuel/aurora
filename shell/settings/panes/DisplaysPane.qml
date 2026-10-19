import QtQuick
import Quickshell.Hyprland
import "../../core"
import "../../components/menu"
import "../../services"
import ".."

/** Displays: brightness, the night light and its warmth, and each screen's mode. */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.xl

    Component.onCompleted: DisplayStatus.refresh()

    SettingsGroup {
        visible: DisplayStatus.hasBacklight
        SettingsRow {
            title: I18n.tr("controlCenter.display")
            glyph: Glyphs.sun
            MenuSlider {
                width: 260
                backdrop: root.backdrop
                value: DisplayStatus.brightness
                onMoved: v => DisplayStatus.setBrightness(v)
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("settings.displays.nightLight")
        info: I18n.tr("settings.displays.nightLightNote")
        SettingsRow {
            title: I18n.tr("settings.displays.nightLightOn")
            MenuSwitch {
                checked: DisplayStatus.nightLight
                onToggled: on => DisplayStatus.setNightLight(on)
            }
        }
        SettingsRow {
            title: I18n.tr("settings.displays.warmth")
            subtitle: I18n.tr("settings.displays.kelvin", { n: Settings.nightLightTemperature })
            MenuSlider {
                width: 260
                backdrop: root.backdrop
                // Left is warmer: 6000 K → 2500 K.
                value: (6000 - Settings.nightLightTemperature) / 3500
                onMoved: v => Settings.nightLightTemperature = Math.round((6000 - v * 3500) / 100) * 100
            }
        }
    }

    Repeater {
        model: Hyprland.monitors.values
        delegate: SettingsGroup {
            required property var modelData
            readonly property var info: modelData.lastIpcObject ?? {}
            title: modelData.name
            SettingsRow {
                title: I18n.tr("settings.displays.resolution")
                Text {
                    text: info.width ? `${info.width} × ${info.height} · ${Math.round(info.refreshRate)} Hz` : ""
                    color: Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                }
            }
            SettingsRow {
                title: I18n.tr("settings.displays.scale")
                Text {
                    text: info.scale ? `${Math.round(info.scale * 100)} %` : ""
                    color: Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                }
            }
        }
    }
}
