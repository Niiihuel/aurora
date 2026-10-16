pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

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
}
