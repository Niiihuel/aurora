pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

/**
 * Bluetooth state and actions for the menu bar's Bluetooth extra and its menu:
 * on/off, the paired devices, and connecting or disconnecting one.
 */
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: !!adapter
    readonly property bool enabled: present && adapter.enabled
    readonly property var connected: present ? adapter.devices.values.filter(d => d.connected) : []
    readonly property string kind: !enabled ? "off" : connected.length > 0 ? "connected" : "on"

    /** Paired (or connected) devices: connected first, then by name. */
    readonly property var devices: !present ? [] : adapter.devices.values
        .filter(d => d.paired || d.connected)
        .sort((a, b) => (b.connected - a.connected) || nameOf(a).localeCompare(nameOf(b)))

    function nameOf(device) {
        return device ? (device.name || device.deviceName || device.address || "") : "";
    }

    function busy(device) {
        return !!device && (device.state === BluetoothDeviceState.Connecting || device.state === BluetoothDeviceState.Disconnecting);
    }

    /** 0–1 battery from any 0–1 or 0–100 scale, or -1 when unknown. */
    function batteryOf(device) {
        if (!device || !device.batteryAvailable)
            return -1;
        const b = device.battery;
        return b > 1 ? b / 100 : b;
    }

    function setEnabled(on) {
        if (present)
            adapter.enabled = on;
    }

    function toggle(device) {
        if (!device || busy(device))
            return;
        if (device.connected)
            device.disconnect();
        else
            device.connect();
    }
}
