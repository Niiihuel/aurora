import QtQuick
import "../core"
import "../components"

/**
 * One row of settings: an optional icon, the title and an optional subtitle
 * on the leading side, the control (a switch, a slider, a choice, a value)
 * on the trailing side. Rows after the first in their group draw the hairline
 * above them, inset to the text, as macOS does. `clicked` fires for rows
 * that are actions as a whole (`interactive`).
 */
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property var glyph: null
    /** An image instead of a glyph tile (an app's own icon). */
    property string image: ""
    property color glyphTint: Tokens.accent
    property bool interactive: false
    /** In progress: macOS's spinner, where the icon goes (or at the end if the row has one). */
    property bool busy: false
    default property alias trailing: control.data
    signal clicked()

    width: parent ? parent.width : 0
    height: subtitle.length ? 52 : 40

    /** First visible row of its group: no hairline above it. */
    readonly property bool first: {
        if (!parent)
            return true;
        for (const child of parent.children)
            if (child.visible)
                return child === root;
        return true;
    }

    Rectangle {
        visible: !root.first
        x: labels.x
        width: parent.width - labels.x
        height: 1
        color: Tokens.separator
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.04)
        visible: root.interactive && touch.containsMouse
    }

    Image {
        visible: root.image.length > 0 && status === Image.Ready
        x: Tokens.space.l
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 26
        sourceSize: Qt.size(52, 52)
        source: root.image
        asynchronous: true
    }

    Rectangle {
        id: tile
        visible: !!root.glyph
        x: Tokens.space.l
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 24
        radius: 6
        color: root.glyphTint
        Icon {
            anchors.centerIn: parent
            glyph: root.glyph ?? []
            size: 14
            color: "white"
            dimColor: Qt.rgba(1, 1, 1, 0.45)
        }
    }

    Column {
        id: labels
        x: root.glyph || root.image.length || root.busy ? Tokens.space.l + 24 + Tokens.space.m : Tokens.space.l
        anchors.verticalCenter: parent.verticalCenter
        width: control.x - x - Tokens.space.m
        Text {
            width: parent.width
            text: root.title
            color: Tokens.label
            font.family: Tokens.family
            font.pixelSize: Tokens.type.body.size
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: root.subtitle.length > 0
            text: root.subtitle
            color: Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.subheadline.size
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: root.interactive
        onClicked: root.clicked()
    }

    ActivityIndicator {
        visible: root.busy
        x: root.glyph || root.image.length ? control.x - width - Tokens.space.m : Tokens.space.l + 5
        anchors.verticalCenter: parent.verticalCenter
        size: 14
    }

    Row {
        id: control
        anchors.right: parent.right
        anchors.rightMargin: Tokens.space.l
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.space.m
    }
}
