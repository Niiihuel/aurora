import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../core"
import "../components/menu"

/**
 * The menu another app publishes for its menu bar extra (StatusNotifierItem
 * with a DBusMenu), drawn as an aurora menu. A row with a submenu opens it in
 * place under a back row naming it; Esc or that row steps back out.
 */
MenuPanel {
    id: root

    required property string itemId
    readonly property SystemTrayItem item: SystemTray.items.values.find(i => i.id === itemId) ?? null
    /** Submenus opened, innermost last. */
    property var path: []
    readonly property var current: path.length ? path[path.length - 1] : null
    readonly property bool marks: opener.children.values.some(e => e.buttonType !== QsMenuButtonType.None)

    function back() {
        if (!path.length)
            return false;
        path = path.slice(0, -1);
        highlighted = null;
        return true;
    }

    /** DBusMenu labels carry GTK mnemonics: "_" marks the access key, "__" is a literal "_". */
    function label(text) {
        return text.replace(/__|_/g, m => m === "__" ? "_" : "");
    }

    QsMenuOpener {
        id: opener
        menu: root.current ?? (root.item ? root.item.menu : null)
    }

    MenuItem {
        visible: !!root.current
        text: root.current ? root.label(root.current.text) : ""
        glyph: Glyphs.chevronBack
        closeOnTrigger: false
        onTriggered: root.back()
    }

    MenuSeparator { visible: !!root.current }

    Repeater {
        model: opener.children
        delegate: Item {
            id: row
            required property QsMenuEntry modelData
            required property int index
            // Apps leave separators at the ends or doubled; macOS never shows those.
            readonly property bool shown: {
                if (!modelData.isSeparator)
                    return true;
                const all = opener.children.values;
                return index > 0 && index < all.length - 1 && !all[index - 1].isSeparator;
            }
            visible: shown
            width: parent ? parent.width : 0
            implicitWidth: modelData.isSeparator ? 0 : entry.implicitWidth
            height: !shown ? 0 : modelData.isSeparator ? separator.height : entry.height

            MenuSeparator {
                id: separator
                visible: row.modelData.isSeparator
            }

            MenuItem {
                id: entry
                visible: !row.modelData.isSeparator
                enabled: row.modelData.enabled
                text: root.label(row.modelData.text)
                image: row.modelData.icon
                reserveMark: root.marks
                checked: row.modelData.buttonType !== QsMenuButtonType.None && row.modelData.checkState === Qt.Checked
                hasSubmenu: row.modelData.hasChildren
                closeOnTrigger: !row.modelData.hasChildren
                onTriggered: {
                    if (row.modelData.hasChildren) {
                        root.path = root.path.concat([row.modelData]);
                        root.highlighted = null;
                    } else {
                        row.modelData.triggered();
                    }
                }
            }
        }
    }
}
