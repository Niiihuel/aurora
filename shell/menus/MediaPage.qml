import QtQuick
import Quickshell.Widgets
import "../core"
import "../components"
import "../components/menu"
import "../components/controlcenter"
import "../services"

/**
 * Now Playing, expanded from Control Center's module, after macOS: the
 * artwork, title, artist and app, a scrubber with elapsed and remaining time
 * (drag to seek when the player allows it), and the transport controls.
 */
MenuPanel {
    id: root

    panelWidth: 300

    Item {
        width: parent.width
        height: 80

        ClippingRectangle {
            id: art
            x: Tokens.menu.itemInset - 4
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            height: 64
            radius: 10
            color: Tokens.toggleOff

            Image {
                anchors.fill: parent
                source: MediaStatus.art
                sourceSize: Qt.size(128, 128)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: Tokens.space.l
            anchors.right: parent.right
            anchors.rightMargin: Tokens.menu.itemInset
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: MediaStatus.present ? MediaStatus.title : I18n.tr("controlCenter.notPlaying")
                color: Tokens.label
                font.family: Tokens.family
                font.pixelSize: Tokens.type.body.size
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: MediaStatus.artist
                color: Tokens.secondaryLabel
                font.family: Tokens.family
                font.pixelSize: Tokens.type.callout.size
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: text.length > 0
                text: MediaStatus.app
                color: Tokens.tertiaryLabel
                font.family: Tokens.family
                font.pixelSize: Tokens.type.subheadline.size
                elide: Text.ElideRight
            }
        }
    }

    Item {
        width: parent.width
        height: 40
        visible: MediaStatus.length > 0

        CCSlider {
            backdrop: root.backdrop
            x: Tokens.menu.itemInset
            width: parent.width - 2 * Tokens.menu.itemInset
            y: 2
            value: MediaStatus.length > 0 ? MediaStatus.position / MediaStatus.length : 0
            enabled: MediaStatus.canSeek
            onMoved: v => MediaStatus.seek(v)
        }
        Text {
            x: Tokens.menu.itemInset
            anchors.bottom: parent.bottom
            text: MediaStatus.time(MediaStatus.position)
            color: Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.caption1.size
            font.features: ({ "tnum": 1 })
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: Tokens.menu.itemInset
            anchors.bottom: parent.bottom
            text: "-" + MediaStatus.time(MediaStatus.length - MediaStatus.position)
            color: Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.caption1.size
            font.features: ({ "tnum": 1 })
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        height: 48
        spacing: Tokens.space.huge
        opacity: MediaStatus.present ? 1 : 0.4

        Repeater {
            model: [
                { glyph: Glyphs.backward, size: 20, act: () => MediaStatus.previous() },
                { glyph: MediaStatus.playing ? Glyphs.pause : Glyphs.play, size: 26, act: () => MediaStatus.toggle() },
                { glyph: Glyphs.forward, size: 20, act: () => MediaStatus.next() }
            ]
            delegate: Item {
                required property var modelData
                width: 36
                height: 48
                Icon {
                    anchors.centerIn: parent
                    glyph: modelData.glyph
                    size: modelData.size
                    scale: press.pressed ? 0.88 : 1
                    opacity: press.pressed ? 0.6 : 1
                }
                MouseArea {
                    id: press
                    anchors.fill: parent
                    onClicked: modelData.act()
                }
            }
        }
    }
}
