import QtQuick
import "../../core"
import "../../components/menu"
import ".."

/** Control Center and the menu bar: what the bar shows. */
Column {
    property Item backdrop: null
    spacing: Tokens.space.xl

    SettingsGroup {
        title: I18n.tr("settings.controlCenter.menuBar")
        SettingsRow {
            title: I18n.tr("settings.battery.percent")
            MenuSwitch {
                checked: Settings.batteryPercent
                onToggled: on => Settings.batteryPercent = on
            }
        }
        SettingsRow {
            title: I18n.tr("settings.controlCenter.activity")
            MenuSwitch {
                checked: Settings.activityExtra
                onToggled: on => Settings.activityExtra = on
            }
        }
        SettingsRow {
            title: I18n.tr("settings.controlCenter.seconds")
            MenuSwitch {
                checked: Settings.clockSeconds
                onToggled: on => Settings.clockSeconds = on
            }
        }
    }
}
