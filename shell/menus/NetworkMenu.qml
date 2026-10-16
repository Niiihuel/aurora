import QtQuick
import Quickshell
import "../core"
import "../components/menu"
import "../services"

/**
 * The network extra's menu, after macOS's Wi-Fi menu: the Wi-Fi title with
 * its switch, Ethernet on top when a cable is connected, the network in use
 * under "Known Network", then "Other Networks" by signal strength with a lock
 * on secured ones. It scans while open. Choosing a known or open network
 * joins it; a new secured network asks for its password (`passwordRequested`).
 *
 * Choosing the network in use shows its details in place (the glass reshapes
 * to them), like the Details of macOS's Wi-Fi settings: disconnect, show or
 * copy the password, auto-join, and Forget This Network… (confirmed by an
 * alert). The back row or Esc returns to the list.
 */
MenuPanel {
    id: root

    panelWidth: 300

    signal passwordRequested(var network)

    /** The network whose details are shown, or null for the list. */
    property var detail: null
    property bool showPassword: false

    function openDetail(network) {
        highlighted = null;
        showPassword = false;
        NetworkStatus.inspect(network);
        detail = network;
    }

    /** Esc: leave the details. False when showing the list. */
    function back() {
        if (!detail)
            return false;
        highlighted = null;
        detail = null;
        showPassword = false;
        NetworkStatus.password = "";
        return true;
    }

    Component.onCompleted: NetworkStatus.setScanning(true)
    Component.onDestruction: {
        NetworkStatus.setScanning(false);
        NetworkStatus.password = "";
    }

    // --- The list ----------------------------------------------------------------

    MenuHeader {
        visible: !root.detail
        title: I18n.tr("network.wifi")
        hasSwitch: !!NetworkStatus.wifiDevice
        checked: NetworkStatus.wifiEnabled
        onToggled: on => NetworkStatus.setWifiEnabled(on)
    }

    Column {
        width: parent.width
        visible: !root.detail && NetworkStatus.wired

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

    Column {
        width: parent.width
        visible: !root.detail && NetworkStatus.wifiEnabled && !!NetworkStatus.wifiNetwork

        MenuSeparator {}
        MenuSectionTitle { text: I18n.tr("network.knownNetwork") }
        MenuDeviceItem {
            readonly property var network: NetworkStatus.wifiNetwork
            badge: Glyphs.wifi(NetworkStatus.bars)
            active: true
            name: network ? network.name : ""
            status: network && network.stateChanging ? I18n.tr("network.connecting") : ""
            busy: !!network && network.stateChanging
            trailingGlyph: NetworkStatus.secured(network) ? Glyphs.lock : null
            closeOnTrigger: false
            onTriggered: root.openDetail(network)
        }
    }

    Column {
        width: parent.width
        visible: !root.detail && NetworkStatus.wifiEnabled && !!NetworkStatus.wifiDevice

        MenuSeparator {}
        MenuSectionTitle { text: I18n.tr("network.otherNetworks") }

        Repeater {
            // Re-sorted on every signal change while scanning: keep the rows.
            model: ScriptModel { values: NetworkStatus.otherNetworks }
            delegate: MenuDeviceItem {
                required property var modelData
                badge: Glyphs.wifi(NetworkStatus.barsOf(modelData))
                name: modelData.name
                status: modelData.stateChanging ? I18n.tr("network.connecting") : ""
                busy: modelData.stateChanging
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
            busy: true
            enabled: false
        }
    }

    MenuItem {
        visible: !root.detail && !NetworkStatus.wifiEnabled
        text: I18n.tr("network.wifiOff")
        enabled: false
    }

    MenuSeparator { visible: !root.detail }

    MenuItem {
        visible: !root.detail
        text: I18n.tr("network.settings")
        onTriggered: Session.openSettings("wifi")
    }

    // --- A network's details -------------------------------------------------------

    Column {
        width: parent.width
        visible: !!root.detail

        MenuItem {
            text: I18n.tr("network.wifi")
            glyph: Glyphs.chevronBack
            closeOnTrigger: false
            onTriggered: root.back()
        }

        MenuDeviceItem {
            badge: Glyphs.wifi(root.detail ? NetworkStatus.barsOf(root.detail) : 0)
            active: !!root.detail && root.detail.connected
            name: root.detail ? root.detail.name : ""
            status: root.detail && root.detail.connected ? I18n.tr("network.connected") : ""
            trailingGlyph: NetworkStatus.secured(root.detail) ? Glyphs.lock : null
            closeOnTrigger: false
        }

        MenuSeparator {}

        MenuItem {
            text: root.detail && root.detail.connected ? I18n.tr("network.disconnect") : I18n.tr("network.join")
            closeOnTrigger: false
            onTriggered: {
                if (root.detail.connected) {
                    NetworkStatus.disconnect(root.detail);
                    root.back();
                } else {
                    NetworkStatus.join(root.detail);
                }
            }
        }

        Column {
            width: parent.width
            visible: NetworkStatus.secured(root.detail) && !!NetworkStatus.profile

            MenuSeparator {}
            MenuSectionTitle { text: I18n.tr("network.password") }
            MenuInfo {
                text: root.showPassword && NetworkStatus.password.length ? NetworkStatus.password : "••••••••••"
            }
            MenuItem {
                text: root.showPassword ? I18n.tr("network.hidePassword") : I18n.tr("network.showPassword")
                closeOnTrigger: false
                onTriggered: {
                    root.showPassword = !root.showPassword;
                    if (root.showPassword)
                        NetworkStatus.revealPassword();
                    else
                        NetworkStatus.password = "";
                }
            }
            MenuItem {
                text: I18n.tr("network.copyPassword")
                onTriggered: NetworkStatus.copyPassword()
            }
        }

        MenuSeparator {}

        MenuItem {
            text: I18n.tr("network.autoJoin")
            reserveMark: true
            checked: !!NetworkStatus.profile && NetworkStatus.profile.autoJoin
            enabled: !!NetworkStatus.profile
            closeOnTrigger: false
            onTriggered: NetworkStatus.setAutoJoin(!NetworkStatus.profile.autoJoin)
        }

        MenuSeparator {}

        MenuItem {
            text: I18n.tr("network.forget")
            destructive: true
            onTriggered: {
                const network = root.detail;
                Dialogs.confirm({
                    title: I18n.tr("network.forget.title", { name: network.name }),
                    message: I18n.tr("network.forget.message"),
                    action: I18n.tr("network.forget.action"),
                    destructive: true,
                    run: () => NetworkStatus.forget(network)
                });
            }
        }
    }
}
