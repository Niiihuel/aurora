import QtQuick
import QtQuick.Shapes
import "../core"

/**
 * A load history as a filled area, newest on the right, like Activity
 * Monitor's CPU graph. `values` run 0–1, oldest first; `length` slots span
 * the width, so a history still filling up grows in from the right edge.
 * `lineWidth` adds a line along the top of the area.
 */
Item {
    id: root

    property var values: []
    property int length: values.length
    property color color: Tokens.label
    property real fillOpacity: 1
    property real lineWidth: 0

    readonly property real step: width / Math.max(1, length - 1)
    readonly property real startX: width - (values.length - 1) * step
    readonly property string line: {
        if (values.length < 2)
            return "";
        let d = "";
        for (let i = 0; i < values.length; i++) {
            // Keep the line inside the item so a full load isn't cut off.
            const y = lineWidth / 2 + (height - lineWidth) * (1 - values[i]);
            d += (i ? " L " : "M ") + (startX + i * step).toFixed(2) + " " + y.toFixed(2);
        }
        return d;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Qt.alpha(root.color, root.fillOpacity)
            PathSvg { path: root.line.length ? `${root.line} L ${root.width} ${root.height} L ${root.startX.toFixed(2)} ${root.height} Z` : "" }
        }

        ShapePath {
            strokeWidth: root.lineWidth
            strokeColor: root.lineWidth > 0 ? root.color : "transparent"
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            capStyle: ShapePath.RoundCap
            PathSvg { path: root.line }
        }
    }
}
