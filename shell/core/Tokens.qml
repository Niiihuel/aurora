pragma Singleton

import QtQuick
import Quickshell

/**
 * aurora's design tokens: type, color, spacing, radii, glass and shadow. The
 * values and their reasoning live in the aurora-design skill
 * (references/tokens.md); keep the two in sync. Components read sizes, colors
 * and materials from here and never hard-code a value a token covers.
 *
 * Units are logical pixels, which Hyprland treats as points.
 */
Singleton {
    id: root

    readonly property bool dark: Settings.dark

    // --- Type --------------------------------------------------------------

    readonly property string family: "Inter"
    readonly property string displayFamily: "Inter Display"

    /**
     * macOS built-in text styles: size and line height in points, regular and
     * emphasized weights. Apply with Tokens.font(style) / Tokens.lineHeight.
     */
    readonly property var type: ({
        largeTitle:  { size: 26, line: 32, weight: Font.Normal,   emphasized: Font.Bold },
        title1:      { size: 22, line: 26, weight: Font.Normal,   emphasized: Font.Bold },
        title2:      { size: 17, line: 22, weight: Font.Normal,   emphasized: Font.Bold },
        title3:      { size: 15, line: 20, weight: Font.Normal,   emphasized: Font.DemiBold },
        headline:    { size: 13, line: 16, weight: Font.Bold,     emphasized: Font.Black },
        body:        { size: 13, line: 16, weight: Font.Normal,   emphasized: Font.DemiBold },
        callout:     { size: 12, line: 15, weight: Font.Normal,   emphasized: Font.DemiBold },
        subheadline: { size: 11, line: 14, weight: Font.Normal,   emphasized: Font.DemiBold },
        footnote:    { size: 10, line: 13, weight: Font.Normal,   emphasized: Font.DemiBold },
        caption1:    { size: 10, line: 13, weight: Font.Normal,   emphasized: Font.Medium },
        caption2:    { size: 10, line: 13, weight: Font.Medium,   emphasized: Font.DemiBold }
    })

    // --- Color (semantic) --------------------------------------------------

    function _ink(alpha) {
        return dark ? Qt.rgba(1, 1, 1, alpha) : Qt.rgba(0, 0, 0, alpha);
    }

    readonly property color label: _ink(0.85)
    readonly property color secondaryLabel: _ink(dark ? 0.55 : 0.50)
    readonly property color tertiaryLabel: _ink(dark ? 0.25 : 0.26)
    readonly property color quaternaryLabel: _ink(0.10)
    readonly property color separator: _ink(0.10)

    /** A fixed choice in Settings, else the wallpaper's hue, else the system blue. */
    readonly property color accent: Settings.accent.length ? Settings.accent
        : WallpaperAccent.tone ?? (dark ? "#0A84FF" : "#007AFF")
    readonly property color destructive: dark ? "#FF453A" : "#FF3B30"
    readonly property color success: dark ? "#30D158" : "#34C759"
    readonly property color warning: dark ? "#FFD60A" : "#FFCC00"

    /** Opaque stand-in for glass under Reduce Transparency. */
    readonly property color solidFill: dark ? "#1C1C1E" : "#F2F2F7"

    // --- Spacing and radii -------------------------------------------------

    readonly property var space: ({ xxs: 2, xs: 4, s: 6, m: 8, l: 12, xl: 16, xxl: 20, xxxl: 24, huge: 32 })

    readonly property var radius: ({
        menu: 12,
        menuItem: 6,
        panel: 24,
        tile: 16,
        banner: 20,
        dialog: 22
    })

    /** Squircle exponent for corners: 2 is a circle, ~4 is Apple's continuous curve. */
    readonly property real cornerPower: 4

    /** Radius of a shape nested `inset` points inside one of radius `outer`. */
    function concentric(outer, inset) {
        return Math.max(0, outer - inset);
    }

    readonly property var bar: ({ height: 24, itemPadding: 8, icon: 16, gap: 6 })
    /**
     * Menus: inner padding, row height, the gap below the bar, the margin
     * kept from the screen edge, and the column a checkmark/icon takes.
     */
    readonly property var menu: ({ padding: 6, itemHeight: 24, separatorInset: 10, gap: 4, edgeMargin: 6, minWidth: 240, maxWidth: 360, markColumn: 22, itemInset: 10 })

    // --- Glass -------------------------------------------------------------

    /**
     * Material presets for Glass. tint is a straight color whose alpha is the
     * veil strength; blur is the backdrop's Gaussian sigma in points;
     * refraction and dispersion are the rim's displacement in points.
     */
    readonly property var glass: ({
        regular: {
            tint: dark ? Qt.rgba(0.149, 0.149, 0.157, 0.60) : Qt.rgba(0.961, 0.961, 0.969, 0.55),
            blur: 8, refraction: 32, dispersion: 0.5, saturation: 2.2, dim: 0
        },
        regularSmall: {
            tint: dark ? Qt.rgba(0.149, 0.149, 0.157, 0.60) : Qt.rgba(0.961, 0.961, 0.969, 0.55),
            blur: 8, refraction: 14, dispersion: 0.5, saturation: 2.2, dim: 0
        },
        clear: {
            tint: dark ? Qt.rgba(0.149, 0.149, 0.157, 0.20) : Qt.rgba(0.961, 0.961, 0.969, 0.18),
            blur: 4, refraction: 32, dispersion: 0.6, saturation: 1.6, dim: 0
        },
        /**
         * A control knob at rest (segmented control, slider thumb). It
         * refracts the control's hidden "selected" copy (solid track +
         * full-weight label), so it reads as a solid pill with its label;
         * it lifts into `lens` while it moves.
         */
        knob: {
            tint: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.50),
            blur: 0, refraction: 4, dispersion: 0, saturation: 1, dim: 0, magnify: 1, bezel: 6
        },
        /** A slider's thumb at rest: a solid white capsule in both appearances. */
        sliderKnob: {
            tint: Qt.rgba(1, 1, 1, 0.96),
            blur: 0, refraction: 4, dispersion: 0, saturation: 1, dim: 0, magnify: 1, bezel: 5
        },
        /**
         * A lifted control knob (segmented control, slider) while it moves:
         * nearly clear, sharp (no blur: it refracts the control's own
         * labels), magnifying the middle ~1.1x, as in Apple's videos.
         */
        lens: {
            tint: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.30),
            blur: 0, refraction: 10, dispersion: 0.8, saturation: 1.2, dim: 0, magnify: 1.1, bezel: 7
        },
        bar: {
            tint: dark ? Qt.rgba(0.149, 0.149, 0.157, 0.60 * Settings.barTint) : Qt.rgba(0.961, 0.961, 0.969, 0.55 * Settings.barTint),
            blur: 8, refraction: 14, dispersion: 0.4, saturation: 2.0, dim: 0
        }
    })

    /** Apple's glass shadow: 0 10 40, black 20% dark / 10% light. */
    readonly property var shadow: ({ offsetY: 10, blur: 40, color: Qt.rgba(0, 0, 0, dark ? 0.20 : 0.10) })
}
