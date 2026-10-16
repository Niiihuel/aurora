import QtQuick
import "../core"
import "../components"
import "../services"

/**
 * The editor's width presets on glass: thin, medium, thick (2, 4, 7). The
 * wheel over the screen goes anywhere from 1 to 20.
 */
Item {
    id: root

    property Item frosted: null
    property var track: []

    width: row.implicitWidth + 2 * Tokens.space.s
    height: 44

    MouseArea {
        anchors.fill: parent
    }

    Glass {
        anchors.fill: parent
        refracts: root.frosted
        material: Tokens.glass.regular
        radius: height / 2
        track: [root.track, root.x, root.y]
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: [{ w: 2, d: 6 }, { w: 4, d: 11 }, { w: 7, d: 16 }]
            delegate: Item {
                required property var modelData
                readonly property bool current: Annotate.style.width === modelData.w
                width: 36
                height: 32
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: parent.current ? Tokens.accent : presetHover.containsMouse ? (Tokens.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.05)) : "transparent"
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: modelData.d
                    height: modelData.d
                    radius: modelData.d / 2
                    color: parent.current ? "white" : Tokens.secondaryLabel
                }
                MouseArea {
                    id: presetHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        Annotate.setWidth(modelData.w);
                        Annotate.popover = "";
                    }
                }
            }
        }
    }
}
