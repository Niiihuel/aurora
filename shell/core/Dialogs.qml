pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

/**
 * System dialogs the shell can raise (one at a time, like macOS alerts).
 * Today: the Wi-Fi password prompt. A dialog shows on the focused screen.
 */
Singleton {
    id: root

    /** The secured network waiting for a password, or null. */
    property var wifiNetwork: null
    /** True when the prompt reopened because the last password was rejected. */
    property bool wifiRejected: false
    /** The network being joined with a typed password, watched for failure. */
    property var joining: null

    function askWifiPassword(network) {
        wifiRejected = false;
        wifiNetwork = network;
    }

    function dismiss() {
        wifiNetwork = null;
    }

    /** Called by the prompt after submitting a password. */
    function watchJoin(network) {
        joining = network;
    }

    // A rejected password brings the prompt back (it shakes, like macOS);
    // any other failure or a successful join just stops watching.
    Connections {
        target: root.joining
        ignoreUnknownSignals: true
        function onConnectionFailed(reason) {
            const network = root.joining;
            root.joining = null;
            if (reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiClientFailed
                || reason === ConnectionFailReason.WifiAuthTimeout) {
                root.wifiNetwork = network;
                root.wifiRejected = true;
            }
        }
        function onConnectedChanged() {
            if (root.joining && root.joining.connected)
                root.joining = null;
        }
    }

    /**
     * A confirmation alert: { title, message, action, destructive, seconds,
     * run }. With `seconds`, the alert counts down and runs the action when
     * it reaches zero, as macOS does for Restart and Shut Down; `message` may
     * use {seconds} for the live count.
     */
    property var confirmation: null

    function confirm(request) {
        confirmation = request;
    }

    function resolve(accepted) {
        const request = confirmation;
        confirmation = null;
        if (accepted && request && request.run)
            request.run();
    }
}
