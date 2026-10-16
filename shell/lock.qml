import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "core"
import "services"
import "lock"

/**
 * aurora's lock screen, run as its own process (`qs -p shell/lock.qml`) so the
 * menu bar's hot reloads never touch a locked session. See lock/LockScreen.
 *
 *   qs -p …/shell/lock.qml ipc call lock lock      lock the session
 *   qs -p …/shell/lock.qml ipc call lock preview   the same screen in a normal
 *                                                  overlay, without locking: try
 *                                                  the look and the password
 *
 * While locked a marker file exists in $XDG_RUNTIME_DIR. If this process dies
 * locked, the session supervisor restarts it and it locks again at once
 * (Hyprland's misc:allow_session_lock_restore lets a new client take over),
 * so a crash never strands the screen.
 */
ShellRoot {
    id: root

    property bool locked: false
    property bool previewing: false
    property bool leaving: false
    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/aurora-locked"

    function lock() {
        leaving = false;
        locked = true;
        Quickshell.execDetached(["touch", marker]);
    }

    function preview() {
        leaving = false;
        previewing = true;
    }

    /** Unlock: play the fade, then let go. */
    function release() {
        leaving = true;
        releaseTimer.restart();
    }

    signal rejected()

    Auth {
        id: auth
        onSucceeded: root.release()
        onFailed: root.rejected()
    }

    Timer {
        id: releaseTimer
        interval: 380
        onTriggered: {
            if (root.locked)
                Quickshell.execDetached(["rm", "-f", root.marker]);
            root.locked = false;
            root.previewing = false;
            root.leaving = false;
        }
    }

    // Relock after a crash.
    Process {
        running: true
        command: ["test", "-e", root.marker]
        onExited: code => {
            if (code === 0)
                root.lock();
        }
    }

    WlSessionLock {
        locked: root.locked

        WlSessionLockSurface {
            id: surface
            color: "black"

            LockScreen {
                id: lockScreen
                anchors.fill: parent
                screen: surface.screen
                primary: !Quickshell.screens.length || surface.screen.name === Quickshell.screens[0].name
                auth: auth
                leaving: root.leaving
                Connections {
                    target: root
                    function onRejected() { lockScreen.rejected(); }
                }
            }
        }
    }

    // The preview: the same screen over the desktop, without locking.
    PanelWindow {
        visible: root.previewing
        screen: Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        color: "black"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aurora-lock-preview"
        WlrLayershell.keyboardFocus: root.previewing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Loader {
            anchors.fill: parent
            active: root.previewing
            sourceComponent: LockScreen {
                id: previewScreen
                screen: Quickshell.screens[0]
                auth: auth
                leaving: root.leaving
                onCancelled: root.previewing = false
                Connections {
                    target: root
                    function onRejected() { previewScreen.rejected(); }
                }
            }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.lock(); }
        function preview(): void { root.preview(); }
    }
}
