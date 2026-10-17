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

    /**
     * Control Center, after macOS Tahoe: a panel of regular glass holding a
     * 4-column grid of modules, each a lighter platter of glass
     * (`glass.module`) `padding` in from the panel's edge. A unit is one
     * column wide and as tall; 1×1 modules are circles, 2×1 capsules, larger
     * ones rounded rectangles of `radius` (the panel's radius is `radius` +
     * `padding`, concentric). `toggle` is the round button inside a capsule.
     */
    readonly property var controlCenter: ({ width: 292, padding: 10, gap: 10, radius: 16, toggle: 36 })
    /** Notification Center: the column's width and the panel's padding (cards of `radius.tile`; the panel's radius is tile + padding). */
    readonly property var notificationCenter: ({ width: 344, padding: 10 })
    readonly property color platter: dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.45)
    readonly property color platterHighlight: dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.70)
    /** Settings: a group of rows on the window's background. */
    readonly property color groupFill: dark ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(1, 1, 1, 0.85)
    /** Settings: the window's own background, behind the content. */
    readonly property color windowFill: dark ? "#1E1E20" : "#ECECEF"

    /** A neutral (system gray) tile, e.g. a settings icon that has no colour of its own. */
    readonly property color neutral: dark ? "#636366" : "#8E8E93"
    /** The window controls: close, minimize, zoom (macOS's fixed colours). */
    readonly property var windowControls: ({ close: "#FF5F57", minimize: "#FEBC2E", zoom: "#28C840" })

    /** A round toggle that is off. */
    readonly property color toggleOff: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)

    // --- Glass -------------------------------------------------------------

    /**
     * Material presets for Glass. tint is a straight color whose alpha is the
     * veil strength; blur is the backdrop's Gaussian sigma in points;
     * refraction and dispersion are the rim's displacement in points.
     */
    readonly property var glass: ({
        regular: {
            tint: dark ? Qt.rgba(0.149, 0.149, 0.157, 0.48) : Qt.rgba(0.961, 0.961, 0.969, 0.45),
            blur: 8, refraction: 32, dispersion: 0.5, saturation: 2.2, dim: 0
        },
        /**
         * A window's sidebar (Settings): still live glass, but a dense veil
         * with muted color and a heavy blur, so what's behind reads as soft
         * blotches and never competes with the list — as in Apple's
         * Liquid Glass adoption guide (the sidebar over a photo measures a
         * ~60% grey veil, color nearly gone).
         */
        sidebar: {
            tint: dark ? Qt.rgba(0.17, 0.17, 0.18, 0.74) : Qt.rgba(0.93, 0.93, 0.94, 0.72),
            blur: 20, refraction: 24, dispersion: 0.3, saturation: 1.1, dim: 0
        },
        regularSmall: {
            tint: dark ? Qt.rgba(0.149, 0.149, 0.157, 0.48) : Qt.rgba(0.961, 0.961, 0.969, 0.45),
            blur: 8, refraction: 14, dispersion: 0.5, saturation: 2.2, dim: 0
        },
        /**
         * A Control Center module: a lighter platter on the panel's regular
         * glass. It samples the backdrop, not the panel, so its tint is the
         * panel's veil with a light wash on top; its rim lenses the scene
         * over a 12 pt band so each module reads as its own piece.
         */
        module: {
            tint: dark ? Qt.rgba(0.26, 0.26, 0.27, 0.52) : Qt.rgba(0.98, 0.98, 0.985, 0.70),
            blur: 8, refraction: 14, dispersion: 0.5, saturation: 2.2, dim: 0, bezel: 12
        },
        /**
         * A Control Center control that is on: bright white glass (still
         * glass — it refracts at its rim and lets a little through), the
         * glyph drawn in the accent on it.
         */
        toggleOn: {
            tint: Qt.rgba(1, 1, 1, 0.86),
            blur: 8, refraction: 14, dispersion: 0.5, saturation: 1.4, dim: 0, bezel: 10
        },
        /**
         * The lock screen's big clock: frosted glass numerals over the
         * wallpaper (a light veil on the blurred wallpaper, no rim — the
         * outline is the glyphs').
         */
        clock: {
            tint: Qt.rgba(1, 1, 1, 0.62),
            blur: 10, refraction: 0, dispersion: 0, saturation: 1.4, dim: 0
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
            blur: 0, refraction: 10, dispersion: 0.4, saturation: 1.2, dim: 0, magnify: 1.1, bezel: 7
        },
        /**
         * A switch's knob at rest: white with a lit rim and no inner shade
         * (macOS Tahoe's reads ~90% white over the track).
         */
        switchKnob: {
            tint: Qt.rgba(1, 1, 1, 0.94),
            blur: 0, refraction: 3, dispersion: 0, saturation: 1, dim: 0, magnify: 1, bezel: 5, shade: 0
        },
        /**
         * A switch's lifted knob: clearer than `lens`, barely magnifying, with
         * a thin bent rim, so the track shows through it whole — its edges
         * and color — as in WWDC25 "Meet Liquid Glass" (the switch sequence).
         */
        switchLens: {
            tint: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.10),
            blur: 0, refraction: 6, dispersion: 0.5, saturation: 1.3, dim: 0, magnify: 1.04, bezel: 5
        },
        bar: {
            tint: dark ? Qt.rgba(0.149, 0.149, 0.157, 0.60 * Settings.barTint) : Qt.rgba(0.961, 0.961, 0.969, 0.55 * Settings.barTint),
            blur: 8, refraction: 14, dispersion: 0.4, saturation: 2.0, dim: 0
        }
    })

    /** Apple's glass shadow: 0 10 40, black 20% dark / 10% light. */
    readonly property var shadow: ({ offsetY: 10, blur: 40, color: Qt.rgba(0, 0, 0, dark ? 0.20 : 0.10) })
}
