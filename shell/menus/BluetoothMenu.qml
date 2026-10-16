import QtQuick
import Quickshell
import "../core"
import "../components/menu"
import "../services"
import Quickshell.Bluetooth

/**
 * The Bluetooth extra's menu, after macOS: the title with its switch, the
 * paired devices (kind glyph in a circle, accent when connected, with the
 * connection state and battery under the name), and the settings entry.
 * Choosing a device connects or disconnects it in place.
 */
MenuPanel {
    id: root

    panelWidth: 280

    MenuHeader {
        title: I18n.tr("bluetooth.title")
        hasSwitch: BluetoothStatus.present
        checked: BluetoothStatus.enabled
        onToggled: on => BluetoothStatus.setEnabled(on)
    }

    Column {
        width: parent.width
        visible: BluetoothStatus.enabled

        MenuSeparator {}
        MenuSectionTitle { text: I18n.tr("bluetooth.devices") }

        Repeater {
            model: ScriptModel { values: BluetoothStatus.devices }
            delegate: MenuDeviceItem {
                required property var modelData
                readonly property real battery: BluetoothStatus.batteryOf(modelData)
                badge: Glyphs.forDevice(modelData.icon)
                active: modelData.connected
                busy: BluetoothStatus.busy(modelData)
                name: BluetoothStatus.nameOf(modelData)
                status: {
                    const d = modelData;
                    if (d.state === BluetoothDeviceState.Connecting)
                        return I18n.tr("bluetooth.connecting");
                    if (d.state === BluetoothDeviceState.Disconnecting)
                        return I18n.tr("bluetooth.disconnecting");
                    if (!d.connected)
                        return "";
                    return battery >= 0
                        ? I18n.tr("bluetooth.connectedBattery", { n: Math.round(battery * 100) })
                        : I18n.tr("bluetooth.connected");
                }
                closeOnTrigger: false
                onTriggered: BluetoothStatus.toggle(modelData)
            }
        }

        MenuItem {
            visible: BluetoothStatus.devices.length === 0
            text: I18n.tr("bluetooth.noDevices")
            enabled: false
        }
    }

    MenuItem {
        visible: BluetoothStatus.present && !BluetoothStatus.enabled
        text: I18n.tr("bluetooth.off")
        enabled: false
    }

    MenuSeparator {}

    MenuItem {
        text: I18n.tr("bluetooth.settings")
        onTriggered: Session.openSettings("bluetooth")
    }
}
