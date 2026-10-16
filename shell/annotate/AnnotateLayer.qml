import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../components"
import "../services"
import "geometry.mjs" as G

/**
 * The screenshot editor on one screen (services/Annotate has the shared
 * state). The screen freezes (a still screencopy, without the pointer) and
 * fades in under a dim.
 *
 * Selecting: a loupe follows the pointer (8×, with crosshairs and the
 * coordinates); in region mode the window under the pointer lights up — drag
 * a region or click the window; in monitor mode a click takes the screen.
 *
 * Editing: the selection, bright inside the dim, with its size above and
 * eight handles to resize it; the active tool draws inside it (points are
 * kept within the selection); the wheel changes the width live; the select
 * tool picks a mark to move (drag) or delete (Delete). The toolbar of glass
 * sits next to the selection (AnnotateToolbar).
 *
 * Export renders the frozen screen and the marks (never the dim, frames or
 * toolbar) at the screen's full resolution and crops it to the selection.
 */
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    readonly property string name: modelData.name
    readonly property bool mine: Annotate.screenName === name
    readonly property bool selecting: Annotate.phase === "selecting"
    readonly property bool editing: Annotate.phase === "editing"
    readonly property real dpr: modelData.devicePixelRatio || 1
    readonly property rect sel: Annotate.selection
    readonly property bool ready: frozenLoader.item ? frozenLoader.item.hasContent : false

    visible: selecting || editing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-annotate"
    WlrLayershell.keyboardFocus: mine && visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onMineChanged: if (mine && visible) Qt.callLater(() => keys.forceActiveFocus())
    onVisibleChanged: if (mine && visible) Qt.callLater(() => keys.forceActiveFocus())

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            if (Annotate.key(event))
                event.accepted = true;
        }
    }

    // --- The frozen screen and the marks -------------------------------------------

    // A frosted copy for the glass (toolbar, popovers). The toolbar's glass
    // hides it from the scene (it's only rendered into the glass's lens, not
    // drawn full screen under the stage every frame).
    MultiEffect {
        id: frosted
        anchors.fill: parent
        source: frozenLoader.item
        blurEnabled: true
        blur: 1
        blurMax: 48
        autoPaddingEnabled: false
    }

    /** A mark as shown: the one being moved follows the pointer. */
    function markAt(i) {
        const a = Annotate.items[i];
        return touch.movingMark && i === Annotate.selected ? G.moved(a, touch.dx, touch.dy) : a;
    }
    // Which marks are effects (drawn first) and which vectors. These only
    // change when marks are added or removed, so the delegates aren't
    // rebuilt while one is dragged: only the dragged one updates.
    readonly property var effectMarks: Annotate.items.map((a, i) => i).filter(i => G.EFFECTS.includes(Annotate.items[i].type))
    readonly property var vectorMarks: Annotate.items.map((a, i) => i).filter(i => !G.EFFECTS.includes(Annotate.items[i].type))

    Item {
        id: stage
        anchors.fill: parent
        opacity: root.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Loader {
            id: frozenLoader
            anchors.fill: parent
            active: Annotate.active
            sourceComponent: ScreencopyView {
                captureSource: root.modelData
                live: false
                paintCursor: false
            }
        }

        // Effects first, then the vector marks (in the order they were made).
        Repeater {
            model: root.mine ? root.effectMarks : []
            delegate: AnnotationView {
                required property int modelData
                a: touch.movingMark && modelData === Annotate.selected ? root.markAt(modelData) : Annotate.items[modelData]
                frozen: frozenLoader.item
                dpr: root.dpr
            }
        }
        Repeater {
            model: root.mine ? root.vectorMarks : []
            delegate: AnnotationView {
                required property int modelData
                a: touch.movingMark && modelData === Annotate.selected ? root.markAt(modelData) : Annotate.items[modelData]
                frozen: frozenLoader.item
                dpr: root.dpr
            }
        }
        AnnotationView {
            visible: root.mine && !!Annotate.draft && Annotate.draft.type !== "text"
            a: Annotate.draft ?? ({})
            frozen: frozenLoader.item
            dpr: root.dpr
        }
    }

    // --- Dim, selection, handles -------------------------------------------------------

    /** The bright hole in the dim: the selection, or the region being dragged. */
    readonly property rect hole: editing && mine ? sel : touch.dragging ? touch.dragRect : Qt.rect(0, 0, 0, 0)
    readonly property bool hasHole: hole.width > 0 && hole.height > 0

    Item {
        anchors.fill: parent
        opacity: stage.opacity
        readonly property color dim: Qt.rgba(0, 0, 0, 0.45)
        Rectangle { color: parent.dim; x: 0; y: 0; width: parent.width; height: root.hole.y }
        Rectangle { color: parent.dim; x: 0; y: root.hole.y + root.hole.height; width: parent.width; height: parent.height - y }
        Rectangle { color: parent.dim; x: 0; y: root.hole.y; width: root.hole.x; height: root.hole.height }
        Rectangle { color: parent.dim; x: root.hole.x + root.hole.width; y: root.hole.y; width: parent.width - x; height: root.hole.height }

        // What a click would take: the window (region mode) or the screen (monitor mode).
        Rectangle {
            readonly property var r: touch.hoverRect
            visible: root.selecting && !touch.dragging && !!r && touch.containsMouse
            x: r ? r.x : 0
            y: r ? r.y : 0
            width: r ? r.width : 0
            height: r ? r.height : 0
            color: Qt.rgba(0.82, 0.85, 0.92, 0.16)
            border.width: 2.5
            border.color: Tokens.accent
        }

        // The selection's frame and size.
        Item {
            visible: root.hasHole
            Rectangle {
                x: root.hole.x - 2
                y: root.hole.y - 2
                width: root.hole.width + 4
                height: root.hole.height + 4
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.4)
            }
            Rectangle {
                x: root.hole.x - 1.5
                y: root.hole.y - 1.5
                width: root.hole.width + 3
                height: root.hole.height + 3
                color: "transparent"
                border.width: 1.5
                border.color: "white"
            }
            Rectangle {
                readonly property bool above: root.hole.y > height + 10
                x: Math.max(4, Math.min(root.width - width - 4, root.hole.x))
                y: above ? root.hole.y - height - 8 : root.hole.y + 8
                width: sizeLabel.implicitWidth + 2 * Tokens.space.m
                height: 22
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.6)
                Text {
                    id: sizeLabel
                    anchors.centerIn: parent
                    text: `${Math.round(root.hole.width)} × ${Math.round(root.hole.height)}`
                    color: "white"
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.footnote.size
                    font.features: ({ "tnum": 1 })
                }
            }
        }

        Repeater {
            model: root.editing && root.mine ? ["nw", "n", "ne", "e", "se", "s", "sw", "w"] : []
            delegate: Rectangle {
                required property string modelData
                readonly property point at: root.handlePoint(modelData)
                readonly property real size: modelData.length === 2 ? 10 : 8
                x: at.x - size / 2
                y: at.y - size / 2
                width: size
                height: size
                radius: 2
                color: "white"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.3)
            }
        }

        // The picked mark (select tool).
        Item {
            readonly property var a: Annotate.selected >= 0 && Annotate.selected < Annotate.items.length ? root.markAt(Annotate.selected) : null
            readonly property var bb: a ? G.bounds(a) : null
            readonly property real pad: a ? (a.type === "text" || a.type === "step" ? 4 : Math.max(a.width, 6)) : 0
            visible: root.editing && root.mine && !!a
            x: bb ? bb.x - pad : 0
            y: bb ? bb.y - pad : 0
            width: bb ? bb.width + 2 * pad : 0
            height: bb ? bb.height + 2 * pad : 0
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 1
                border.color: Tokens.accent
            }
            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    x: (index % 2) * parent.width - 2.5
                    y: Math.floor(index / 2) * parent.height - 2.5
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Tokens.accent
                }
            }
        }
    }

    function handlePoint(h) {
        const r = sel;
        const x = h.includes("w") ? r.x : h.includes("e") ? r.x + r.width : r.x + r.width / 2;
        const y = h.includes("n") ? r.y : h.includes("s") ? r.y + r.height : r.y + r.height / 2;
        return Qt.point(x, y);
    }
    function handleAt(x, y) {
        for (const h of ["nw", "ne", "se", "sw", "n", "e", "s", "w"]) {
            const p = handlePoint(h);
            if (Math.abs(x - p.x) <= 9 && Math.abs(y - p.y) <= 9)
                return h;
        }
        return "";
    }

    // --- Windows (click one to take it) ---------------------------------------------------

    readonly property var windows: {
        if (!root.visible)
            return [];
        void Hyprland.toplevels.values;
        const mon = Hyprland.monitorFor(root.modelData);
        const ws = mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1;
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.at || !o.size || o.hidden || o.mapped === false || !o.workspace || o.workspace.id !== ws || o.size[0] <= 0)
                continue;
            out.push({
                rect: Qt.rect(o.at[0] - root.modelData.x, o.at[1] - root.modelData.y, o.size[0], o.size[1]),
                order: o.focusHistoryID ?? 99,
                floating: !!o.floating
            });
        }
        return out.sort((a, b) => (b.floating - a.floating) || (a.order - b.order));
    }
    function windowAt(x, y) {
        return windows.find(w => x >= w.rect.x && x < w.rect.x + w.rect.width && y >= w.rect.y && y < w.rect.y + w.rect.height) ?? null;
    }
    function clampRect(r) {
        const x = Math.max(0, r.x);
        const y = Math.max(0, r.y);
        return Qt.rect(x, y, Math.min(r.x + r.width, width) - x, Math.min(r.y + r.height, height) - y);
    }

    // --- The pointer ------------------------------------------------------------------------

    MouseArea {
        id: touch
        anchors.fill: parent
        enabled: root.selecting || (root.editing && root.mine)
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        property point from
        property bool dragging: false
        property rect dragRect: Qt.rect(0, 0, 0, 0)
        property string resizing: ""
        property rect startSel
        property bool movingMark: false
        property real dx: 0
        property real dy: 0
        property var hoverRect: null

        cursorShape: {
            if (root.selecting)
                return Qt.CrossCursor;
            const h = resizing || root.handleAt(mouseX, mouseY);
            switch (h) {
            case "n": case "s": return Qt.SizeVerCursor;
            case "e": case "w": return Qt.SizeHorCursor;
            case "nw": case "se": return Qt.SizeFDiagCursor;
            case "ne": case "sw": return Qt.SizeBDiagCursor;
            }
            if (Annotate.tool === "select")
                return movingMark ? Qt.ClosedHandCursor : Qt.ArrowCursor;
            return Annotate.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor;
        }

        function point(mouse) {
            return G.clampPoint(mouse.x, mouse.y, root.sel);
        }

        onPositionChanged: mouse => {
            if (root.selecting) {
                if (dragging) {
                    dragRect = root.clampRect(Qt.rect(Math.min(from.x, mouse.x), Math.min(from.y, mouse.y), Math.abs(mouse.x - from.x), Math.abs(mouse.y - from.y)));
                } else {
                    const w = Annotate.mode === "monitor" ? null : root.windowAt(mouse.x, mouse.y);
                    hoverRect = Annotate.mode === "monitor" ? Qt.rect(0, 0, root.width, root.height) : (w ? root.clampRect(w.rect) : null);
                }
                return;
            }
            if (!pressed)
                return;
            if (resizing) {
                const r = G.resized(startSel, resizing, mouse.x - from.x, mouse.y - from.y);
                Annotate.resizeSelection(root.clampRect(Qt.rect(r.x, r.y, r.width, r.height)));
                return;
            }
            if (movingMark) {
                dx = mouse.x - from.x;
                dy = mouse.y - from.y;
                return;
            }
            const d = Annotate.draft;
            if (!d || d.type === "text")
                return;
            const [x, y] = point(mouse);
            if (d.type === "pen") {
                const last = d.points[d.points.length - 1];
                if (Math.abs(x - last[0]) >= 2 || Math.abs(y - last[1]) >= 2)
                    Annotate.draft = Object.assign({}, d, { points: d.points.concat([[x, y]]) });
            } else {
                Annotate.draft = Object.assign({}, d, { x2: x, y2: y });
            }
        }

        onPressed: mouse => {
            from = Qt.point(mouse.x, mouse.y);
            if (root.selecting) {
                Annotate.screenName = root.name;
                if (Annotate.mode === "monitor") {
                    Annotate.choose(root.name, Qt.rect(0, 0, root.width, root.height));
                    return;
                }
                dragging = true;
                dragRect = Qt.rect(mouse.x, mouse.y, 0, 0);
                return;
            }
            // Editing.
            if (Annotate.popover.length) {
                Annotate.popover = "";
                return;
            }
            const h = root.handleAt(mouse.x, mouse.y);
            if (h) {
                resizing = h;
                startSel = root.sel;
                return;
            }
            if (Annotate.typing) {
                // This click only finishes the text.
                Annotate.commitText();
                keys.forceActiveFocus();
                return;
            }
            const [x, y] = point(mouse);
            switch (Annotate.tool) {
            case "select":
                Annotate.selected = G.pick(Annotate.items, mouse.x, mouse.y);
                movingMark = Annotate.selected >= 0;
                dx = 0;
                dy = 0;
                return;
            case "step":
                Annotate.add(Annotate.make({ x1: x, y1: y, n: G.nextStep(Annotate.items) }));
                return;
            case "text":
                Annotate.draft = Annotate.make({ x1: x, y1: y, text: "", size: G.textSize(Annotate.style.width) });
                Annotate.typing = true;
                textInput.text = "";
                Qt.callLater(() => textInput.forceActiveFocus());
                return;
            case "pen":
                Annotate.draft = Annotate.make({ x1: x, y1: y, points: [[x, y]] });
                return;
            default:
                Annotate.draft = Annotate.make({ x1: x, y1: y, x2: x, y2: y, zoom: Settings.annotateZoom });
            }
        }

        onReleased: mouse => {
            if (root.selecting) {
                if (!dragging)
                    return;
                dragging = false;
                if (dragRect.width > 2 && dragRect.height > 2) {
                    Annotate.choose(root.name, dragRect);
                } else {
                    const w = root.windowAt(mouse.x, mouse.y);
                    if (w)
                        Annotate.choose(root.name, root.clampRect(w.rect));
                }
                return;
            }
            if (resizing) {
                resizing = "";
                return;
            }
            if (movingMark) {
                movingMark = false;
                Annotate.moveSelected(dx, dy);
                dx = 0;
                dy = 0;
                return;
            }
            const d = Annotate.draft;
            if (d && d.type !== "text") {
                Annotate.draft = null;
                Annotate.add(d);
            }
        }

        onWheel: wheel => {
            Annotate.setWidth(Annotate.style.width + (wheel.angleDelta.y > 0 ? 1 : -1));
            wheel.accepted = true;
        }
    }

    // --- Typing a text -------------------------------------------------------------------------

    TextInput {
        id: textInput
        visible: root.mine && Annotate.typing && !!Annotate.draft
        x: Annotate.draft ? Annotate.draft.x1 : 0
        y: Annotate.draft ? Annotate.draft.y1 : 0
        width: Math.max(contentWidth + 4, 8)
        color: Annotate.draft ? Annotate.draft.color : "white"
        font.family: Tokens.family
        font.pixelSize: Annotate.draft ? Annotate.draft.size : 28
        cursorVisible: true
        onTextChanged: if (Annotate.typing && Annotate.draft) Annotate.draft = Object.assign({}, Annotate.draft, { text: text })
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                Annotate.commitText();
                keys.forceActiveFocus();
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                Annotate.back();
                keys.forceActiveFocus();
                event.accepted = true;
            }
        }
    }

    // --- The loupe (while selecting) --------------------------------------------------------

    Item {
        id: loupe
        readonly property real size: 110
        readonly property real zoom: 8
        visible: root.selecting && root.ready && touch.containsMouse
        x: {
            const px = touch.mouseX + 24;
            return Math.max(4, px + size > root.width - 4 ? touch.mouseX - 24 - size : px);
        }
        y: {
            const py = touch.mouseY + 24;
            return Math.max(4, py + size + 30 > root.height - 4 ? touch.mouseY - 24 - size - 30 : py);
        }
        width: size
        height: size + 30

        Rectangle {
            width: loupe.size
            height: loupe.size
            radius: 12
            color: "black"
            clip: true
            ShaderEffectSource {
                anchors.fill: parent
                sourceItem: frozenLoader.item
                sourceRect: Qt.rect(touch.mouseX - loupe.size / loupe.zoom / 2, touch.mouseY - loupe.size / loupe.zoom / 2, loupe.size / loupe.zoom, loupe.size / loupe.zoom)
                textureSize: Qt.size(Math.ceil(loupe.size / loupe.zoom * root.dpr), Math.ceil(loupe.size / loupe.zoom * root.dpr))
                smooth: false
            }
            Rectangle { x: parent.width / 2 - 0.5; width: 1; height: parent.height; color: Qt.alpha(Tokens.accent, 0.7) }
            Rectangle { y: parent.height / 2 - 0.5; height: 1; width: parent.width; color: Qt.alpha(Tokens.accent, 0.7) }
            Rectangle {
                anchors.centerIn: parent
                width: loupe.zoom
                height: loupe.zoom
                color: "transparent"
                border.width: 1
                border.color: "white"
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.bottomMargin: 30
            radius: 12
            color: "transparent"
            border.width: 1.5
            border.color: Qt.rgba(1, 1, 1, 0.85)
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: loupe.size + 6
            width: coords.implicitWidth + 2 * Tokens.space.m
            height: 22
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.6)
            Text {
                id: coords
                anchors.centerIn: parent
                text: `${Math.round(root.modelData.x + touch.mouseX)}, ${Math.round(root.modelData.y + touch.mouseY)}`
                color: "white"
                font.family: Tokens.family
                font.pixelSize: Tokens.type.footnote.size
                font.features: ({ "tnum": 1 })
            }
        }
    }

    // --- The toolbar ------------------------------------------------------------------------------

    AnnotateToolbar {
        visible: root.editing && root.mine && root.ready
        selection: root.sel
        frosted: frosted
    }

    // The keyboard comes back to the editor when a popover closes.
    Connections {
        target: Annotate
        function onPopoverChanged() {
            if (!Annotate.popover.length && root.mine && root.visible)
                keys.forceActiveFocus();
        }
    }

    // --- Export ------------------------------------------------------------------------------------

    Connections {
        target: Annotate
        function onExportRequested(action) {
            if (!root.mine)
                return;
            const file = Annotate.targetFor(action);
            const full = Annotate.runtime + `/aurora-shot-full-${Date.now()}.png`;
            const r = root.sel;
            const s = root.dpr;
            stage.grabToImage(result => {
                result.saveToFile(full);
                crop.action = action;
                crop.file = file;
                crop.command = ["bash", "-c", 'magick "$1" -crop "$3" +repage "$2"; rc=$?; rm -f "$1"; exit $rc', "_", full, file,
                    `${Math.round(r.width * s)}x${Math.round(r.height * s)}+${Math.round(r.x * s)}+${Math.round(r.y * s)}`];
                crop.running = true;
            // grabToImage already renders at the screen's scale: ask for the logical size.
            }, Qt.size(root.width, root.height));
        }
    }

    Process {
        id: crop
        property string action: ""
        property string file: ""
        onExited: code => {
            if (code === 0) {
                Annotate.deliver(action, file);
            } else {
                Quickshell.execDetached(["notify-send", "-a", "aurora", "-u", "critical", I18n.tr("annotate.exportFailed")]);
                Annotate.close();
            }
        }
    }
}
