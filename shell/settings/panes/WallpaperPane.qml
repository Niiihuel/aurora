import QtQuick
import Quickshell.Widgets
import Quickshell
import "../../core"
import "../../services"
import ".."

/** Wallpaper: the current one large, and every wallpaper in ~/wallpapers to pick. */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.xl

    readonly property string current: Wallpaper.pathFor(Quickshell.screens[0]?.name ?? "")

    Component.onCompleted: Wallpaper.rescan()

    ClippingRectangle {
        width: Math.min(parent.width, 420)
        height: width * 10 / 16
        radius: 14
        color: Tokens.toggleOff
        Image {
            anchors.fill: parent
            source: root.current.length ? "file://" + root.current : ""
            sourceSize: Qt.size(840, 525)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    SettingsGroup {
        title: I18n.tr("settings.wallpaper.yours")
        info: I18n.tr("settings.wallpaper.note")

        Flow {
            width: parent.width
            padding: Tokens.space.l
            spacing: Tokens.space.m

            Repeater {
                model: Wallpaper.files
                delegate: Item {
                    required property string modelData
                    readonly property bool on: modelData === root.current
                    width: 150
                    height: 94
                    ClippingRectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        radius: 9
                        color: Tokens.toggleOff
                        Image {
                            anchors.fill: parent
                            source: "file://" + modelData
                            sourceSize: Qt.size(300, 188)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: 12
                        color: "transparent"
                        border.width: parent.on ? 3 : 0
                        border.color: Tokens.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Wallpaper.apply(modelData, 0.5, 0.5)
                    }
                }
            }
        }
    }
}
