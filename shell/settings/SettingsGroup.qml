import QtQuick
import "../core"

/**
 * A group of settings rows, after macOS System Settings: an optional title
 * above, then the rows on one rounded plate, separated by hairlines that
 * start where the row's text starts. Put SettingsRow items (or anything
 * row-sized) inside.
 */
Column {
    id: root

    property string title: ""
    property string footer: ""
    default property alias rows: list.data

    width: parent ? parent.width : 0
    spacing: Tokens.space.s

    Text {
        visible: root.title.length > 0
        x: Tokens.space.m
        text: root.title
        color: Tokens.label
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
        font.weight: Font.DemiBold
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
