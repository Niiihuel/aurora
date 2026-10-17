import QtQuick
import QtQuick.Shapes

/** A monochrome glyph on aurora's 16 pt grid (1.5 pt strokes), like the shell's Icon. */
Item {
    id: root

    property var parts: [] // [{ d: "svg path", fill: bool }]
    property real size: 16
    property color color: "white"

    width: size
    height: size

    Repeater {
        model: root.parts
        delegate: Shape {
            required property var modelData
            width: 16
            height: 16
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { xScale: root.size / 16; yScale: root.size / 16 }
            ShapePath {
                strokeWidth: modelData.fill ? 0 : 1.5
                strokeColor: modelData.fill ? "transparent" : root.color
                fillColor: modelData.fill ? root.color : "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: modelData.d }
            }
        }
    }
}
