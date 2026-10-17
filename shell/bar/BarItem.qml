import QtQuick
import "../core"

/**
 * One clickable slot in the menu bar: padding, the selection capsule, and its
 * menu. Put the visible content (Icon, Text, BatteryIcon) inside as children;
 * they are centered and laid out in a row.
 *
 * Like macOS there is no hover effect at rest — the bar is hovered constantly
 * and motion there would be noise. A click opens the slot's `menu` (or closes
 * it if it's the open one); while any menu of this bar is open, simply moving
 * onto the slot switches to its menu (tracking). The capsule shows while
 * pressed and while the slot's menu is open.
 */
Item {
    id: root

    default property alias content: row.data
    /** Id of the menu this slot opens (see bar/MenuLayer); empty for none. */
    property string menu: ""
    property string screenName: ""
    /**
     * Another app's extra: a click runs `clicked` (the app's own action) and
     * the menu opens on a right click instead.
     */
    property bool menuOnSecondary: false
    property real padding: Tokens.bar.itemPadding

    readonly property bool open: menu.length > 0 && Menus.active === menu && Menus.screen === screenName
    readonly property bool active: open || touch.pressed

    signal clicked()
    signal middleClicked()

    implicitWidth: row.implicitWidth + 2 * padding
    implicitHeight: Tokens.bar.height

    function anchor() {
        return root.mapToItem(null, 0, 0).x;
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        radius: height / 2
        color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.10)
        opacity: root.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.hover; easing.type: Motion.easeOut } }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.space.xs
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered && root.menu.length)
                Menus.track(root.menu, root.screenName, root.anchor(), root.width);
        }
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            // A right click opens any slot's menu, as on macOS.
            const opens = mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && !root.menuOnSecondary);
            if (root.menu.length && opens)
                Menus.toggle(root.menu, root.screenName, root.anchor(), root.width);
            if (mouse.button === Qt.LeftButton)
                root.clicked();
            else if (mouse.button === Qt.MiddleButton)
                root.middleClicked();
        }
    }
}
