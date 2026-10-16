import QtQuick
import "../core"

/**
 * Apple's segmented control in liquid glass: a quiet track with the options'
 * labels, and a glass knob over the selected one. While the knob moves it
 * lifts into a clear lens that shows the control's "selected" look through
 * it (solid track, full-weight labels), the way Apple's knob does.
 *
 * `options` are the labels; `selected` is the index; a click emits
 * `activated(index)` and the owner sets `selected` from the real state.
 */
Item {
    id: root

    property var options: []
    property int selected: 0
    property Item backdrop: null
    signal activated(int index)

    implicitWidth: Math.max(1, options.length) * 96
    implicitHeight: 28

    readonly property real segment: width / Math.max(1, options.length)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Tokens.quaternaryLabel
    }

    Row {
        anchors.fill: parent
        Repeater {
            model: root.options
            delegate: Item {
                required property string modelData
                required property int index
                width: root.segment
                height: root.height
                Text {
                    anchors.centerIn: parent
                    text: modelData
                    color: Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.callout.size
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.activated(index)
                }
            }
        }
    }

    // The control as it looks selected, only seen through the lifted knob.
    Item {
        id: selectedLook
        anchors.fill: parent
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Tokens.solidFill
        }
        Row {
            anchors.fill: parent
            Repeater {
                model: root.options
                delegate: Item {
                    required property string modelData
                    width: root.segment
                    height: root.height
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: Tokens.label
                        font.family: Tokens.family
                        font.pixelSize: Tokens.type.callout.size
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }

    SpringValue {
        id: knobX
        to: root.selected * root.segment
        preset: Motion.snappy
        epsilon: 0.05
    }

    Glass {
        x: knobX.value + 2
        y: 2
        width: root.segment - 4
        height: root.height - 4
        radius: height / 2
        backdrop: root.backdrop
        refracts: selectedLook
        hideRefracted: true
        material: Tokens.glass.knob
        liftedMaterial: Tokens.glass.lens
        held: !knobX.settled
        pressScale: 1.18
        shadow: false
        track: [x, root.width]

        Text {
            anchors.centerIn: parent
            text: root.options[root.selected] ?? ""
            color: Tokens.label
            opacity: knobX.settled ? 1 : 0
            font.family: Tokens.family
            font.pixelSize: Tokens.type.callout.size
            font.weight: Font.Bold
        }
    }
}
