pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

/**
 * Inactivity: when the screen turns off, the session locks and the computer
 * sleeps (Settings.idleScreenOff / idleLock / idleSuspend, in minutes; 0 =
 * never). hypridle does the watching, so this writes its config from those
 * values and restarts it. Locking always goes through lock.sh (aurora's lock
 * screen) and the session locks before sleeping.
 *
 * Only the Settings app touches this, so a single process writes the file.
 */
Singleton {
    id: root

    readonly property string path: Quickshell.env("HOME") + "/.config/hypr/hypridle.conf"

    function config() {
        const dpms = action => `hyprctl dispatch 'hl.dsp.dpms({ action = "${action}" })'`;
        let out = "# Written by aurora's Settings (Lock Screen). Edit there, not here.\n"
            + "general {\n"
            + "    lock_cmd = " + Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh\n"
            + "    before_sleep_cmd = loginctl lock-session\n"
            + "    after_sleep_cmd = " + dpms("enable") + "\n"
            + "}\n";
        if (Settings.idleScreenOff > 0)
            out += `\nlistener {\n    timeout = ${Settings.idleScreenOff * 60}\n    on-timeout = ${dpms("disable")}\n    on-resume = ${dpms("enable")}\n}\n`;
        if (Settings.idleLock > 0)
            out += `\nlistener {\n    timeout = ${Settings.idleLock * 60}\n    on-timeout = loginctl lock-session\n}\n`;
        if (Settings.idleSuspend > 0)
            out += `\nlistener {\n    timeout = ${Settings.idleSuspend * 60}\n    on-timeout = systemctl suspend\n}\n`;
        return out;
    }

    /** Write the config and restart hypridle (debounced: a choice changes one value at a time). */
    function apply() {
        writeSoon.restart();
    }

    Timer {
        id: writeSoon
        interval: 300
        onTriggered: {
            file.setText(root.config());
            Quickshell.execDetached(["systemctl", "--user", "restart", "hypridle"]);
        }
    }

    FileView {
        id: file
        path: root.path
        // The file is a link into ~/dotfiles: write through it, don't replace it.
        atomicWrites: false
    }
}
