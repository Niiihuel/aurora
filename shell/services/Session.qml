pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

/**
 * Session and power actions for the system menu. Locking asks logind
 * (`loginctl lock-session`), so whichever locker the session runs answers it.
 * Nothing here asks for confirmation: the menu routes Restart…, Shut Down…
 * and Log Out… through Dialogs.confirm first, like macOS.
 */
Singleton {
    readonly property string user: Quickshell.env("USER") || ""

    function sleep() { Quickshell.execDetached(["systemctl", "suspend"]); }
    function lock() { Quickshell.execDetached(["loginctl", "lock-session"]); }
    function restart() { Quickshell.execDetached(["systemctl", "reboot"]); }
    function shutDown() { Quickshell.execDetached(["systemctl", "poweroff"]); }
    function logOut() { Hyprland.dispatch("hl.dsp.exit()"); }
    /** Open aurora's Settings on a page ("wifi", "sound"…), or bring it forward. */
    function openSettings(page) { Quickshell.execDetached([Quickshell.shellDir + "/../scripts/aurora-settings", page || ""]); }
}
