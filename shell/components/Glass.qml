import QtQuick
import QtQuick.Effects
import "../core"

/**
 * A liquid glass surface (shaders/glass.frag) filling this item. Give it the
 * window's GlassBackdrop and a material preset from Tokens.glass:
 *
 *     Glass { anchors.fill: parent; backdrop: glassBackdrop; material: Tokens.glass.regular; radius: Tokens.radius.menu }
 *
 * What it refracts:
 * - By default the backdrop's blurred scene (wallpaper + windows), which suits
 *   menus, panels and banners.
 * - With `refracts` set, any item in the same window, sharp and at device
 *   resolution (only the rectangle under the glass is captured). That is how
 *   a control's knob lenses the control's own labels, like Apple's segmented
 *   control. Never point it at an item that contains this Glass: the glass
 *   would render into its own source.
 *
 * Interaction: with `interactive` on, pressing grows it by `pressScale` on the
 * Motion.press spring and lights it up around the press point; `held` does
 * the same from code or the keyboard. While lifted, the material moves toward
 * `liftedMaterial` (e.g. Tokens.glass.lens: clear, magnifying) along the same
 * spring. `clicked` fires on a release inside.
 *
 * mapToItem isn't reactive, so whatever moves this item on screen goes into
 * `track`. The shadow is analytic (RectangularShadow), never a layer effect.
 * Reduce Transparency turns it into an opaque fill; Reduce Motion keeps the
 * highlight but drops the growth.
 */
Item {
    id: root

    property Item backdrop: null
    property Item refracts: null
    property var material: Tokens.glass.regular
    property var liftedMaterial: null
    property real radius: Tokens.radius.menu
    property real power: Tokens.cornerPower
    property bool shadow: true
    /** Whether lifting casts a shadow when `shadow` is off (a small knob's lens doesn't). */
    property bool liftShadow: true
    /**
     * The rim: bent bezel, dispersion and the lit hairline. Turn it off for
     * glass that runs edge to edge (the menu bar), which macOS draws flat.
     */
    property bool edge: true
    /**
     * 0–1: how milky-bright the glass is. Liquid Glass "materializes" instead
     * of fading — a menu first pops out as a luminous white drop and clears
     * as it takes shape; the menu layer drives this while it grows.
     */
    property real bloom: 0
    /**
     * 0–1: how much of the material's veil is present. Liquid Glass
     * materializes by "gradually modulating light bending and lensing": a
     * menu pops out as clear, lensing glass and gains its veil as it forms.
     */
    property real presence: 1
    /**
     * Hide `refracts` from the scene while still lensing it. Lets a control
     * keep an invisible "selected" copy of its labels that only shows
     * through the lifted knob, as Apple's segmented control does.
     */
    property bool hideRefracted: false
    property bool interactive: false
    property bool held: false
    property real pressScale: Motion.pressScale
    property var track: []

    readonly property bool pressed: touch.pressed || held
    readonly property bool opaque: Settings.reduceTransparency || (!refracts && (!backdrop || !backdrop.ready))
    signal clicked()

    // --- Press response ------------------------------------------------------

    SpringValue {
        id: lift
        to: root.pressed && !Motion.reduced ? 1 : 0
        preset: Motion.press
    }
    scale: 1 + (root.pressScale - 1) * lift.value

    property real glow: root.pressed ? 1 : 0
    Behavior on glow {
        NumberAnimation {
            duration: root.pressed ? Motion.glowIn : Motion.glowOut
            easing.type: Motion.easeOut
        }
    }
    property point glowAt: Qt.point(0.5, 0.5)

    MouseArea {
        id: touch
        anchors.fill: parent
        enabled: root.interactive
        onPressed: mouse => root.glowAt = Qt.point(mouse.x / Math.max(1, width), mouse.y / Math.max(1, height))
        onPositionChanged: mouse => {
            if (pressed)
                root.glowAt = Qt.point(mouse.x / Math.max(1, width), mouse.y / Math.max(1, height));
        }
        onClicked: root.clicked()
    }

    /** The material in effect: `material` blended toward `liftedMaterial` by the lift. */
    readonly property var effective: {
        const a = material;
        const b = liftedMaterial;
        const t = Math.max(0, Math.min(1, lift.value));
        if (!b || t <= 0)
            return a;
        const mix = (x, y) => x + (y - x) * t;
        return {
            tint: Qt.rgba(mix(a.tint.r, b.tint.r), mix(a.tint.g, b.tint.g), mix(a.tint.b, b.tint.b), mix(a.tint.a, b.tint.a)),
            refraction: mix(a.refraction, b.refraction),
            dispersion: mix(a.dispersion, b.dispersion),
            saturation: mix(a.saturation, b.saturation),
            dim: mix(a.dim, b.dim),
            magnify: mix(a.magnify ?? 1, b.magnify ?? 1),
            bezel: mix(a.bezel ?? 0, b.bezel ?? 0),
            shade: mix(a.shade ?? 1, b.shade ?? 1)
        };
    }

    // --- Sharp source (refracts) --------------------------------------------

    /**
     * The glass's footprint in `refracts` coordinates, grown by the rim's
     * reach so refraction near the edge has something to sample.
     */
    readonly property rect lensRect: {
        void track;
        void scale;
        void width;
        void height;
        const src = refracts;
        if (!src)
            return Qt.rect(0, 0, 0, 0);
        const reach = Math.max(material.refraction, liftedMaterial ? liftedMaterial.refraction : 0);
        const a = root.mapToItem(src, 0, 0);
        const c = root.mapToItem(src, width, height);
        return Qt.rect(a.x - reach, a.y - reach, (c.x - a.x) + 2 * reach, (c.y - a.y) + 2 * reach);
    }
    readonly property real dpr: backdrop ? backdrop.dpr : 2

    ShaderEffectSource {
        id: lensSource
        visible: false
        hideSource: root.hideRefracted
        live: true
        smooth: true
        sourceItem: root.refracts
        sourceRect: root.lensRect
        textureSize: Qt.size(Math.max(1, Math.ceil(root.lensRect.width * root.dpr)), Math.max(1, Math.ceil(root.lensRect.height * root.dpr)))
    }

    // --- Surface -------------------------------------------------------------

    // Resting shadow when `shadow` is on; a lifted glass casts one anyway,
    // growing with the lift so it reads as rising off the surface.
    RectangularShadow {
        visible: opacity > 0.01
        opacity: root.shadow ? 1 : root.liftShadow ? Math.max(0, Math.min(1, lift.value)) : 0
        anchors.fill: parent
        radius: root.radius
        offset: Qt.vector2d(0, Tokens.shadow.offsetY)
        blur: Tokens.shadow.blur
        color: Tokens.shadow.color
    }

    Rectangle {
        visible: root.opaque
        anchors.fill: parent
        radius: root.radius
        color: root.glow > 0 ? Qt.lighter(Tokens.solidFill, 1 + 0.25 * root.glow) : Tokens.solidFill
        border.width: 1
        border.color: Tokens.separator
    }

    ShaderEffect {
        id: surface
        anchors.fill: parent
        visible: !root.opaque

        property var source: root.refracts ? lensSource : (root.backdrop ? root.backdrop.texture : null)
        // Flat glass (no edge) never samples the sharp scene: don't bind it, or
        // the backdrop keeps rendering a full-screen texture nobody reads.
        property var sharp: root.refracts ? lensSource : !root.edge ? source : (root.backdrop ? root.backdrop.sharpTexture : null)
        property vector2d itemSize: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        // Where this item sits in the source texture, as uv. Both corners are
        // mapped so a press scale (or any parent transform) stays correct.
        property vector4d mapping: {
            void root.track;
            void root.scale;
            void width;
            void height;
            if (root.refracts) {
                const r = root.lensRect;
                if (r.width <= 0 || r.height <= 0)
                    return Qt.vector4d(0, 0, 1, 1);
                const a = root.mapToItem(root.refracts, 0, 0);
                const c = root.mapToItem(root.refracts, width, height);
                return Qt.vector4d((a.x - r.x) / r.width, (a.y - r.y) / r.height, (c.x - a.x) / r.width, (c.y - a.y) / r.height);
            }
            const b = root.backdrop;
            if (!b || b.width <= 0 || b.height <= 0)
                return Qt.vector4d(0, 0, 1, 1);
            const a = surface.mapToItem(b, 0, 0);
            const c = surface.mapToItem(b, width, height);
            return Qt.vector4d(a.x / b.width, a.y / b.height, (c.x - a.x) / b.width, (c.y - a.y) / b.height);
        }
        property vector4d tint: Qt.vector4d(root.effective.tint.r, root.effective.tint.g, root.effective.tint.b, root.effective.tint.a * root.presence)
        property vector4d material: Qt.vector4d(root.effective.refraction, root.effective.dispersion, root.effective.saturation, root.effective.dim)
        property real radius: root.radius
        // A radius of half the short side is a capsule: Apple draws those
        // with true semicircular ends, so the squircle exponent only
        // applies to rounded rectangles.
        property real power: root.radius >= 0.5 * Math.min(width, height) - 0.5 ? 2 : root.power
        property real dpr: root.dpr
        property vector4d glow: Qt.vector4d(root.glowAt.x, root.glowAt.y, root.glow, root.effective.shade ?? 1)
        property vector4d lens: Qt.vector4d(root.effective.magnify ?? 1, root.effective.bezel ?? 0, root.edge ? 1 : 0, root.bloom * 0.12)

        fragmentShader: Qt.resolvedUrl("../shaders/glass.frag.qsb")
    }
}
