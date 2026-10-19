import QtQuick
import "../../core"
import "../../components"
import "../../components/menu"
import "../../services"
import ".."

/** Battery: the charge, the energy mode, and the percentage in the menu bar. */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.xl

    // i18n-keys: battery.mode.saver battery.mode.balanced battery.mode.performance
    readonly property var modes: BatteryStatus.hasPerformance ? ["saver", "balanced", "performance"] : ["saver", "balanced"]

    SettingsGroup {
        SettingsRow {
            title: I18n.tr("battery.title")
            subtitle: I18n.tr("battery.source", { source: BatteryStatus.pluggedIn ? I18n.tr("battery.source.adapter") : I18n.tr("battery.source.battery") })
            glyph: Glyphs.bolt
            Text {
                text: I18n.tr("common.percent", { n: Math.round(BatteryStatus.level * 100) })
                color: Tokens.secondaryLabel
                font.family: Tokens.family
                font.pixelSize: Tokens.type.body.size
            }
        }
        SettingsRow {
            title: I18n.tr("battery.mode")
            SegmentedControl {
                width: 300
                backdrop: root.backdrop
                options: root.modes.map(m => I18n.tr("battery.mode." + m))
                selected: Math.max(0, root.modes.indexOf(BatteryStatus.mode))
                onActivated: i => BatteryStatus.setMode(root.modes[i])
            }
        }
        SettingsRow {
            title: I18n.tr("settings.battery.percent")
            MenuSwitch {
                checked: Settings.batteryPercent
                onToggled: on => Settings.batteryPercent = on
            }
        }
    }
}
