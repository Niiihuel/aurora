pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * The built-in display for Control Center: backlight brightness and the night
 * light.
 *
 * Brightness is read from /sys/class/backlight and set with brightnessctl.
 * Hybrid laptops list a second backlight for the discrete GPU (nvidia_0 here)
 * that drives nothing, and brightnessctl picks it by default, so the panel's
 * own device is chosen explicitly. Setting is throttled: a slider drag would
 * otherwise spawn a process per pointer move.
 *
 * The night light is hyprsunset, through Hyprland's IPC: on warms the screen
 * to `nightTemperature`, off restores the identity transform.
 */
Singleton {
    id: root

    property string device: ""
    readonly property bool hasBacklight: device.length > 0
    /** 0–1. */
    property real brightness: 0
    property bool nightLight: false
    /** Keyboard backlight (a LED class device), its level and top level. */
    property string keyboardDevice: ""
    property int keyboardLevel: 0
    property int keyboardMax: 0
    readonly property bool hasKeyboardLight: keyboardDevice.length > 0 && keyboardMax > 0
    readonly property int nightTemperature: 4500

    /** Read both again (the brightness keys change them behind our back). */
    function refresh() {
        if (!backlights.running)
            backlights.running = true;
        if (!sunset.running)
            sunset.running = true;
        if (!keyboard.running)
            keyboard.running = true;
    }

    function setBrightness(v) {
        // Never fully dark: macOS stops at its dimmest step, not at off.
        brightness = Math.max(0.01, Math.min(1, v));
        if (!applyBrightness.running)
            applyBrightness.start();
    }

    /** Step the keyboard backlight up, wrapping to off after the brightest level. */
    function cycleKeyboard() {
        if (!hasKeyboardLight)
            return;
        keyboardLevel = (keyboardLevel + 1) % (keyboardMax + 1);
        Quickshell.execDetached(["brightnessctl", "-q", "-d", keyboardDevice, "set", String(keyboardLevel)]);
    }

    function setNightLight(on) {
        nightLight = on;
        Quickshell.execDetached(on ? ["hyprctl", "hyprsunset", "temperature", String(nightTemperature)]
                                   : ["hyprctl", "hyprsunset", "identity"]);
    }

    Timer {
        id: applyBrightness
        interval: 50
        onTriggered: if (root.hasBacklight)
            Quickshell.execDetached(["brightnessctl", "-q", "-d", root.device, "set", Math.round(root.brightness * 100) + "%"])
    }

    Process {
        id: backlights
        running: true
        command: ["sh", "-c", "cd /sys/class/backlight 2>/dev/null && for n in *; do echo \"$n $(cat $n/brightness) $(cat $n/max_brightness)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = this.text.trim().split("\n").filter(l => l.length).map(l => l.split(" "));
                const pick = all.find(f => !f[0].startsWith("nvidia")) ?? all[0];
                if (!pick)
                    return;
                root.device = pick[0];
                if (!applyBrightness.running)
                    root.brightness = Number(pick[1]) / Math.max(1, Number(pick[2]));
            }
        }
    }

    Process {
        id: keyboard
        running: true
        command: ["sh", "-c", "for d in /sys/class/leds/*kbd_backlight*; do [ -e \"$d\" ] && echo \"${d##*/} $(cat $d/brightness) $(cat $d/max_brightness)\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split(" ");
                if (f.length < 3)
                    return;
                root.keyboardDevice = f[0];
                root.keyboardLevel = Number(f[1]);
                root.keyboardMax = Number(f[2]);
            }
        }
    }

    Process {
        id: sunset
        running: true
        command: ["hyprctl", "hyprsunset", "temperature"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = parseInt(this.text);
                // Identity reads back as hyprsunset's neutral 6000 K.
                root.nightLight = t > 0 && t < 5500;
            }
        }
    }
}
