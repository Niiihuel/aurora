pragma Singleton

import QtQuick
import Quickshell

/**
 * aurora's own monochrome icons, drawn on a 16 × 16 point grid with 1.5 pt
 * rounded strokes (Inter's weight at menu bar size). Each glyph is a list of
 * parts: { d: SVG path data, fill: bool, dim: bool }. `dim` parts are drawn in
 * the secondary color (e.g. the missing bars of a weak Wi-Fi signal) so one
 * glyph shows its level the way macOS template icons do. Draw them with
 * components/Icon.
 */
Singleton {
    id: root

    /** The system menu mark: a sun rising over a horizon, aurora's own. */
    readonly property var aurora: [
        { d: "M3.5 11.5 A4.5 4.5 0 0 1 12.5 11.5" },
        { d: "M1.5 11.5 H14.5" },
        { d: "M8 2.6 V4.6 M3.4 4.6 L4.8 6 M12.6 4.6 L11.2 6" }
    ]

    function wifi(bars) {
        return [
            { d: "M8 13.6 m-1.25 0 a1.25 1.25 0 1 0 2.5 0 a1.25 1.25 0 1 0 -2.5 0", fill: true, dim: bars < 1 },
            { d: "M5.3 10.8 A3.9 3.9 0 0 1 10.7 10.8", dim: bars < 1 },
            { d: "M3.1 8.4 A7 7 0 0 1 12.9 8.4", dim: bars < 2 },
            { d: "M0.9 6 A10.1 10.1 0 0 1 15.1 6", dim: bars < 3 }
        ];
    }

    readonly property var wifiOff: [
        { d: "M8 13.6 m-1.25 0 a1.25 1.25 0 1 0 2.5 0 a1.25 1.25 0 1 0 -2.5 0", fill: true, dim: true },
        { d: "M5.3 10.8 A3.9 3.9 0 0 1 10.7 10.8 M3.1 8.4 A7 7 0 0 1 12.9 8.4 M0.9 6 A10.1 10.1 0 0 1 15.1 6", dim: true },
        { d: "M2.5 2.5 L13.5 13.5" }
    ]

    /** Two ports linked to a switch above them. */
    readonly property var ethernet: [
        { d: "M5.75 2 H10.25 V6 H5.75 Z" },
        { d: "M8 6 V8.75 M3.5 8.75 H12.5 M3.5 8.75 V10.5 M12.5 8.75 V10.5" },
        { d: "M1.75 10.5 H5.25 V14 H1.75 Z M10.75 10.5 H14.25 V14 H10.75 Z" }
    ]

    function bluetooth(state) {
        return [{ d: "M4.75 5 L11 11 L7.75 14 V2 L11 5 L4.75 11", dim: state === "off" }];
    }

    function speaker(waves) {
        const parts = [{ d: "M1.75 6 H4.5 L8 3 V13 L4.5 10 H1.75 Z" }];
        if (waves === 0) {
            parts.push({ d: "M10.75 6 L14.25 10 M14.25 6 L10.75 10" });
            return parts;
        }
        parts.push({ d: "M10.25 6.25 A2.6 2.6 0 0 1 10.25 9.75" });
        parts.push({ d: "M12 4.5 A5.1 5.1 0 0 1 12 11.5", dim: waves < 2 });
        parts.push({ d: "M13.75 2.75 A7.6 7.6 0 0 1 13.75 13.25", dim: waves < 3 });
        return parts;
    }

    /** Control Center: two switches, one on (knob right), one off (knob left). */
    readonly property var controlCenter: [
        { d: "M4 2 H12 A3 3 0 0 1 12 8 H4 A3 3 0 0 1 4 2 Z" },
        { d: "M12 3.5 A1.5 1.5 0 1 1 12 6.5 A1.5 1.5 0 1 1 12 3.5 Z", fill: true },
        { d: "M4 9 H12 A3 3 0 0 1 12 15 H4 A3 3 0 0 1 4 9 Z" },
        { d: "M4 10.5 A1.5 1.5 0 1 1 4 13.5 A1.5 1.5 0 1 1 4 10.5 Z", fill: true }
    ]

    /** A menu item's "in effect" mark. */
    readonly property var checkmark: [
        { d: "M3.5 8.5 L6.5 11.5 L12.5 4.5" }
    ]

    /** A menu item that opens a submenu. */
    readonly property var chevron: [
        { d: "M6 3.5 L10.5 8 L6 12.5" }
    ]

    // --- Device kinds (Bluetooth menu) -------------------------------------

    readonly property var headphones: [
        { d: "M2.75 10.5 V8.5 A5.25 5.25 0 0 1 13.25 8.5 V10.5" },
        { d: "M2.25 9.75 H5 V14.25 H3.5 A1.25 1.25 0 0 1 2.25 13 Z", fill: true },
        { d: "M13.75 9.75 H11 V14.25 H12.5 A1.25 1.25 0 0 0 13.75 13 Z", fill: true }
    ]
    readonly property var mouse: [
        { d: "M8 1.75 A4.25 4.25 0 0 1 12.25 6 V10 A4.25 4.25 0 0 1 3.75 10 V6 A4.25 4.25 0 0 1 8 1.75 Z" },
        { d: "M8 4.25 V6.5" }
    ]
    readonly property var keyboard: [
        { d: "M1.75 4 H14.25 V12 H1.75 Z" },
        { d: "M4.25 6.75 H4.26 M6.75 6.75 H6.76 M9.25 6.75 H9.26 M11.75 6.75 H11.76 M5 9.5 H11" }
    ]
    readonly property var phone: [
        { d: "M5.25 1.5 H10.75 A1.5 1.5 0 0 1 12.25 3 V13 A1.5 1.5 0 0 1 10.75 14.5 H5.25 A1.5 1.5 0 0 1 3.75 13 V3 A1.5 1.5 0 0 1 5.25 1.5 Z" },
        { d: "M7 12.25 H9" }
    ]
    readonly property var gamepad: [
        { d: "M4.75 4.75 H11.25 A3.5 3.5 0 0 1 14.75 8.25 V9.75 A2.5 2.5 0 0 1 10.5 11.5 L9.5 10.5 H6.5 L5.5 11.5 A2.5 2.5 0 0 1 1.25 9.75 V8.25 A3.5 3.5 0 0 1 4.75 4.75 Z" },
        { d: "M4.75 6.75 V9.25 M3.5 8 H6 M11 7.5 H11.01 M12.25 8.75 H12.26" }
    ]
    readonly property var computer: [
        { d: "M3 3.25 H13 V10.5 H3 Z" },
        { d: "M1 12.75 H15" }
    ]

    /**
     * Glyph for a BlueZ device icon name ("audio-headset", "input-mouse"…);
     * anything unknown gets the Bluetooth mark.
     */
    function forDevice(icon) {
        const name = icon || "";
        if (name.startsWith("audio-head") || name === "audio-card") return headphones;
        if (name.startsWith("audio-speaker")) return speaker(2);
        if (name === "input-mouse" || name === "input-tablet") return mouse;
        if (name === "input-keyboard") return keyboard;
        if (name === "input-gaming") return gamepad;
        if (name === "phone") return phone;
        if (name === "computer") return computer;
        return bluetooth("on");
    }

    /** A secured network. */
    readonly property var lock: [
        { d: "M5 7.25 V5.25 A3 3 0 0 1 11 5.25 V7.25" },
        { d: "M3.75 7.25 H12.25 V14 H3.75 Z", fill: true }
    ]

    // --- Control Center ----------------------------------------------------------

    /** Back to the previous level (Control Center detail pages). */
    readonly property var chevronBack: [
        { d: "M10 3.5 L5.5 8 L10 12.5" }
    ]
    /** Do Not Disturb: a crescent moon. */
    readonly property var moon: [
        { d: "M13.5 9.9 A5.9 5.9 0 1 1 6.1 2.5 A4.6 4.6 0 0 0 13.5 9.9 Z", fill: true }
    ]
    /** Display brightness: a sun. */
    readonly property var sun: [
        { d: "M8 5.25 A2.75 2.75 0 1 1 8 10.75 A2.75 2.75 0 1 1 8 5.25 Z", fill: true },
        { d: "M8 1.25 V2.75 M8 13.25 V14.75 M1.25 8 H2.75 M13.25 8 H14.75 M3.2 3.2 L4.25 4.25 M11.75 11.75 L12.8 12.8 M3.2 12.8 L4.25 11.75 M11.75 4.25 L12.8 3.2" }
    ]
    /** Dark Mode: a disc half dark (filled), half light. */
    readonly property var darkMode: [
        { d: "M8 2 A6 6 0 1 1 8 14 A6 6 0 1 1 8 2 Z" },
        { d: "M8 2 A6 6 0 0 0 8 14 Z", fill: true }
    ]
    /** Night light: a crescent outline with two small stars. */
    readonly property var nightLight: [
        { d: "M12.5 10.4 A5.4 5.4 0 1 1 5.6 3.5 A4.2 4.2 0 0 0 12.5 10.4 Z" },
        { d: "M11.25 2 V4.5 M10 3.25 H12.5 M13.75 5.75 V7.25 M13 6.5 H14.5" }
    ]
    /** Screenshot: a viewfinder. */
    readonly property var screenshot: [
        { d: "M1.75 5.25 V3.25 A1.5 1.5 0 0 1 3.25 1.75 H5.25 M10.75 1.75 H12.75 A1.5 1.5 0 0 1 14.25 3.25 V5.25 M14.25 10.75 V12.75 A1.5 1.5 0 0 1 12.75 14.25 H10.75 M5.25 14.25 H3.25 A1.5 1.5 0 0 1 1.75 12.75 V10.75" },
        { d: "M8 5.6 A2.4 2.4 0 1 1 8 10.4 A2.4 2.4 0 1 1 8 5.6 Z" }
    ]
    /** Color picker: an eyedropper. */
    readonly property var eyedropper: [
        { d: "M9.25 4.25 L11.75 6.75 M10.5 2.9 L13.1 5.5 A1.4 1.4 0 0 0 13.1 3.5 L12.5 2.9 A1.4 1.4 0 0 0 10.5 2.9 Z" },
        { d: "M10.5 5.5 L4 12 L2.5 13.5 M4 12 L3.25 10.5 L9 4.75" }
    ]
    /** Choose the sound output: a speaker cone under sound waves. */
    readonly property var output: [
        { d: "M3.5 10.5 A5.5 5.5 0 1 1 12.5 10.5 M5.5 9 A3 3 0 1 1 10.5 9" },
        { d: "M8 9.5 L11 14.25 H5 Z", fill: true }
    ]
    readonly property var airplane: [
        { d: "M8 1.25 C8.75 1.25 9.1 2 9.1 2.9 V6.3 L14.5 9.3 V10.9 L9.1 9.3 V12.2 L10.75 13.4 V14.6 L8 13.8 L5.25 14.6 V13.4 L6.9 12.2 V9.3 L1.5 10.9 V9.3 L6.9 6.3 V2.9 C6.9 2 7.25 1.25 8 1.25 Z", fill: true }
    ]
    /** Energy modes: a leaf (saver), a gauge (automatic); performance uses `bolt`. */
    readonly property var leaf: [
        { d: "M2.75 13.25 C2.75 7 6.75 2.75 13.25 2.75 C13.25 9.25 9 13.25 2.75 13.25 Z" },
        { d: "M2.75 13.25 L8.75 7.25" }
    ]
    readonly property var gauge: [
        { d: "M2.25 11.5 A5.75 5.75 0 0 1 13.75 11.5" },
        { d: "M8 11.5 L10.75 7.25" }
    ]
    /** Now Playing transport. */
    readonly property var play: [
        { d: "M4.75 2.75 L13 8 L4.75 13.25 Z", fill: true }
    ]
    readonly property var pause: [
        { d: "M4.25 2.75 H6.75 V13.25 H4.25 Z M9.25 2.75 H11.75 V13.25 H9.25 Z", fill: true }
    ]
    readonly property var forward: [
        { d: "M1.5 3.75 L8 8 L1.5 12.25 Z M8 3.75 L14.5 8 L8 12.25 Z", fill: true }
    ]
    readonly property var backward: [
        { d: "M14.5 3.75 L8 8 L14.5 12.25 Z M8 3.75 L1.5 8 L8 12.25 Z", fill: true }
    ]

    // --- Notifications and the launcher ---------------------------------------

    /** Close / clear. */
    readonly property var xmark: [
        { d: "M4.25 4.25 L11.75 11.75 M11.75 4.25 L4.25 11.75" }
    ]
    /** A bell, for a notification whose app has no icon. */
    readonly property var bell: [
        { d: "M4 11.25 V7.25 A4 4 0 0 1 12 7.25 V11.25 L13.25 12.5 H2.75 Z" },
        { d: "M6.75 14 A1.4 1.4 0 0 0 9.25 14" }
    ]
    /** Search. */
    readonly property var magnifier: [
        { d: "M7 2.25 A4.75 4.75 0 1 1 7 11.75 A4.75 4.75 0 1 1 7 2.25 Z" },
        { d: "M10.5 10.5 L14 14" }
    ]
    /** Applications: a 2×2 grid of rounded squares. */
    readonly property var apps: [
        { d: "M2.5 2.5 H6.75 V6.75 H2.5 Z M9.25 2.5 H13.5 V6.75 H9.25 Z M2.5 9.25 H6.75 V13.5 H2.5 Z M9.25 9.25 H13.5 V13.5 H9.25 Z" }
    ]
    /** Clipboard history. */
    readonly property var clipboard: [
        { d: "M5.5 2.75 H3.75 A1 1 0 0 0 2.75 3.75 V13.75 A1 1 0 0 0 3.75 14.75 H12.25 A1 1 0 0 0 13.25 13.75 V3.75 A1 1 0 0 0 12.25 2.75 H10.5" },
        { d: "M5.5 1.5 H10.5 V4 H5.5 Z M5.25 8 H10.75 M5.25 11 H9" }
    ]
    /** Calculator result. */
    readonly property var equals: [
        { d: "M3.5 6 H12.5 M3.5 10 H12.5" }
    ]

    /** Lightning bolt drawn over the battery while charging. */
    readonly property var bolt: [
        { d: "M9 1.5 L4.5 8.75 H7.75 L6.75 14.5 L11.5 7 H8.25 Z", fill: true }
    ]
}
