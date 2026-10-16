import QtQuick
import "../../core"
import "../../components"
import "../../components/menu"
import "../../services"
import ".."

/** Bluetooth: the switch and the paired devices (click to connect or disconnect). */
Column {
    property Item backdrop: null
    spacing: Tokens.space.xl

    SettingsGroup {
        SettingsRow {
            title: I18n.tr("bluetooth.title")
            glyph: Glyphs.bluetooth("on")
            glyphTint: Tokens.accent
            MenuSwitch {
                checked: BluetoothStatus.enabled
                onToggled: on => BluetoothStatus.setEnabled(on)
            }
        }
    }

    SettingsGroup {
        visible: BluetoothStatus.enabled
        title: I18n.tr("bluetooth.devices")
        Repeater {
            model: BluetoothStatus.devices
            delegate: SettingsRow {
                required property var modelData
                title: BluetoothStatus.nameOf(modelData)
                subtitle: modelData.connected ? I18n.tr("bluetooth.connected") : ""
                glyph: Glyphs.forDevice(modelData.icon)
                glyphTint: modelData.connected ? Tokens.accent : Tokens.toggleOff
                interactive: true
                onClicked: BluetoothStatus.toggle(modelData)
            }
        }
        SettingsRow {
            visible: BluetoothStatus.devices.length === 0
            title: I18n.tr("bluetooth.noDevices")
        }
    }
}
