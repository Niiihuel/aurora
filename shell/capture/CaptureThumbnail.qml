import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../core"
import "../components"
import "../services"

/**
 * The floating thumbnail after a screenshot or recording, as on macOS: it
 * slides in at the bottom-right corner of the screen it was taken on, stays
 * about five seconds (longer while the pointer is on it), and slides back
 * out. Click it to open the file; swipe it to the right to put it away now.
 * A recording carries a play badge; a screenshot sent to the clipboard just
 * shows what was copied.
 */
PanelWindow {
    id: root

    property string file: ""
    property string thumb: ""
    property string kind: ""
    property bool shown: false

    Connections {
        target: Capture
        function onFinished(file, thumb, kind) {
            root.file = file;
            root.thumb = thumb;
            root.kind = kind;
            root.screen = Capture.screen;
            touch.dx = 0;
            root.shown = true;
            stay.restart();
        }
    }

    Timer {
        id: stay
        interval: 5000
        onTriggered: if (!touch.containsMouse) root.shown = false; else restart()
    }

    SpringValue {
        id: openness
        to: root.shown ? 1 : 0
        preset: root.shown ? Motion.smooth : Motion.dismiss
    }

    visible: shown || !openness.settled
    anchors { bottom: true; right: true }
    margins { bottom: 24; right: 24 }
    implicitWidth: 260
    implicitHeight: card.height + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-capture-thumbnail"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property real ratio: image.status === Image.Ready ? image.implicitWidth / Math.max(1, image.implicitHeight) : 16 / 10

    Item {
        id: drag
        width: parent.width
        height: parent.height
        // Off to the right while closed; follows the finger while swiped.
        x: (1 - openness.value) * (root.width + 24) + Math.max(0, touch.dx)

        Item {
            id: card
            readonly property real maxW: 236
            readonly property real maxH: 160
            width: root.ratio >= maxW / maxH ? maxW : maxH * root.ratio
            height: width / root.ratio
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 12
            anchors.bottomMargin: 12

            RectangularShadow {
                anchors.fill: parent
                radius: 10
                blur: 24
                offset: Qt.vector2d(0, 6)
                color: Qt.rgba(0, 0, 0, 0.35)
            }

            ClippingRectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                Image {
                    id: image
                    anchors.fill: parent
                    source: root.thumb ? "file://" + root.thumb : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize: Qt.size(472, 320)
                }
            }
            Rectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.35)
            }

            // A recording: the play badge.
            Rectangle {
                visible: root.kind === "recording"
                anchors.centerIn: parent
                width: 40
                height: 40
                radius: 20
                color: Qt.rgba(0, 0, 0, 0.45)
                Icon {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 1
                    glyph: Glyphs.play
                    size: 18
                    color: "white"
                }
            }
        }
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        hoverEnabled: true
        property real startX: 0
        property real dx: 0
        onPressed: mouse => {
            startX = mouse.x;
            dx = 0;
        }
        onPositionChanged: mouse => {
            if (pressed)
                dx = mouse.x - startX;
        }
        onReleased: {
            // A swipe leaves it where the finger let go and it slides on out.
            if (dx > 60) {
                root.shown = false;
                return;
            }
            if (dx < 4) {
                root.shown = false;
                Capture.openFile(root.file || root.thumb);
            }
            dx = 0;
        }
    }
}
