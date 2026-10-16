pragma Singleton

import QtQuick
import Quickshell

/**
 * Motion presets. Springs follow SwiftUI's parameterization: `duration` is the
 * perceptual settle time in seconds and `bounce` 0–1 how much it overshoots
 * (0 = critically damped). SpringValue turns a preset into physics; plain
 * NumberAnimations use the eased durations below. Every value lives here so the
 * whole shell moves the same way and can be tuned in one place.
 *
 * Under Reduce Motion, springs jump to their target and components cross-fade
 * over `fade` instead of moving.
 */
Singleton {
    id: root

    readonly property bool reduced: Settings.reduceMotion

    readonly property var smooth: ({ duration: 0.40, bounce: 0.00 })
    readonly property var snappy: ({ duration: 0.30, bounce: 0.15 })
    readonly property var bouncy: ({ duration: 0.45, bounce: 0.30 })
    readonly property var dismiss: ({ duration: 0.20, bounce: 0.00 })
    /**
     * A menu growing out of its menu bar item (and sliding between menus).
     * Fitted to Apple's menu pop (WWDC25 "Meet Liquid Glass", 30 fps): after
     * the drop beat (`menuDrop`), the glass stretches to full size by
     * ~210 ms with a visible overshoot and settles by ~430 ms. The phases
     * riding on top (bloom, shape, content focus) are timed by `menuPhases`.
     */
    readonly property var menuOpen: ({ duration: 0.26, bounce: 0.30 })
    /**
     * The first beat of a menu pop: the glass leaves the item as a small
     * round drop (Apple's drop stays small for ~80–100 ms before it
     * stretches into the menu). `menuPhases.dropHold` is how long it holds.
     */
    readonly property var menuDrop: ({ duration: 0.16, bounce: 0.0 })
    /**
     * Seconds into a menu's pop when each phase happens, measured from the
     * same footage: a faint light peaks at 0.167 and is gone by 0.367; the
     * shape stays a round drop until 0.20 and is the menu's rounded
     * rectangle by 0.333 (the veil grows with it); content focuses in from
     * a blur 0.233 → 0.40.
     */
    readonly property var menuPhases: ({ dropHold: 0.06, bloomPeak: 0.167, bloomEnd: 0.367, shapeStart: 0.20, shapeEnd: 0.333, focusStart: 0.233, focusEnd: 0.40, total: 0.60 })
    /**
     * Closing, re-fitted frame by frame to the same footage: the menu shrinks
     * evenly into a drop about half its size, nearly there by ~170 ms
     * (`menuClose`, ~36% of the way at 33 ms, ~74% at 100 ms); the content is
     * blurred out by ~100 ms. Then the drop melts into its item as a bump
     * that flattens by ~300 ms (`menuMerge`). `closeHold` is when the drop
     * starts merging.
     */
    readonly property var menuClose: ({ duration: 0.22, bounce: 0.0 })
    readonly property var menuMerge: ({ duration: 0.20, bounce: 0.0 })
    readonly property real menuCloseHold: 0.17

    /**
     * Interactive glass under a press: it grows to `pressScale` with a little
     * overshoot and settles back past 1 on release. Measured frame by frame
     * from Apple's interactive glass example (60 fps): +8.4% peak, +7.3%
     * settled ~200 ms after press; ~170 ms back with a 0.6% undershoot.
     */
    readonly property var press: ({ duration: 0.30, bounce: 0.35 })
    readonly property real pressScale: 1.075
    /** Press highlight: quick to light up, slower to fade. */
    readonly property int glowIn: 120
    readonly property int glowOut: 300

    /** Eased durations in ms for things that aren't springs. */
    readonly property int hover: 120
    readonly property int fade: 150
    readonly property int quick: 200

    readonly property int easeOut: Easing.OutCubic
    readonly property int easeInOut: Easing.InOutCubic
}
