import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../components"
import "../components/controlcenter"
import "../services"

/**
 * Volume and brightness feedback, after macOS Tahoe: instead of the old
 * centered square, a small wide capsule of liquid glass under the menu bar
 * on the right of the focused screen — the glyph and the level on aurora's
 * slider (it can be dragged while it shows). It materializes on the smooth
 * spring and leaves after a moment without changes, waiting while the pointer
 * is on it.
 *
 * The keys reach aurora as Hyprland global shortcuts (`hl.dsp.global
 * ("aurora:volumeUp")` …), so a press changes the level in-process —
 * PipeWire for volume, the backlight service for brightness — with no
 * helper process per key repeat. Steps are 1/16, as on a Mac. The media keys
 * (play/pause, next, previous) are handled here too, without a HUD.
 */
PanelWindow {
    id: root

    /** "volume" or "brightness". */
    property string kind: "volume"
    property bool shown: false

    readonly property real step: 1 / 16

    function flash(k) {
        kind = k;
        shown = true;
        hideTimer.restart();
    }

    function volume(delta) {
        if (!AudioStatus.ready)
            return;
        const base = AudioStatus.muted ? 0 : AudioStatus.volume;
        // Land on the 1/16 grid, like macOS, whatever the level was.
        AudioStatus.setVolume(Math.round((base + delta) / step) * step);
        flash("volume");
    }

    function brightness(delta) {
        if (!DisplayStatus.hasBacklight)
            return;
        DisplayStatus.setBrightness(Math.round((DisplayStatus.brightness + delta) / step) * step);
        flash("brightness");
    }

    // Find the backlight and its level now, not on the first key press. From
    // then on every change goes through aurora (keys, Control Center), so its
    // own value is the truth; Control Center re-reads it when it opens.
    Component.onCompleted: DisplayStatus.refresh()

    GlobalShortcut { appid: "aurora"; name: "volumeUp"; description: "Raise the volume"; onPressed: root.volume(root.step) }
    GlobalShortcut { appid: "aurora"; name: "volumeDown"; description: "Lower the volume"; onPressed: root.volume(-root.step) }
    GlobalShortcut {
        appid: "aurora"; name: "volumeMute"; description: "Mute or unmute"
        onPressed: {
            AudioStatus.setMuted(!AudioStatus.muted);
            root.flash("volume");
        }
    }
    GlobalShortcut { appid: "aurora"; name: "brightnessUp"; description: "Raise the display brightness"; onPressed: root.brightness(root.step) }
    GlobalShortcut { appid: "aurora"; name: "brightnessDown"; description: "Lower the display brightness"; onPressed: root.brightness(-root.step) }
    GlobalShortcut { appid: "aurora"; name: "mediaToggle"; description: "Play or pause"; onPressed: MediaStatus.toggle() }
    GlobalShortcut { appid: "aurora"; name: "mediaNext"; description: "Next track"; onPressed: MediaStatus.next() }
    GlobalShortcut { appid: "aurora"; name: "mediaPrevious"; description: "Previous track"; onPressed: MediaStatus.previous() }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: {
            if (hover.hovered)
                restart();
            else
                root.shown = false;
        }
    }

    SpringValue {
        id: openness
        to: root.shown ? 1 : 0
        preset: root.shown ? Motion.smooth : Motion.dismiss
    }

    screen: {
        const focused = Hyprland.focusedMonitor;
        for (const s of Quickshell.screens)
            if (focused && s.name === focused.name)
                return s;
        return Quickshell.screens[0];
    }

    readonly property real margin: 10
    visible: shown || !openness.settled
    anchors { top: true; right: true }
    margins.top: Tokens.bar.height + Tokens.space.xs
    margins.right: Tokens.space.xs
    implicitWidth: capsule.width + 2 * margin
    implicitHeight: capsule.height + 2 * margin
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    GlassBackdrop {
        id: osdBackdrop
        screen: root.screen
        origin: Qt.point(root.screen.width - root.implicitWidth - Tokens.space.xs, Tokens.bar.height + Tokens.space.xs)
        region: Qt.rect(origin.x + root.margin, origin.y + root.margin, capsule.width, capsule.height)
    }

    Item {
        id: capsule
        x: root.margin
        y: root.margin
        width: 236
        height: 46
        opacity: openness.value
        scale: 0.9 + 0.1 * openness.value
        transformOrigin: Item.Top

        HoverHandler { id: hover }

        Glass {
            anchors.fill: parent
            backdrop: osdBackdrop
            material: Tokens.glass.regular
            radius: height / 2
            track: [capsule.scale]
        }

        Icon {
            id: glyph
            x: Tokens.space.l + 2
            anchors.verticalCenter: parent.verticalCenter
            size: 18
            glyph: root.kind === "brightness" ? Glyphs.sun : Glyphs.speaker(AudioStatus.waves)
            dimColor: Tokens.tertiaryLabel
        }

        CCSlider {
            anchors.left: glyph.right
            anchors.leftMargin: Tokens.space.s
            anchors.right: parent.right
            anchors.rightMargin: Tokens.space.m
            anchors.verticalCenter: parent.verticalCenter
            backdrop: osdBackdrop
            value: root.kind === "brightness" ? DisplayStatus.brightness : (AudioStatus.muted ? 0 : AudioStatus.volume)
            onMoved: v => {
                if (root.kind === "brightness")
                    DisplayStatus.setBrightness(v);
                else
                    AudioStatus.setVolume(v);
                hideTimer.restart();
            }
        }
    }
}
