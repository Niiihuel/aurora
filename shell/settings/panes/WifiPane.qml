import QtQuick
import "../../core"
import "../../components"
import "../../components/menu"
import "../../services"
import ".."

/** Wi-Fi: the switch, the network in use, and the others to join. */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.xl

    Component.onCompleted: NetworkStatus.setScanning(true)
    Component.onDestruction: NetworkStatus.setScanning(false)

    SettingsGroup {
        SettingsRow {
            title: I18n.tr("network.wifi")
            glyph: Glyphs.wifi(3)
            MenuSwitch {
                checked: NetworkStatus.wifiEnabled
                onToggled: on => NetworkStatus.setWifiEnabled(on)
            }
        }
        SettingsRow {
            visible: NetworkStatus.wifiEnabled && !!NetworkStatus.wifiNetwork
            title: NetworkStatus.wifiNetwork ? NetworkStatus.wifiNetwork.name : ""
            subtitle: I18n.tr("network.connected")
            Button {
                text: I18n.tr("network.disconnect")
                onClicked: NetworkStatus.disconnect(NetworkStatus.wifiNetwork)
            }
        }
    }

    SettingsGroup {
        visible: NetworkStatus.wifiEnabled
        title: I18n.tr("network.otherNetworks")
        Repeater {
            model: NetworkStatus.otherNetworks
            delegate: SettingsRow {
                required property var modelData
                title: modelData.name
                subtitle: modelData.stateChanging ? I18n.tr("network.connecting") : ""
                busy: modelData.stateChanging
                glyph: Glyphs.wifi(NetworkStatus.barsOf(modelData))
                interactive: true
                onClicked: {
                    if (!NetworkStatus.join(modelData))
                        Dialogs.askWifiPassword(modelData);
                }
                Icon {
                    visible: NetworkStatus.secured(modelData)
                    glyph: Glyphs.lock
                    size: 12
                    color: Tokens.secondaryLabel
                }
            }
        }
        SettingsRow {
            visible: NetworkStatus.otherNetworks.length === 0
            title: I18n.tr("network.searching")
            busy: true
        }
    }
}
