import QtQuick
import "../../core"
import "../../components/menu"
import ".."

/** Notifications: Do Not Disturb and the arrival sound. */
Column {
    property Item backdrop: null
    spacing: Tokens.space.xl

    SettingsGroup {
        footer: I18n.tr("settings.notifications.dndNote")
        SettingsRow {
            title: I18n.tr("controlCenter.focus")
            glyph: Glyphs.moon
            MenuSwitch {
                checked: Settings.doNotDisturb
                onToggled: on => Settings.doNotDisturb = on
            }
        }
        SettingsRow {
            title: I18n.tr("settings.notifications.sounds")
            MenuSwitch {
                checked: Settings.notificationSounds
                onToggled: on => Settings.notificationSounds = on
            }
        }
    }
}
