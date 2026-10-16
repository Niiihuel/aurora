import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../components"
import "../services"
import "../core/search.mjs" as Search

/**
 * The launcher, after macOS Tahoe's Spotlight but at the bottom centre of the
 * focused screen (aurora has no dock there; it's where the eye already is): a
 * capsule of liquid glass with the search field and, as you type, the results
 * on a second piece of glass that opens upward. The best match sits next to
 * the field, at the bottom of the list; ↑ walks up it.
 *
 * - Apps mode: installed apps matched loosely ("vsc" finds Visual Studio
 *   Code), favorites first; with nothing typed, the most used apps. An
 *   arithmetic expression shows its result first; Return copies it.
 * - Clipboard mode: the clipboard history (cliphist), newest first, filtered
 *   as you type; Return copies the entry back.
 *
 * ↑/↓ move up/down the list, Return opens or copies, Tab switches mode, Esc or a click
 * outside closes. It appears with a short zoom-and-fade on the smooth spring.
 */
PanelWindow {
    id: root

    /** "apps" or "clipboard". */
    property string mode: "apps"
    property bool wanted: false
    property int selected: 0

    function toggle(m) {
        if (wanted && mode === m)
            close();
        else
            open(m);
    }
    function open(m) {
        mode = m;
        field.text = "";
        selected = 0;
        wanted = true;
        if (m === "clipboard")
            history.reload();
        Qt.callLater(() => field.forceActiveFocus());
    }
    function close() {
        wanted = false;
    }

    screen: {
        const focused = Hyprland.focusedMonitor;
        for (const s of Quickshell.screens)
            if (focused && s.name === focused.name)
                return s;
        return Quickshell.screens[0];
    }

    SpringValue {
        id: openness
        to: root.wanted ? 1 : 0
        preset: root.wanted ? Motion.smooth : Motion.dismiss
    }

    visible: wanted || !openness.settled
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-launcher"
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property real panelWidth: 640
    readonly property real rowHeight: 40
    readonly property int maxRows: 8

    // --- Results -------------------------------------------------------------------

    readonly property var calculation: mode === "apps" ? Search.calculate(field.text) : null

    readonly property var rows: {
        if (mode === "clipboard") {
            const q = field.text;
            return history.items.filter(i => !q.trim().length || Search.score(i.title, q) > 0).slice(0, 100);
        }
        const list = [];
        if (calculation !== null)
            list.push({ kind: "calc", value: calculation, title: formatNumber(calculation), subtitle: I18n.tr("launcher.calculator") });
        for (const e of Apps.search(field.text, maxRows))
            list.push({ kind: "app", entry: e, title: e.name, subtitle: e.genericName || e.comment || "" });
        return list;
    }
    onRowsChanged: selected = Math.min(selected, Math.max(0, rows.length - 1))

    readonly property string sectionTitle: mode === "clipboard" ? I18n.tr("launcher.clipboard")
        : field.text.trim().length ? I18n.tr("launcher.applications") : I18n.tr("launcher.suggestions")
    readonly property bool showResults: rows.length > 0 || field.text.trim().length > 0

    function formatNumber(v) {
        return String(Number(v.toPrecision(12))).replace(".", I18n.locale.decimalPoint);
    }

    function run(row) {
        if (!row)
            return;
        if (row.kind === "app")
            Apps.launch(row.entry);
        else if (row.kind === "calc")
            Quickshell.execDetached(["wl-copy", String(Number(row.value.toPrecision(12)))]);
        else if (row.kind === "clip")
            Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", row.line]);
        close();
    }

    Process {
        id: history
        property var items: []
        function reload() {
            running = false;
            running = true;
        }
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const preview = line.slice(tab + 1);
                    const image = preview.match(/^\[\[ binary data .* (\d+x\d+) \]\]$/);
                    out.push({
                        kind: "clip",
                        line,
                        title: image ? I18n.tr("launcher.image", { size: image[1].replace("x", "×") }) : preview.trim(),
                        subtitle: ""
                    });
                }
                history.items = out;
            }
        }
    }

    // --- Scene ---------------------------------------------------------------------

    MouseArea {
        anchors.fill: parent
        onPressed: root.close()
    }

    GlassBackdrop {
        id: launcherBackdrop
        screen: root.screen
        region: Qt.rect(card.x, card.y, card.width, card.height)
    }

    Item {
        id: card
        x: Math.round((root.width - root.panelWidth) / 2)
        // Anchored by its bottom: the field stays put while the results grow up.
        y: root.height - Math.round(Math.max(48, root.height * 0.08)) - height
        width: root.panelWidth
        height: bar.height + (root.showResults ? Tokens.space.m + results.height : 0)
        opacity: openness.value
        scale: 0.96 + 0.04 * openness.value
        transformOrigin: Item.Bottom

        // Clicks on the launcher itself don't close it.
        MouseArea { anchors.fill: parent }

        // The search field.
        Item {
            id: bar
            y: parent.height - height
            width: parent.width
            height: 52

            Glass {
                anchors.fill: parent
                backdrop: launcherBackdrop
                material: Tokens.glass.regular
                radius: height / 2
                track: [card.scale]
            }

            Icon {
                id: magnifier
                x: Tokens.space.xl
                anchors.verticalCenter: parent.verticalCenter
                glyph: Glyphs.magnifier
                size: 20
                color: Tokens.secondaryLabel
            }

            TextInput {
                id: field
                anchors.left: magnifier.right
                anchors.leftMargin: Tokens.space.m
                anchors.right: modes.left
                anchors.rightMargin: Tokens.space.m
                anchors.verticalCenter: parent.verticalCenter
                color: Tokens.label
                selectionColor: Tokens.accent
                selectedTextColor: "white"
                font.family: Tokens.family
                font.pixelSize: Tokens.type.title2.size + 3
                clip: true
                onTextChanged: root.selected = 0

                Text {
                    visible: !field.text.length
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.mode === "clipboard" ? I18n.tr("launcher.clipboard") : I18n.tr("launcher.placeholder")
                    color: Tokens.tertiaryLabel
                    font: field.font
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape)
                        root.close();
                    else if (event.key === Qt.Key_Up)
                        root.selected = Math.min(root.rows.length - 1, root.selected + 1);
                    else if (event.key === Qt.Key_Down)
                        root.selected = Math.max(0, root.selected - 1);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        root.run(root.rows[root.selected]);
                    else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                        root.open(root.mode === "apps" ? "clipboard" : "apps");
                    else
                        return;
                    event.accepted = true;
                }
            }

            // Mode buttons, like Tahoe's Spotlight (Apps, Clipboard).
            Row {
                id: modes
                anchors.right: parent.right
                anchors.rightMargin: Tokens.space.m + 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.space.s

                Repeater {
                    model: [
                        { mode: "apps", glyph: Glyphs.apps },
                        { mode: "clipboard", glyph: Glyphs.clipboard }
                    ]
                    delegate: Item {
                        id: modeButton
                        required property var modelData
                        readonly property bool on: root.mode === modelData.mode
                        width: 34
                        height: 34

                        Glass {
                            anchors.fill: parent
                            backdrop: launcherBackdrop
                            material: modeButton.on ? Tokens.glass.toggleOn : Tokens.glass.regularSmall
                            radius: width / 2
                            shadow: false
                            held: modeTouch.pressed
                            track: [card.scale]
                        }
                        Icon {
                            anchors.centerIn: parent
                            glyph: modeButton.modelData.glyph
                            size: 15
                            color: modeButton.on ? Tokens.accent : Tokens.label
                        }
                        MouseArea {
                            id: modeTouch
                            anchors.fill: parent
                            onClicked: root.open(modeButton.modelData.mode)
                        }
                    }
                }
            }
        }

        // The results.
        Item {
            id: results
            visible: root.showResults
            y: 0
            width: parent.width
            readonly property real wantedHeight: header.height + (root.rows.length ? Math.min(root.rows.length, root.maxRows) * root.rowHeight : root.rowHeight) + Tokens.space.m * 2
            SpringValue { id: grow; to: results.wantedHeight; preset: Motion.smooth; epsilon: 0.5 }
            height: Math.max(1, grow.value)

            Glass {
                anchors.fill: parent
                backdrop: launcherBackdrop
                material: Tokens.glass.regular
                radius: 22
                track: [card.scale, results.height]
            }

            Item {
                anchors.fill: parent
                anchors.margins: Tokens.space.m
                clip: true

                Text {
                    id: header
                    x: Tokens.space.s
                    height: 24
                    verticalAlignment: Text.AlignVCenter
                    text: root.sectionTitle
                    color: Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.subheadline.size
                    font.weight: Font.DemiBold
                }

                Text {
                    visible: !root.rows.length
                    y: header.height
                    x: Tokens.space.s
                    height: root.rowHeight
                    verticalAlignment: Text.AlignVCenter
                    text: I18n.tr("launcher.noResults")
                    color: Tokens.tertiaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                }

                ListView {
                    id: listView
                    y: header.height
                    width: parent.width
                    height: parent.height - header.height
                    model: root.rows
                    // Best match at the bottom, next to the field.
                    verticalLayoutDirection: ListView.BottomToTop
                    currentIndex: root.selected
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: Motion.reduced ? 0 : Motion.hover
                    boundsBehavior: Flickable.StopAtBounds
                    highlight: Rectangle {
                        radius: Tokens.radius.menuItem + 2
                        color: Tokens.accent
                    }

                    delegate: Item {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool current: index === root.selected
                        width: listView.width
                        height: root.rowHeight

                        Item {
                            id: rowIcon
                            x: Tokens.space.s
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28

                            Image {
                                id: appIcon
                                anchors.fill: parent
                                // A missing themed icon still "loads", as an empty image.
                                visible: row.modelData.kind === "app" && status === Image.Ready && implicitWidth > 1
                                source: row.modelData.kind === "app" ? Apps.iconFor(row.modelData.entry) : ""
                                sourceSize: Qt.size(56, 56)
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                            Icon {
                                visible: !appIcon.visible
                                anchors.centerIn: parent
                                glyph: row.modelData.kind === "calc" ? Glyphs.equals : row.modelData.kind === "clip" ? Glyphs.clipboard : Glyphs.apps
                                size: 18
                                color: row.current ? "white" : Tokens.secondaryLabel
                            }
                        }

                        Text {
                            id: rowTitle
                            anchors.left: rowIcon.right
                            anchors.leftMargin: Tokens.space.m
                            anchors.right: rowSubtitle.left
                            anchors.rightMargin: Tokens.space.m
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.title
                            textFormat: Text.PlainText
                            maximumLineCount: 1
                            color: row.current ? "white" : Tokens.label
                            font.family: Tokens.family
                            font.pixelSize: row.modelData.kind === "calc" ? Tokens.type.title3.size + 2 : Tokens.type.body.size + 1
                            font.weight: row.modelData.kind === "calc" ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Text {
                            id: rowSubtitle
                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.space.m
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, row.width * 0.4)
                            text: row.modelData.subtitle
                            color: row.current ? Qt.rgba(1, 1, 1, 0.8) : Tokens.secondaryLabel
                            font.family: Tokens.family
                            font.pixelSize: Tokens.type.callout.size
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.selected = row.index
                            onClicked: root.run(row.modelData)
                        }
                    }
                }
            }
        }
    }
}
