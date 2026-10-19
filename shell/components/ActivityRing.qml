import QtQuick
import QtQuick.Shapes
import "../core"

/**
 * A load as a ring for the menu bar (the activity extra): a faint track, the
 * filled part clockwise from the top, and the value in percent inside it, in
 * the bar's ink like a template icon. Values jump without animating: they
 * change every 2 s, and an animation each time would keep the bar drawing.
 */
Item {
    id: root

    /** 0–1. */
    property real value: 0
    property color color: Tokens.label
    property real stroke: 2

    implicitWidth: 18
    implicitHeight: 18

    readonly property real radius: (width - stroke) / 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: root.stroke
            strokeColor: Qt.alpha(root.color, 0.22)
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: 0
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeWidth: root.stroke
            // An empty sweep would still draw its round cap as a dot.
            strokeColor: root.value > 0.005 ? root.color : "transparent"
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.radius
                radiusY: root.radius
                startAngle: -90
                sweepAngle: 360 * Math.min(1, root.value)
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: Math.round(Math.min(1, root.value) * 100)
        color: root.color
        font.family: Tokens.family
        // "100" has to fit inside the ring too.
        font.pixelSize: text.length > 2 ? 6 : 7.5
        font.weight: Font.DemiBold
        font.features: ({ "tnum": 1 })
    }
}
