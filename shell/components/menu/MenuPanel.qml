import QtQuick
import "../../core"
import ".."

/**
 * A menu's body: regular glass with 12 pt corners and Apple's shadow, and a
 * column for the rows (MenuItem, MenuSeparator, MenuHeader, MenuSlider…).
 *
 * It owns the highlighted row. Hover sets it; the menu layer forwards the
 * keyboard here (`move`, `activate`), which walks the visible, enabled rows in
 * on-screen order, so rows built by Repeaters navigate correctly too.
 */
Item {
    id: root

    property Item backdrop: null
    /**
     * Draw the panel's own glass. The menu layer turns this off and draws
     * one glass that morphs out of the menu bar item instead.
     */
    property bool chrome: true
    property real panelWidth: Tokens.menu.minWidth
    default property alias content: column.data
    /** Window-space geometry the glass depends on (animations), for re-mapping. */
    property var track: []

    readonly property bool isMenuPanel: true
    property Item highlighted: null

    /**
     * Menus size to their content like macOS: the widest row decides, never
     * narrower than `panelWidth` nor wider than the token maximum (rows
     * elide past that).
     */
    readonly property real contentWidth: {
        let widest = 0;
        for (const child of column.children)
            if (child.visible)
                widest = Math.max(widest, child.implicitWidth || 0);
        return widest + 2 * Tokens.menu.padding;
    }
    implicitWidth: Math.min(Tokens.menu.maxWidth, Math.max(panelWidth, contentWidth))
    implicitHeight: column.implicitHeight + 2 * Tokens.menu.padding

    function rows() {
        const found = [];
        const walk = item => {
            for (const child of item.children) {
                if (!child.visible)
                    continue;
                if (child.menuItem === true) {
                    if (child.enabled)
                        found.push(child);
                } else {
                    walk(child);
                }
            }
        };
        walk(column);
        found.sort((a, b) => a.mapToItem(root, 0, 0).y - b.mapToItem(root, 0, 0).y);
        return found;
    }

    function move(step) {
        const list = rows();
        if (!list.length)
            return;
        const i = list.indexOf(highlighted);
        highlighted = i < 0 ? list[step > 0 ? 0 : list.length - 1] : list[(i + step + list.length) % list.length];
    }

    function activate() {
        if (highlighted)
            highlighted.activate();
    }

    Glass {
        visible: root.chrome
        anchors.fill: parent
        backdrop: root.backdrop
        material: Tokens.glass.regular
        radius: Tokens.radius.menu
        track: root.track
    }

    // Leaving the panel clears the hover highlight, as in macOS.
    HoverHandler {
        onHoveredChanged: if (!hovered) root.highlighted = null
    }

    Column {
        id: column
        x: Tokens.menu.padding
        y: Tokens.menu.padding
        width: root.width - 2 * Tokens.menu.padding
    }
}
