import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../components"
import "../services"

/**
 * Screenshot and screen recording, after macOS's ⇧⌘5 (Super+D here): a
 * toolbar of liquid glass at the bottom of the focused screen — close, capture
 * the entire screen or a selection, record the entire screen or a selection,
 * Options, and the Capture / Record button.
 *
 * In the selection modes the screen dims around the selection, drawn with a
 * hairline and eight handles and its size below it. Drag anywhere to draw a
 * new one, drag inside to move it, drag a handle to resize, click a window to
 * select it (windows highlight under the pointer). Return or a double click
 * inside starts, Esc closes. In the entire-screen modes a click anywhere
 * starts. With a timer the toolbar gives way to the countdown, centered on
 * what will be captured. Everything is gone from the screen before the
 * capture (services/Capture).
 */
PanelWindow {
    id: root

    readonly property bool choosing: Capture.state === "choosing"
    readonly property bool counting: Capture.state === "countdown"
    readonly property real s: 1

    screen: Capture.screen
    visible: choosing || counting || !openness.settled
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-capture"
    WlrLayershell.keyboardFocus: choosing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // While counting down only the countdown takes input.
    mask: Region {
        item: root.counting ? countdownDisc : fullArea
    }
    Item {
        id: fullArea
        anchors.fill: parent
    }

    SpringValue {
        id: openness
        to: root.choosing ? 1 : 0
        preset: root.choosing ? Motion.smooth : Motion.dismiss
    }

    readonly property rect sel: Capture.selection
    readonly property bool selecting: Capture.selectionMode

    onChoosingChanged: if (choosing) {
        Hyprland.refreshToplevels();
        Qt.callLater(() => keys.forceActiveFocus());
    }

    Item {
        id: keys
        focus: root.choosing
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape)
                Capture.cancel();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                Capture.go();
            else
                return;
            event.accepted = true;
        }
    }

    // --- Windows under the pointer (click one to select it) ---------------------

    readonly property var windows: {
        void Hyprland.toplevels.values;
        const mon = Hyprland.monitorFor(root.screen);
        const ws = mon && mon.activeWorkspace ? mon.activeWorkspace.id : -1;
        const out = [];
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject;
            if (!o || !o.at || !o.size || o.hidden || !o.workspace || o.workspace.id !== ws)
                continue;
            out.push({
                rect: Qt.rect(o.at[0] - root.screen.x, o.at[1] - root.screen.y, o.size[0], o.size[1]),
                order: o.focusHistoryID ?? 99,
                floating: !!o.floating
            });
        }
        // Floating windows over tiled ones, then the most recently focused first.
        return out.sort((a, b) => (b.floating - a.floating) || (a.order - b.order));
    }
    function windowAt(x, y) {
        return windows.find(w => x >= w.rect.x && x < w.rect.x + w.rect.width && y >= w.rect.y && y < w.rect.y + w.rect.height) ?? null;
    }

    // --- The selection ----------------------------------------------------------

    Item {
        id: stage
        anchors.fill: parent
        visible: root.choosing || !openness.settled
        opacity: openness.value

        // The dim around the selection (or none, for the entire screen).
        readonly property color dim: Qt.rgba(0, 0, 0, 0.38)
        Rectangle { visible: root.selecting; color: stage.dim; x: 0; y: 0; width: parent.width; height: root.sel.y }
        Rectangle { visible: root.selecting; color: stage.dim; x: 0; y: root.sel.y + root.sel.height; width: parent.width; height: parent.height - y }
        Rectangle { visible: root.selecting; color: stage.dim; x: 0; y: root.sel.y; width: root.sel.x; height: root.sel.height }
        Rectangle { visible: root.selecting; color: stage.dim; x: root.sel.x + root.sel.width; y: root.sel.y; width: parent.width - x; height: root.sel.height }

        // The window under the pointer, offered for selection.
        Rectangle {
            readonly property var w: touch.hoverWindow
            visible: root.selecting && !!w && !touch.pressed
            x: w ? w.rect.x : 0
            y: w ? w.rect.y : 0
            width: w ? w.rect.width : 0
            height: w ? w.rect.height : 0
            color: Qt.alpha(Tokens.accent, 0.12)
            border.width: 2
            border.color: Qt.alpha(Tokens.accent, 0.8)
            radius: 10
        }

        Rectangle {
            visible: root.selecting
            x: root.sel.x - 1
            y: root.sel.y - 1
            width: root.sel.width + 2
            height: root.sel.height + 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.9)
        }

        // Handles at the corners and the middle of each side.
        Repeater {
            model: root.selecting ? ["nw", "n", "ne", "e", "se", "s", "sw", "w"] : []
            delegate: Rectangle {
                required property string modelData
                readonly property point at: root.handlePoint(modelData)
                x: at.x - width / 2
                y: at.y - height / 2
                width: 9
                height: 9
                radius: 4.5
                color: "white"
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.25)
            }
        }

        // The size, under the selection (or inside it at the bottom edge).
        Rectangle {
            visible: root.selecting && root.sel.width > 0
            readonly property bool below: root.sel.y + root.sel.height + 34 < toolbar.y
            x: Math.max(4, Math.min(parent.width - width - 4, root.sel.x + (root.sel.width - width) / 2))
            y: below ? root.sel.y + root.sel.height + 8 : root.sel.y + root.sel.height - height - 8
            width: sizeText.implicitWidth + 2 * Tokens.space.m
            height: 22
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.55)
            Text {
                id: sizeText
                anchors.centerIn: parent
                text: `${Math.round(root.sel.width)} × ${Math.round(root.sel.height)}`
                color: "white"
                font.family: Tokens.family
                font.pixelSize: Tokens.type.footnote.size
                font.features: ({ "tnum": 1 })
            }
        }
    }

    function handlePoint(h) {
        const r = sel;
        const x = h.includes("w") ? r.x : h.includes("e") ? r.x + r.width : r.x + r.width / 2;
        const y = h.includes("n") ? r.y : h.includes("s") ? r.y + r.height : r.y + r.height / 2;
        return Qt.point(x, y);
    }

    MouseArea {
        id: touch
        anchors.fill: parent
        enabled: root.choosing
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton

        property string kind: ""
        property point from
        property rect start
        property bool moved: false
        property var hoverWindow: null

        cursorShape: {
            if (!root.selecting)
                return Qt.PointingHandCursor;
            const k = pressed ? kind : root.hitTest(mouseX, mouseY);
            switch (k) {
            case "move": return pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor;
            case "n": case "s": return Qt.SizeVerCursor;
            case "e": case "w": return Qt.SizeHorCursor;
            case "nw": case "se": return Qt.SizeFDiagCursor;
            case "ne": case "sw": return Qt.SizeBDiagCursor;
            default: return Qt.CrossCursor;
            }
        }

        onPositionChanged: mouse => {
            if (!pressed) {
                hoverWindow = root.selecting && root.hitTest(mouse.x, mouse.y) === "" ? root.windowAt(mouse.x, mouse.y) : null;
                return;
            }
            const dx = mouse.x - from.x;
            const dy = mouse.y - from.y;
            if (!moved && Math.abs(dx) + Math.abs(dy) < 3)
                return;
            moved = true;
            Capture.setSelection(root.dragged(kind, start, from, Qt.point(mouse.x, mouse.y)));
        }
        onPressed: mouse => {
            from = Qt.point(mouse.x, mouse.y);
            start = root.sel;
            moved = false;
            kind = root.selecting ? (root.hitTest(mouse.x, mouse.y) || "new") : "";
        }
        onReleased: mouse => {
            if (!root.selecting) {
                Capture.go();
                return;
            }
            if (!moved && kind === "new") {
                const w = root.windowAt(mouse.x, mouse.y);
                if (w)
                    Capture.setSelection(root.clampRect(w.rect));
            }
            kind = "";
        }
        onDoubleClicked: mouse => {
            if (root.selecting && root.hitTest(mouse.x, mouse.y) === "move")
                Capture.go();
        }
    }

    /** What's under a point: a handle, "move" inside, or "" outside. */
    function hitTest(x, y) {
        for (const h of ["nw", "ne", "se", "sw", "n", "e", "s", "w"]) {
            const p = handlePoint(h);
            if (Math.abs(x - p.x) <= 8 && Math.abs(y - p.y) <= 8)
                return h;
        }
        const r = sel;
        if (x > r.x && x < r.x + r.width && y > r.y && y < r.y + r.height)
            return "move";
        return "";
    }

    function clampRect(r) {
        const x = Math.max(0, Math.min(r.x, width - 8));
        const y = Math.max(0, Math.min(r.y, height - 8));
        return Qt.rect(x, y, Math.max(8, Math.min(r.width, width - x)), Math.max(8, Math.min(r.height, height - y)));
    }

    function dragged(kind, r, a, b) {
        const dx = b.x - a.x;
        const dy = b.y - a.y;
        if (kind === "new")
            return clampRect(Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(dx), Math.abs(dy)));
        if (kind === "move") {
            const x = Math.max(0, Math.min(r.x + dx, width - r.width));
            const y = Math.max(0, Math.min(r.y + dy, height - r.height));
            return Qt.rect(x, y, r.width, r.height);
        }
        let x1 = r.x, y1 = r.y, x2 = r.x + r.width, y2 = r.y + r.height;
        if (kind.includes("w")) x1 = Math.min(x1 + dx, x2 - 8);
        if (kind.includes("e")) x2 = Math.max(x2 + dx, x1 + 8);
        if (kind.includes("n")) y1 = Math.min(y1 + dy, y2 - 8);
        if (kind.includes("s")) y2 = Math.max(y2 + dy, y1 + 8);
        return clampRect(Qt.rect(x1, y1, x2 - x1, y2 - y1));
    }

    // --- The toolbar --------------------------------------------------------------

    GlassBackdrop {
        id: toolbarBackdrop
        screen: root.screen
        region: Qt.rect(toolbar.x, toolbar.y, toolbar.width, toolbar.height)
    }

    component ModeButton: Item {
        id: mode
        property string value: ""
        property var glyph: []
        readonly property bool current: Capture.mode === value
        width: 40
        height: 32
        // Hover only fades; the current mode is the toolbar's sliding drop.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: !mode.current && modeHover.containsMouse ? (Tokens.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)) : "transparent"
        }
        Icon {
            anchors.centerIn: parent
            glyph: mode.glyph
            size: 20
            color: Tokens.label
        }
        MouseArea {
            id: modeHover
            anchors.fill: parent
            hoverEnabled: true
            onClicked: Capture.setMode(mode.value)
            onContainsMouseChanged: toolbar.hint = containsMouse ? I18n.tr("capture.mode." + mode.value) : ""
        }
    }
    component Divider: Rectangle {
        width: 1
        height: 22
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: Tokens.separator
    }

    // i18n-keys: capture.mode.shotScreen capture.mode.shotSelection capture.mode.recordScreen capture.mode.recordSelection
    Item {
        id: toolbar
        property string hint: ""
        width: row.implicitWidth + 2 * Tokens.space.s
        height: 46
        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height - height - Math.max(36, root.height * 0.05))
        visible: !root.counting
        opacity: openness.value
        scale: 0.94 + 0.06 * openness.value
        transformOrigin: Item.Bottom

        // The toolbar is a control, not part of the screen to select.
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
        }

        Glass {
            anchors.fill: parent
            backdrop: toolbarBackdrop
            material: Tokens.glass.regular
            radius: height / 2
            track: [toolbar.scale]
        }

        // The current mode: a drop that slides to the chosen one on a spring,
        // stretching with its speed (Liquid Glass's selection).
        readonly property real modeX: {
            void row.implicitWidth;
            void Capture.mode;
            for (const c of row.children)
                if (c.value === Capture.mode)
                    return c.mapToItem(toolbar, 0, 0).x;
            return 0;
        }
        SpringValue {
            id: modeDrop
            to: toolbar.modeX
            preset: ({ duration: 0.34, bounce: 0.22 })
        }
        Connections {
            target: root
            function onChoosingChanged() {
                if (root.choosing)
                    Qt.callLater(() => modeDrop.snap(toolbar.modeX));
            }
        }
        Rectangle {
            readonly property real stretch: Math.min(16, Math.abs(modeDrop.velocity) * 0.006)
            x: modeDrop.value - stretch / 2
            width: 40 + stretch
            height: 32 - stretch * 0.25
            y: (toolbar.height - height) / 2
            radius: height / 2
            color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.10)
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: Tokens.space.xs

            Item {
                width: 32
                height: 32
                Icon {
                    anchors.centerIn: parent
                    glyph: Glyphs.closeCircle
                    size: 18
                    color: closeHover.containsMouse ? Tokens.label : Tokens.secondaryLabel
                }
                MouseArea {
                    id: closeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Capture.cancel()
                    onContainsMouseChanged: toolbar.hint = containsMouse ? I18n.tr("capture.close") : ""
                }
            }
            Divider {}
            ModeButton { value: "shotScreen"; glyph: Glyphs.captureScreen }
            ModeButton { value: "shotSelection"; glyph: Glyphs.captureSelection }
            Divider {}
            ModeButton { value: "recordScreen"; glyph: Glyphs.recordScreen }
            ModeButton { value: "recordSelection"; glyph: Glyphs.recordSelection }
            Divider {}

            // Options ⌄
            Item {
                id: optionsButton
                width: optionsRow.implicitWidth + 2 * Tokens.space.m
                height: 32
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: optionsHover.containsMouse || options.open ? (Tokens.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)) : "transparent"
                }
                Row {
                    id: optionsRow
                    anchors.centerIn: parent
                    spacing: Tokens.space.xs
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("capture.options")
                        color: Tokens.label
                        font.family: Tokens.family
                        font.pixelSize: Tokens.type.body.size
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: Glyphs.chevron
                        size: 10
                        rotation: 90
                        color: Tokens.secondaryLabel
                    }
                }
                MouseArea {
                    id: optionsHover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: options.open ? options.open = false : options.show(optionsButton)
                }
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                text: Capture.recordMode ? I18n.tr("capture.record") : I18n.tr("capture.capture")
                isDefault: true
                onClicked: Capture.go()
            }
        }

        // What the hovered button does, above the toolbar.
        Rectangle {
            visible: toolbar.hint.length > 0
            anchors.horizontalCenter: parent.horizontalCenter
            y: -height - Tokens.space.s
            width: hintText.implicitWidth + 2 * Tokens.space.m
            height: 24
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.6)
            Text {
                id: hintText
                anchors.centerIn: parent
                text: toolbar.hint
                color: "white"
                font.family: Tokens.family
                font.pixelSize: Tokens.type.footnote.size
            }
        }
    }

    // What the Options menu's glass sees (it opens above the toolbar).
    GlassBackdrop {
        id: menuBackdrop
        screen: root.screen
        region: Qt.rect(0, Math.round(root.height * 0.3), root.width, Math.round(root.height * 0.7))
    }

    PopupMenu {
        id: options
        upward: true
        backdrop: menuBackdrop
        items: {
            const save = v => () => { Settings.captureSaveTo = v; };
            const timer = v => () => { Settings.captureTimer = v; };
            return [
                { label: I18n.tr("capture.saveTo"), enabled: false },
                { label: I18n.tr("capture.save.desktop"), checked: Settings.captureSaveTo === "desktop", act: save("desktop") },
                { label: I18n.tr("capture.save.documents"), checked: Settings.captureSaveTo === "documents", act: save("documents") },
                { label: I18n.tr("capture.save.default"), checked: Settings.captureSaveTo === "default", act: save("default") },
                { label: I18n.tr("capture.save.clipboard"), checked: Settings.captureSaveTo === "clipboard", act: save("clipboard") },
                { label: I18n.tr("capture.timer"), enabled: false },
                { label: I18n.tr("capture.timer.none"), checked: Settings.captureTimer === 0, act: timer(0) },
                { label: I18n.tr("capture.timer.seconds", { n: 5 }), checked: Settings.captureTimer === 5, act: timer(5) },
                { label: I18n.tr("capture.timer.seconds", { n: 10 }), checked: Settings.captureTimer === 10, act: timer(10) },
                { label: I18n.tr("capture.optionsHeader"), enabled: false },
                { label: I18n.tr("capture.mic"), checked: Settings.captureMic, act: () => { Settings.captureMic = !Settings.captureMic; } },
                { label: I18n.tr("capture.systemAudio"), checked: Settings.captureSystemAudio, act: () => { Settings.captureSystemAudio = !Settings.captureSystemAudio; } },
                { label: I18n.tr("capture.pointer"), checked: Settings.capturePointer, act: () => { Settings.capturePointer = !Settings.capturePointer; } },
                { label: I18n.tr("capture.remember"), checked: Settings.captureRemember, act: () => { Settings.captureRemember = !Settings.captureRemember; } }
            ];
        }
    }

    // --- The countdown --------------------------------------------------------------

    GlassBackdrop {
        id: countdownBackdrop
        screen: root.screen
        region: Qt.rect(countdownDisc.x, countdownDisc.y, countdownDisc.width, countdownDisc.height)
    }

    Item {
        id: countdownDisc
        readonly property point centre: root.selecting
            ? Qt.point(root.sel.x + root.sel.width / 2, root.sel.y + root.sel.height / 2)
            : Qt.point(root.width / 2, root.height / 2)
        width: 112
        height: 112
        x: centre.x - width / 2
        y: centre.y - height / 2
        visible: root.counting

        Glass {
            anchors.fill: parent
            backdrop: countdownBackdrop
            material: Tokens.glass.regular
            radius: width / 2
        }
        Text {
            anchors.centerIn: parent
            text: Capture.countdown
            color: Tokens.label
            font.family: Tokens.family
            font.pixelSize: 52
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
        // A click cancels the timer.
        MouseArea {
            anchors.fill: parent
            onClicked: Capture.cancel()
        }
    }
}
