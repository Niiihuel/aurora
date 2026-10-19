import QtQuick
import "../core"
import "../components"

/**
 * A group of settings rows, after macOS System Settings: an optional title
 * above, then the rows on one rounded plate, separated by hairlines that
 * start where the row's text starts. Put SettingsRow items (or anything
 * row-sized) inside. `info` puts an ⓘ next to the title with more about the
 * group; `footer` is for what must stay in sight.
 */
Column {
    id: root

    property string title: ""
    property string footer: ""
    property string info: ""
    default property alias rows: list.data

    width: parent ? parent.width : 0
    spacing: Tokens.space.s

    Row {
        visible: root.title.length > 0
        x: Tokens.space.m
        spacing: Tokens.space.s
        Text {
            text: root.title
            color: Tokens.label
            font.family: Tokens.family
            font.pixelSize: Tokens.type.body.size
            font.weight: Font.DemiBold
        }
        InfoButton {
            visible: root.info.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.info
        }
    }

    Rectangle {
        width: parent.width
        height: list.height
        radius: 12
        color: Tokens.groupFill
        border.width: Tokens.dark ? 0 : 1
        border.color: Tokens.separator

        Column {
            id: list
            width: parent.width
        }
    }

    Text {
        visible: root.footer.length > 0
        x: Tokens.space.m
        width: parent.width - 2 * Tokens.space.m
        text: root.footer
        color: Tokens.secondaryLabel
        font.family: Tokens.family
        font.pixelSize: Tokens.type.subheadline.size
        wrapMode: Text.Wrap
    }
}
