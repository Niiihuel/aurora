import QtQuick
import "../../core"
import ".."

/**
 * One command in a menu. Layout, left to right: an optional checkmark column
 * (`reserveMark` keeps it in rows without a check so labels line up), an
 * optional glyph, the label, and on the trailing side `detail` (a shortcut or
 * status) or a chevron when it opens a submenu.
 *
 * Highlighted rows (hover or keyboard) get the accent capsule and white text.
 * Choosing a row plays macOS's selection flash — the highlight blinks off and
 * on once — then emits `triggered` and closes the menu (unless
 * `closeOnTrigger` is off, for rows that change state in place). Disabled rows
 * stay visible and dimmed: people can still learn what the menu offers.
 */
Item {
    id: root

    property string text: ""
    property string detail: ""
    property var glyph: null
    property bool checked: false
    property bool reserveMark: false
    property bool hasSubmenu: false
    property bool closeOnTrigger: true

    signal triggered()

    readonly property bool menuItem: true
    readonly property Item panel: {
        for (let p = parent; p; p = p.parent)
            if (p.isMenuPanel)
                return p;
        return null;
    }
    readonly property bool highlighted: !!panel && panel.highlighted === root && enabled
    property bool blink: false

    width: parent ? parent.width : implicitWidth
    implicitWidth: row.x + label.x + label.implicitWidth + trailing.implicitWidth + 2 * Tokens.menu.itemInset + Tokens.space.xl
    height: Tokens.menu.itemHeight

    function activate() {
        if (!enabled || flash.running)
            return;
        flash.start();
    }

    SequentialAnimation {
        id: flash
        PropertyAction { target: root; property: "blink"; value: true }
        PauseAnimation { duration: 60 }
        PropertyAction { target: root; property: "blink"; value: false }
        PauseAnimation { duration: 60 }
        ScriptAction {
            script: {
                root.triggered();
                if (root.closeOnTrigger)
                    Menus.close();
            }
        }
    }

    readonly property color ink: !enabled ? Tokens.tertiaryLabel : (highlighted && !blink ? "white" : Tokens.label)

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius.menuItem
        color: Tokens.accent
        visible: root.highlighted && !root.blink
    }

    Row {
        id: row
        x: Tokens.menu.itemInset - (root.reserveMark || root.checked ? 4 : 0)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.space.s

        Item {
            visible: root.reserveMark || root.checked
            width: 14; height: 14
            anchors.verticalCenter: parent.verticalCenter
            Icon {
                visible: root.checked
                anchors.centerIn: parent
                size: 13
                stroke: 1.75
                glyph: Glyphs.checkmark
                color: root.ink
            }
        }

        Icon {
            visible: !!root.glyph
            anchors.verticalCenter: parent.verticalCenter
            glyph: root.glyph ?? []
            size: 15
            color: root.ink
            dimColor: Qt.alpha(root.ink, 0.35)
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.ink
            font.family: Tokens.family
            font.pixelSize: Tokens.type.body.size
            elide: Text.ElideRight
            // Room left once the leading columns and the trailing side are placed.
            width: Math.min(implicitWidth, root.width - row.x - (label.x) - trailing.width - 2 * Tokens.menu.itemInset)
        }
    }

    Item {
        id: trailing
        anchors.right: parent.right
        anchors.rightMargin: Tokens.menu.itemInset
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.hasSubmenu ? 12 : detailText.implicitWidth
        height: parent.height

        Text {
            id: detailText
            visible: !root.hasSubmenu && root.detail.length > 0
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: root.detail
            color: root.highlighted && !root.blink ? Qt.rgba(1, 1, 1, 0.8) : Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.body.size
        }

        Icon {
            visible: root.hasSubmenu
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            size: 12
            glyph: Glyphs.chevron
            color: root.ink
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: if (root.panel) root.panel.highlighted = root
        onClicked: root.activate()
    }
}
