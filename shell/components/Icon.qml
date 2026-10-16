import QtQuick
import QtQuick.Shapes
import "../core"

/**
 * Draws a glyph from core/Glyphs at `size` points. Strokes are 1.5 pt on the
 * 16 pt grid and scale with the icon; `color` paints the glyph and `dimColor`
 * its dim parts (levels not reached). One Shape per part, so a glyph that
 * changes (Wi-Fi bars, speaker waves) is rebuilt cleanly. Uses the curve
 * renderer so edges stay crisp at fractional scales.
 */
Item {
    id: root

    property var glyph: []
    property real size: Tokens.bar.icon
    property color color: Tokens.label
    property color dimColor: Tokens.tertiaryLabel
    property real stroke: 1.5

    implicitWidth: size
    implicitHeight: size

    Repeater {
        model: root.glyph
        delegate: Shape {
            required property var modelData
            width: 16
            height: 16
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { xScale: root.size / 16; yScale: root.size / 16 }

            ShapePath {
                strokeWidth: modelData.fill ? 0 : root.stroke
                strokeColor: modelData.fill ? "transparent" : (modelData.dim ? root.dimColor : root.color)
                fillColor: modelData.fill ? (modelData.dim ? root.dimColor : root.color) : "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: modelData.d }
            }
        }
    }
}
