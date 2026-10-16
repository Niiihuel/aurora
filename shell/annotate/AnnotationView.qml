import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell.Widgets
import "../core"
import "geometry.mjs" as G

/**
 * One annotation of the screenshot editor, drawn over the frozen screen:
 * rect and ellipse (outline or filled), line, arrow (filled head), pen,
 * marker (translucent yellow, rounded), step (a numbered disc), text, and the
 * three that read the screenshot under them — blur, pixelate and zoom
 * (magnified in place, framed and shadowed). `frozen` is the screenshot
 * item; effects never see other annotations. Fills its parent (the stage),
 * in the screen's logical points.
 */
Item {
    id: root

    property var a: ({})
    property Item frozen: null
    property int mosaic: Settings.annotateMosaic
    property int blurRadius: Settings.annotateBlur
    property real dpr: 2

    readonly property var b: G.box(a)

    anchors.fill: parent

    Loader {
        anchors.fill: parent
        sourceComponent: {
            switch (root.a.type) {
            case "rect":
            case "ellipse":
            case "line":
            case "arrow":
            case "pen":
                return vector;
            case "marker":
                return marker;
            case "step":
                return step;
            case "text":
                return text;
            case "blur":
                return blur;
            case "pixelate":
                return pixelate;
            case "zoom":
                return zoom;
            default:
                return null;
            }
        }
    }

    Component {
        id: vector
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.a.color
                strokeWidth: root.a.width
                fillColor: root.a.filled ? root.a.color : "transparent"
                capStyle: root.a.type === "rect" ? ShapePath.SquareCap : ShapePath.RoundCap
                joinStyle: root.a.type === "rect" ? ShapePath.MiterJoin : ShapePath.RoundJoin
                PathSvg { path: G.path(root.a) }
            }
            ShapePath {
                strokeColor: root.a.type === "arrow" ? root.a.color : "transparent"
                strokeWidth: root.a.type === "arrow" ? root.a.width : 0
                fillColor: root.a.type === "arrow" ? root.a.color : "transparent"
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: root.a.type === "arrow" ? G.headPath(root.a) : "" }
            }
        }
    }

    Component {
        id: marker
        Item {
            Rectangle {
                x: root.b.x
                y: root.b.y
                width: root.b.width
                height: root.b.height
                radius: Math.min(width, height) * 0.18
                color: Qt.rgba(1, 0.839, 0.039, 0.32)
            }
        }
    }

    Component {
        id: step
        Item {
            Rectangle {
                readonly property real d: G.stepDiameter(root.a.width)
                x: root.a.x1 - d / 2
                y: root.a.y1 - d / 2
                width: d
                height: d
                radius: d / 2
                color: root.a.color
                Text {
                    anchors.centerIn: parent
                    text: root.a.n
                    color: "white"
                    font.family: Tokens.family
                    font.pixelSize: parent.d * 0.55
                    font.weight: Font.Bold
                }
            }
        }
    }

    Component {
        id: text
        Item {
            Text {
                x: root.a.x1
                y: root.a.y1
                text: root.a.text ?? ""
                color: root.a.color
                font.family: Tokens.family
                font.pixelSize: root.a.size ?? G.textSize(root.a.width)
            }
        }
    }

    Component {
        id: blur
        Item {
            Item {
                x: root.b.x
                y: root.b.y
                width: root.b.width
                height: root.b.height
                clip: true
                // A margin around the area, so the blur doesn't darken toward its edges.
                readonly property real m: root.blurRadius
                ShaderEffectSource {
                    id: under
                    x: -parent.m
                    y: -parent.m
                    width: parent.width + 2 * parent.m
                    height: parent.height + 2 * parent.m
                    sourceItem: root.frozen
                    sourceRect: Qt.rect(root.b.x - parent.m, root.b.y - parent.m, width, height)
                    visible: false
                }
                MultiEffect {
                    anchors.fill: under
                    source: under
                    blurEnabled: true
                    blur: 1
                    blurMax: root.blurRadius
                }
            }
        }
    }

    Component {
        id: pixelate
        Item {
            ShaderEffectSource {
                x: root.b.x
                y: root.b.y
                width: root.b.width
                height: root.b.height
                sourceItem: root.frozen
                sourceRect: Qt.rect(root.b.x, root.b.y, root.b.width, root.b.height)
                textureSize: Qt.size(Math.max(1, Math.ceil(root.b.width / root.mosaic)), Math.max(1, Math.ceil(root.b.height / root.mosaic)))
                smooth: false
            }
        }
    }

    Component {
        id: zoom
        Item {
            id: zoomed
            readonly property real factor: root.a.zoom ?? 2
            readonly property real r: Math.min(root.b.width, root.b.height) * 0.08
            RectangularShadow {
                x: root.b.x + 2
                y: root.b.y + 2
                width: root.b.width
                height: root.b.height
                radius: zoomed.r
                blur: 6
                color: Qt.rgba(0, 0, 0, 0.28)
            }
            ClippingRectangle {
                x: root.b.x
                y: root.b.y
                width: root.b.width
                height: root.b.height
                radius: zoomed.r
                color: "transparent"
                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: root.frozen
                    sourceRect: Qt.rect(root.b.x + root.b.width * (1 - 1 / zoomed.factor) / 2,
                        root.b.y + root.b.height * (1 - 1 / zoomed.factor) / 2,
                        root.b.width / zoomed.factor, root.b.height / zoomed.factor)
                    textureSize: Qt.size(Math.ceil(root.b.width * root.dpr), Math.ceil(root.b.height * root.dpr))
                    smooth: true
                }
            }
            Rectangle {
                x: root.b.x
                y: root.b.y
                width: root.b.width
                height: root.b.height
                radius: zoomed.r
                color: "transparent"
                border.width: 2
                border.color: Qt.rgba(1, 1, 1, 0.9)
            }
        }
    }
}
