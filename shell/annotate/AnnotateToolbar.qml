import QtQuick
import "../core"
import "../components"
import "../services"

/**
 * The screenshot editor's toolbar: a capsule of liquid glass (it lenses a
 * frosted copy of the frozen screen) centered under the selection, or above
 * it when there's no room, kept 8 pt inside the screen. Drag it by its grip;
 * a double click on the grip puts it back.
 *
 * Grip · the twelve tools · color, width, fill (rect and ellipse) · undo,
 * redo · copy, save, upload · settings. Hovering a button shows its name and
 * key under the toolbar; the color, width and settings popovers open from
 * their buttons with aurora's menu motion (GlassMorph: a drop out of the
 * button that swells into the panel; services/Annotate keeps which one is
 * open).
 *
 * Highlights are round, concentric with the capsule. The active tool is a
 * drop that slides to the new one on a spring, stretching with its speed
 * and settling back (Liquid Glass's selection); hovering only fades, since
 * the pointer crosses buttons all the time.
 */
Item {
    id: root

    property rect selection
    property Item frosted: null
    property point offset: Qt.point(0, 0)
    property string hint: ""
    property string hintKey: ""

    readonly property real margin: 8
    readonly property bool below: selection.y + selection.height + 12 + height <= parent.height - margin

    width: row.implicitWidth + 2 * 6
    height: 44
    x: Math.max(margin, Math.min(parent.width - width - margin, selection.x + (selection.width - width) / 2 + offset.x))
    y: Math.max(margin, Math.min(parent.height - height - margin,
        (below ? selection.y + selection.height + 12 : selection.y - height - 12) + offset.y))

    opacity: 0
    property real rise: 6
    transform: Translate { y: root.rise }
    onVisibleChanged: if (visible) {
        appear.restart();
        Qt.callLater(() => dropX.snap(root.toolX));
    }
    ParallelAnimation {
        id: appear
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "rise"; from: 6; to: 0; duration: 140; easing.type: Easing.OutCubic }
    }

    // Clicks on the toolbar stay on it.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
    }

    Glass {
        anchors.fill: parent
        refracts: root.frosted
        // The frosted screen exists only for the glass: keep it out of the scene.
        hideRefracted: true
        material: Tokens.glass.regular
        radius: height / 2
        track: [root.x, root.y, root.rise]
    }

    component Separator: Rectangle {
        width: 1
        height: 20
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: Tokens.separator
    }

    component ToolButton: Item {
        id: button
        property var glyph: []
        property bool current: false
        /** The active tool's drop draws its highlight (see `drop`). */
        property bool sliding: false
        property bool available: true
        property string label: ""
        property string shortcut: ""
        default property alias extra: custom.data
        signal clicked()
        width: 32
        height: 32
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        scale: hover.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: 80 } }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: button.current && !button.sliding ? root.currentFill
                : hover.containsMouse && button.available ? (Tokens.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.05)) : "transparent"
        }
        Icon {
            visible: button.glyph.length > 0
            anchors.centerIn: parent
            glyph: button.glyph
            size: 18
            color: !button.available ? Tokens.tertiaryLabel : button.current ? Tokens.label : Tokens.secondaryLabel
        }
        Item {
            id: custom
            anchors.fill: parent
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.available
            onClicked: button.clicked()
            // Entering the next button can come before leaving this one: only
            // clear the hint if it's still ours.
            onContainsMouseChanged: {
                if (containsMouse) {
                    root.hint = button.label;
                    root.hintKey = button.shortcut;
                } else if (root.hint === button.label) {
                    root.hint = "";
                    root.hintKey = "";
                }
            }
        }
    }

    // i18n-keys: annotate.tool.select annotate.tool.rect annotate.tool.ellipse annotate.tool.line annotate.tool.arrow annotate.tool.pen annotate.tool.marker annotate.tool.step annotate.tool.text annotate.tool.blur annotate.tool.pixelate annotate.tool.zoom
    readonly property var toolGlyphs: ({
        select: Glyphs.toolSelect, rect: Glyphs.toolRect, ellipse: Glyphs.toolEllipse, line: Glyphs.toolLine,
        arrow: Glyphs.toolArrow, pen: Glyphs.toolPen, marker: Glyphs.toolMarker, step: Glyphs.toolStep,
        text: Glyphs.toolText, blur: Glyphs.toolBlur, pixelate: Glyphs.toolPixelate, zoom: Glyphs.toolZoom
    })
    readonly property var keyOf: {
        const out = {};
        for (const k in Annotate.toolKeys)
            out[Annotate.toolKeys[k]] = k.toUpperCase();
        return out;
    }

    readonly property color currentFill: Tokens.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.10)

    // The active tool's drop: slides between tools, stretching with speed.
    // It lives in the row's coordinates (row.x + the button's x, both
    // reactive), so when the row re-centers — the Fill button coming and
    // going changes its width — the drop moves with it at once; only the
    // jump from tool to tool is animated.
    readonly property real toolX: {
        const b = toolButtons.count ? toolButtons.itemAt(Annotate.tools.indexOf(Annotate.tool)) : null;
        return b ? b.x : 0;
    }
    SpringValue {
        id: dropX
        to: root.toolX
        preset: ({ duration: 0.34, bounce: 0.22 })
    }
    Rectangle {
        id: drop
        readonly property real stretch: Math.min(14, Math.abs(dropX.velocity) * 0.006)
        x: row.x + dropX.value - stretch / 2
        width: 32 + stretch
        height: 32 - stretch * 0.25
        y: (root.height - height) / 2
        radius: height / 2
        color: root.currentFill
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        // The grip: drag to move the toolbar, double click to put it back.
        Item {
            width: 20
            height: 32
            anchors.verticalCenter: parent.verticalCenter
            Icon {
                anchors.centerIn: parent
                glyph: Glyphs.grip
                size: 16
                color: Tokens.tertiaryLabel
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                property point start
                property point from
                onPressed: mouse => {
                    const p = mapToItem(root.parent, mouse.x, mouse.y);
                    from = p;
                    start = root.offset;
                }
                onPositionChanged: mouse => {
                    const p = mapToItem(root.parent, mouse.x, mouse.y);
                    root.offset = Qt.point(start.x + p.x - from.x, start.y + p.y - from.y);
                }
                onDoubleClicked: root.offset = Qt.point(0, 0)
            }
        }
        Separator {}

        Repeater {
            id: toolButtons
            model: Annotate.tools
            delegate: ToolButton {
                required property string modelData
                sliding: true
                glyph: root.toolGlyphs[modelData]
                current: Annotate.tool === modelData
                label: I18n.tr("annotate.tool." + modelData)
                shortcut: root.keyOf[modelData] ?? ""
                onClicked: Annotate.setTool(modelData)
            }
        }
        Separator {}

        ToolButton {
            id: colorButton
            label: I18n.tr("annotate.color")
            shortcut: "C"
            current: Annotate.popover === "color"
            onClicked: Annotate.popover = Annotate.popover === "color" ? "" : "color"
            Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 18
                radius: 9
                color: Annotate.style.color
                border.width: 1.5
                border.color: Qt.rgba(1, 1, 1, 0.7)
            }
        }
        ToolButton {
            id: widthButton
            label: I18n.tr("annotate.width")
            shortcut: "W"
            current: Annotate.popover === "width"
            onClicked: Annotate.popover = Annotate.popover === "width" ? "" : "width"
            Rectangle {
                anchors.centerIn: parent
                width: Math.min(26, Annotate.style.width * 1.6 + 5)
                height: width
                radius: width / 2
                color: Tokens.secondaryLabel
                Behavior on width { NumberAnimation { duration: 90 } }
            }
        }
        ToolButton {
            visible: Annotate.fillable
            label: I18n.tr("annotate.fill")
            shortcut: "F"
            current: Annotate.style.filled
            onClicked: Annotate.toggleFill()
            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 4
                color: Annotate.style.filled ? Tokens.secondaryLabel : "transparent"
                border.width: 1.5
                border.color: Tokens.secondaryLabel
            }
        }
        Separator {}

        ToolButton {
            glyph: Glyphs.undo
            available: Annotate.past.length > 0
            label: I18n.tr("annotate.undo")
            shortcut: "Ctrl+Z"
            onClicked: Annotate.undo()
        }
        ToolButton {
            glyph: Glyphs.redo
            available: Annotate.future.length > 0
            label: I18n.tr("annotate.redo")
            shortcut: "Ctrl+Y"
            onClicked: Annotate.redo()
        }
        Separator {}

        ToolButton {
            glyph: Glyphs.copy
            label: I18n.tr("annotate.copy")
            shortcut: "Ctrl+C"
            onClicked: Annotate.copy()
        }
        ToolButton {
            glyph: Glyphs.download
            label: I18n.tr("annotate.save")
            shortcut: "Ctrl+S"
            onClicked: Annotate.save()
        }
        ToolButton {
            glyph: Glyphs.upload
            label: I18n.tr("annotate.upload")
            shortcut: "Ctrl+U"
            onClicked: Annotate.upload()
        }
        Separator {}

        ToolButton {
            id: gearButton
            glyph: Glyphs.gear
            label: I18n.tr("annotate.settings")
            shortcut: ","
            current: Annotate.popover === "settings"
            onClicked: Annotate.popover = Annotate.popover === "settings" ? "" : "settings"
        }
    }

    // The hovered button's name and key, under the toolbar (above it when it's at the bottom).
    Rectangle {
        visible: root.hint.length > 0 && !Annotate.popover.length
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.below || root.y < 40 ? root.height + 6 : -height - 6
        width: hintRow.implicitWidth + 2 * Tokens.space.m
        height: 24
        radius: height / 2
        color: Qt.rgba(0, 0, 0, 0.65)
        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: Tokens.space.s
            Text {
                text: root.hint
                color: "white"
                font.family: Tokens.family
                font.pixelSize: Tokens.type.footnote.size
            }
            Text {
                visible: root.hintKey.length > 0
                text: root.hintKey
                color: Qt.rgba(1, 1, 1, 0.6)
                font.family: Tokens.family
                font.pixelSize: Tokens.type.footnote.size
                font.weight: Font.DemiBold
            }
        }
    }

    // --- Popovers --------------------------------------------------------------------------

    /**
     * A popover with aurora's menu motion (GlassMorph): a drop out of its
     * button that swells into the panel and melts back into it. It works in
     * the window's coordinates and lenses the frosted screen.
     */
    component Pop: GlassMorph {
        id: pop
        property string name: ""
        property Item button: null
        property real panelWidth: 0
        property real panelHeight: 0
        /** Above the toolbar when there's no room below (or when `preferAbove`). */
        property bool preferAbove: false
        readonly property bool above: preferAbove ? root.y > panelHeight + 16 : !(root.y + root.height + 8 + panelHeight < root.parent.height - 8)

        x: -root.x
        y: -root.y
        width: root.parent ? root.parent.width : 0
        height: root.parent ? root.parent.height : 0
        open: Annotate.popover === name
        refracts: root.frosted
        track: [root.x, root.y, root.rise]
        fromRect: {
            void Annotate.popover;
            void root.x;
            void root.y;
            if (!button)
                return Qt.rect(0, 0, 0, 0);
            const p = button.mapToItem(root, 0, 0);
            return Qt.rect(root.x + p.x, root.y + p.y, button.width, button.height);
        }
        toRect: {
            void Annotate.popover;
            if (!button)
                return Qt.rect(0, 0, 0, 0);
            const c = root.x + button.mapToItem(root, button.width / 2, 0).x;
            const x = Math.max(8, Math.min(width - panelWidth - 8, c - panelWidth / 2));
            const y = above ? root.y - panelHeight - 8 : root.y + root.height + 8;
            return Qt.rect(x, y, panelWidth, panelHeight);
        }
    }

    Pop {
        name: "color"
        button: colorButton
        panelWidth: colorPopover.width
        panelHeight: colorPopover.height
        panelRadius: 16
        ColorPopover { id: colorPopover }
    }
    Pop {
        name: "width"
        button: widthButton
        panelWidth: widthPopover.width
        panelHeight: widthPopover.height
        panelRadius: widthPopover.height / 2
        WidthPopover { id: widthPopover }
    }
    Pop {
        name: "settings"
        button: gearButton
        preferAbove: true
        panelWidth: settingsPopover.width
        panelHeight: settingsPopover.height
        panelRadius: 18
        AnnotateSettings { id: settingsPopover }
    }
}
