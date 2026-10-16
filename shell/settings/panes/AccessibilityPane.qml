import QtQuick
import "../../core"
import "../../components/menu"
import ".."

/** Accessibility: Reduce Motion and Reduce Transparency, as on macOS. */
Column {
    property Item backdrop: null
    spacing: Tokens.space.xl

    SettingsGroup {
        footer: I18n.tr("settings.accessibility.note")
        SettingsRow {
            title: I18n.tr("settings.accessibility.reduceMotion")
            MenuSwitch {
                checked: Settings.reduceMotion
                onToggled: on => Settings.reduceMotion = on
            }
        }
        SettingsRow {
            title: I18n.tr("settings.accessibility.reduceTransparency")
            MenuSwitch {
                checked: Settings.reduceTransparency
                onToggled: on => Settings.reduceTransparency = on
            }
        }
    }
}
