pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io

/**
 * Network state and actions for the menu bar's network extra and its menu.
 * A wired link wins over Wi-Fi for the bar glyph (like macOS when Ethernet is
 * up); the menu shows both. `kind` is "wired", "wifi", "wifi-off" or "none".
 */
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null

    readonly property bool wired: !!wiredDevice && wiredDevice.connected
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var wifiNetwork: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null

    /** 0–1 from any 0–1 or 0–100 scale. */
    function strengthOf(network) {
        const s = network ? network.signalStrength : 0;
        return s > 1 ? s / 100 : s;
    }
    function barsOf(network) {
        const s = strengthOf(network);
        return s >= 0.67 ? 3 : s >= 0.34 ? 2 : s > 0 ? 1 : 0;
    }

    readonly property real strength: strengthOf(wifiNetwork)
    readonly property int bars: barsOf(wifiNetwork)

    readonly property string kind: wired ? "wired" : !wifiEnabled ? "wifi-off" : wifiNetwork ? "wifi" : "none"
    readonly property string name: wired ? "Ethernet" : wifiNetwork ? wifiNetwork.name : ""

    function secured(network) {
        return !!network && network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }

    /**
     * Visible Wi-Fi networks other than the connected one, one row per name
     * (several access points of one network collapse to the strongest),
     * strongest first. Hidden (unnamed) networks are left out.
     */
    readonly property var otherNetworks: {
        if (!wifiDevice)
            return [];
        const best = {};
        for (const n of wifiDevice.networks.values) {
            if (!n.name || n.connected)
                continue;
            if (!best[n.name] || strengthOf(n) > strengthOf(best[n.name]))
                best[n.name] = n;
        }
        return Object.values(best).sort((a, b) => strengthOf(b) - strengthOf(a));
    }

    function setWifiEnabled(on) {
        Networking.wifiEnabled = on;
    }

    /** Airplane Mode: every radio off (Wi-Fi and Bluetooth; there's no WWAN here). */
    readonly property bool airplane: !wifiEnabled && !BluetoothStatus.enabled
    function setAirplane(on) {
        setWifiEnabled(!on);
        BluetoothStatus.setEnabled(!on);
    }

    /** Keep scanning for networks while a menu shows them, like macOS. */
    function setScanning(on) {
        if (wifiDevice)
            wifiDevice.scannerEnabled = on;
    }

    /**
     * Join a network: known and open ones connect directly; a new secured one
     * needs a password, so this returns false and the caller asks for it.
     */
    function join(network) {
        if (!network)
            return true;
        if (network.known || !secured(network)) {
            network.connect();
            return true;
        }
        return false;
    }

    function joinWithPassword(network, password) {
        if (network)
            network.connectWithPsk(password);
    }

    function disconnect(network) {
        if (network)
            network.disconnect();
    }

    // --- A saved network's details (the Wi-Fi menu's detail view) ------------
    // NetworkManager's profile for an SSID: Quickshell exposes forget() but not
    // auto-join or the stored password, so those go through nmcli. The
    // password is read only when asked for and dropped when the view closes.

    /** { uuid, autoJoin } of the network being inspected, or null. */
    property var profile: null
    property string password: ""

    function inspect(network) {
        profile = null;
        password = "";
        if (!network)
            return;
        profileQuery.ssid = network.name;
        profileQuery.running = true;
    }

    function revealPassword() {
        if (profile) {
            passwordQuery.uuid = profile.uuid;
            passwordQuery.running = true;
        }
    }

    function copyPassword() {
        // Piped straight into the clipboard, so the secret never passes through QML.
        if (profile)
            Quickshell.execDetached(["sh", "-c", "nmcli -s -g 802-11-wireless-security.psk connection show \"$1\" | tr -d '\\n' | wl-copy", "_", profile.uuid]);
    }

    function setAutoJoin(on) {
        if (!profile)
            return;
        Quickshell.execDetached(["nmcli", "connection", "modify", profile.uuid, "connection.autoconnect", on ? "yes" : "no"]);
        profile = { uuid: profile.uuid, autoJoin: on };
    }

    function forget(network) {
        if (network)
            network.forget();
    }

    Process {
        id: profileQuery
        property string ssid: ""
        command: ["sh", "-c", "nmcli -t -f UUID,TYPE connection show | while IFS=: read -r u t; do [ \"$t\" = 802-11-wireless ] || continue; if [ \"$(nmcli -g 802-11-wireless.ssid connection show \"$u\")\" = \"$1\" ]; then echo \"$u\"; nmcli -g connection.autoconnect connection show \"$u\"; break; fi; done", "_", ssid]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                root.profile = lines[0] ? { uuid: lines[0], autoJoin: lines[1] === "yes" } : null;
            }
        }
    }

    Process {
        id: passwordQuery
        property string uuid: ""
        command: ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "connection", "show", uuid]
        stdout: StdioCollector {
            onStreamFinished: root.password = this.text.trim()
        }
    }
}
