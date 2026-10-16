import QtQuick
import "../../core"
import ".."

/** Keyboard: aurora's shortcuts. */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.xl

    // i18n-keys: settings.keys.launcher settings.keys.clipboard settings.keys.wallpaper settings.keys.switcher settings.keys.switcherApp settings.keys.lock settings.keys.screenshot settings.keys.region settings.keys.terminal settings.keys.files
    readonly property var shortcuts: [
        ["launcher", "Super Espacio"], ["clipboard", "Super V"], ["wallpaper", "Super C"],
        ["switcher", "Alt Tab"], ["switcherApp", "Alt `"], ["lock", "Super L"],
        ["screenshot", "Impr Pant"], ["region", "Super Shift S"], ["terminal", "Super Return"], ["files", "Super E"]
    ]

    SettingsGroup {
        title: I18n.tr("settings.keys.shortcuts")
        Repeater {
            model: root.shortcuts
            delegate: SettingsRow {
                required property var modelData
                title: I18n.tr("settings.keys." + modelData[0])
                Text {
                    text: modelData[1]
                    color: Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                }
            }
        }
    }
}
