import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../components"
import "../services"

/**
 * Notification banners, after macOS: glass cards stacked under the menu bar
 * on the right of the focused screen, newest on top. A banner slides in from
 * the screen's edge on the smooth spring, stays its time (the timer waits
 * while the pointer is on it), and slides back out; dragging it to the right
 * dismisses it. Clicking runs its default action.
 *
 * The window is exactly as big as the stack (plus a margin for the close
 * button on the corner), so it never takes clicks meant for what's around.
 */
PanelWindow {
    id: root

    readonly property real margin: 10

    screen: {
        const focused = Hyprland.focusedMonitor;
        for (const s of Quickshell.screens)
            if (focused && s.name === focused.name)
                return s;
        return Quickshell.screens[0];
    }

    visible: Notifications.banners.length > 0
    anchors { top: true; right: true }
    margins.top: Tokens.bar.height + Tokens.space.xs
    margins.right: Tokens.space.xs
    implicitWidth: 344 + 2 * margin
    implicitHeight: Math.max(1, stack.height + 2 * margin)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-banners"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    /** Ticks the cards' ages. */
    property real now: Date.now()
    Timer {
        interval: 30000
        running: root.visible
        repeat: true
        onTriggered: root.now = Date.now()
    }

    GlassBackdrop {
        id: bannerBackdrop
        screen: root.screen
        origin: Qt.point(root.screen.width - root.implicitWidth - Tokens.space.xs, Tokens.bar.height + Tokens.space.xs)
        region: Qt.rect(origin.x + root.margin, origin.y + root.margin, 344, stack.height)
    }

    Column {
        id: stack
        x: root.margin
        y: root.margin
        width: 344
        spacing: Tokens.space.m

        move: Transition {
            NumberAnimation { properties: "y"; duration: Motion.quick; easing.type: Motion.easeOut }
        }

        Repeater {
            // A ScriptModel diffs by object: a banner arriving or leaving
            // doesn't rebuild (and re-slide) the others.
            model: ScriptModel { values: Notifications.banners }
            delegate: Item {
                id: banner
                required property var modelData
                width: 344
                height: card.height

                /** Slide: 0 at rest, the card's width + margin when out at the edge. */
                SpringValue {
                    id: slide
                    to: 0
                    preset: banner.leaving ? Motion.dismiss : Motion.smooth
                    epsilon: 0.5
                    onSettledChanged: if (settled && banner.leaving) Notifications.hideBanner(banner.modelData)
                }
                property bool leaving: false
                property real dragX: 0
                function leave() {
                    leaving = true;
                    slide.to = banner.width + root.margin * 2;
                }
                Component.onCompleted: slide.snap(Motion.reduced ? 0 : banner.width + root.margin * 2)

                Timer {
                    readonly property real seconds: Notifications.bannerSeconds(banner.modelData)
                    interval: seconds * 1000
                    running: seconds > 0 && !card.hovered && !drag.active && !banner.leaving
                    onTriggered: banner.leave()
                }

                NotificationCard {
                    id: card
                    x: slide.value + banner.dragX
                    notification: banner.modelData
                    backdrop: bannerBackdrop
                    now: root.now
                    track: [x, banner.y]
                    opacity: 1 - Math.min(1, banner.dragX / 300)
                }

                DragHandler {
                    id: drag
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onTranslationChanged: banner.dragX = Math.max(0, translation.x)
                    onActiveChanged: {
                        if (active)
                            return;
                        if (banner.dragX > 90) {
                            slide.snap(banner.dragX);
                            banner.dragX = 0;
                            banner.leave();
                            Notifications.dismiss(banner.modelData);
                        } else {
                            banner.dragX = 0;
                        }
                    }
                }
            }
        }
    }
}
