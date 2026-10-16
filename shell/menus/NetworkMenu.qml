import QtQuick
import "../core"
import "../components/menu"
import "../services"

/**
 * The network extra's menu, after macOS's Wi-Fi menu: the Wi-Fi title with
 * its switch, Ethernet on top when a cable is connected, the network in use
 * under "Known Network", then "Other Networks" by signal strength with a lock
 * on secured ones. It scans while open. Choosing a known or open network
 * joins it; a new secured network asks for its password (`passwordRequested`).
 */
MenuPanel {
    id: root

    panelWidth: 300

    signal passwordRequested(var network)

    Component.onCompleted: NetworkStatus.setScanning(true)
    Component.onDestruction: NetworkStatus.setScanning(false)

    MenuHeader {
        title: I18n.tr("network.wifi")
        hasSwitch: !!NetworkStatus.wifiDevice
        checked: NetworkStatus.wifiEnabled
        onToggled: on => NetworkStatus.setWifiEnabled(on)
    }

    // --- Ethernet --------------------------------------------------------------
    Column {
        width: parent.width
        visible: NetworkStatus.wired

        MenuSeparator {}
        MenuSectionTitle { text: I18n.tr("network.ethernet") }
        MenuDeviceItem {
            badge: Glyphs.ethernet
            active: true
            name: I18n.tr("network.ethernet")
            status: I18n.tr("network.connected")
            closeOnTrigger: false
        }
    }

    // --- Wi-Fi -----------------------------------------------------------------
    Column {
        width: parent.width
        visible: NetworkStatus.wifiEnabled && !!NetworkStatus.wifiNetwork

        MenuSeparator {}
        MenuSectionTitle { text: I18n.tr("network.knownNetwork") }
        MenuDeviceItem {
            readonly property var network: NetworkStatus.wifiNetwork
            badge: Glyphs.wifi(NetworkStatus.bars)
            active: true
            name: network ? network.name : ""
            status: network && network.stateChanging ? I18n.tr("network.connecting") : ""
            trailingGlyph: NetworkStatus.secured(network) ? Glyphs.lock : null
            closeOnTrigger: false
        }
    }

    Column {
        width: parent.width
        visible: NetworkStatus.wifiEnabled && !!NetworkStatus.wifiDevice

        MenuSeparator {}
        MenuSectionTitle { text: I18n.tr("network.otherNetworks") }

        Repeater {
            model: NetworkStatus.otherNetworks
            delegate: MenuDeviceItem {
                required property var modelData
                badge: Glyphs.wifi(NetworkStatus.barsOf(modelData))
                name: modelData.name
                status: modelData.stateChanging ? I18n.tr("network.connecting") : ""
                trailingGlyph: NetworkStatus.secured(modelData) ? Glyphs.lock : null
                closeOnTrigger: !(NetworkStatus.secured(modelData) && !modelData.known)
                onTriggered: {
                    if (!NetworkStatus.join(modelData))
                        root.passwordRequested(modelData);
                }
            }
        }

        MenuItem {
            visible: NetworkStatus.otherNetworks.length === 0
            text: I18n.tr("network.searching")
            enabled: false
        }
    }

    MenuItem {
        visible: !NetworkStatus.wifiEnabled
        text: I18n.tr("network.wifiOff")
        enabled: false
    }

    MenuSeparator {}

    MenuItem {
        text: I18n.tr("network.settings")
        enabled: false
    }
}
