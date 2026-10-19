import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
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
 *   Code), favorites first; with nothing typed, the most used apps and then
 *   every app by name. The list shows `maxRows` at a time and scrolls (wheel,
 *   ↑/↓) with an overlay scroll bar. An
 *   arithmetic expression shows its result first; Return copies it.
 * - Clipboard mode: the clipboard history (cliphist), newest first, filtered
 *   as you type; Return copies the entry back. The glass widens into two
 *   columns: the list, images with a thumbnail, and a preview of the chosen
 *   entry (pointer or ↑/↓) — the image fitted, or the whole text — over a
 *   line that says what it is.
 *
 * ↑/↓ move up/down the list, Return opens or copies, Tab switches mode, Esc or a click
 * outside closes. It materializes, as Liquid Glass does: the glass comes in
 * clear and lensing with a faint bloom, gains its veil as it settles (scale
 * 0.92 → 1 on the smooth spring) and the content shows once the glass is
 * mostly there; closing is quicker (`dismiss`), content first, then the glass
 * clears and fades.
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
        // Opening in the other mode: start at its width, not morphing to it.
        if (!visible)
            breadth.snap(breadth.to);
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
    /** How much of the material's veil is there (the glass comes in clear). */
    readonly property real presence: 0.3 + 0.7 * openness.value
    /** A faint bloom halfway through the materialization, gone at rest. */
    readonly property real bloom: 2 * openness.value * (1 - openness.value)
    /** The content: in once the glass is mostly formed, out first on close. */
    readonly property real focus: Math.max(0, (openness.value - 0.35) / 0.65)

    visible: wanted || !openness.settled
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-launcher"
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    SpringValue {
        id: breadth
        to: root.mode === "clipboard" ? 900 : 640
        preset: Motion.smooth
        epsilon: 0.5
    }
    readonly property real panelWidth: breadth.value
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
        for (const e of Apps.search(field.text, Infinity))
            list.push({ kind: "app", entry: e, title: e.name, subtitle: e.genericName || e.comment || "" });
        return list;
    }
    onRowsChanged: selected = Math.min(selected, Math.max(0, rows.length - 1))
    readonly property var current: rows[selected] ?? null

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
                    // "[[ binary data 501 KiB png 2816x1688 ]]"
                    const image = preview.match(/^\[\[ binary data (\S+ \S+) \S+ (\d+x\d+) \]\]$/);
                    out.push({
                        kind: "clip",
                        line,
                        id: line.slice(0, tab),
                        image: !!image,
                        size: image ? image[2].replace("x", "×") : "",
                        bytes: image ? image[1].replace("iB", "B") : "",
                        title: image ? I18n.tr("launcher.image", { size: image[2].replace("x", "×") }) : preview.trim(),
                        subtitle: ""
                    });
                }
                history.items = out;
                // shortcut: only the newest 100 entries get images (what an empty search lists); widen if searching old ones matters.
                thumbs.command = ["sh", "-c", thumbs.script, "_", thumbs.dir].concat(out.slice(0, 100).filter(i => i.image).map(i => i.line));
                thumbs.running = false;
                thumbs.running = true;
            }
        }
    }

    // The listed images, decoded once into a cache the thumbnails and the
    // preview read, newest first; each shows as soon as it's there. What's no
    // longer listed is dropped.
    Process {
        id: thumbs
        /** Ids whose image is in the cache. */
        property var decoded: ({})
        readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/aurora-clipboard"
        readonly property string script: 'd="$1"; shift; mkdir -p "$d" && cd "$d" || exit 1; ids=" "; '
            + 'for l in "$@"; do id=${l%%\t*}; ids="$ids$id "; '
            + '[ -s "$id" ] || { printf "%s" "$l" | cliphist decode > "$id.part" && mv "$id.part" "$id"; }; '
            + '[ -s "$id" ] && echo "$id"; done; '
            + 'for f in *; do case "$ids" in *" $f "*) ;; *) rm -f -- "$f";; esac; done'
        stdout: SplitParser {
            onRead: id => thumbs.decoded = Object.assign({}, thumbs.decoded, { [id]: true })
        }
    }
    function imageOf(row) {
        return row && row.image && thumbs.decoded[row.id] ? "file://" + thumbs.dir + "/" + row.id : "";
    }

    // The chosen text in full (the list only has cliphist's first line):
    // its length, then up to 20k of it.
    Process {
        id: fullText
        property string line: ""
        property int count: 0
        property string text: ""
        command: ["sh", "-c", 't=$(printf "%s" "$1" | cliphist decode); printf "%s\n" "${#t}"; printf "%s" "$t" | head -c 20000', "_", line]
        stdout: StdioCollector {
            onStreamFinished: {
                const nl = this.text.indexOf("\n");
                fullText.count = Number(this.text.slice(0, nl)) || 0;
                fullText.text = this.text.slice(nl + 1);
            }
        }
    }
    // Rows pass under the pointer quickly: decode the one it stays on.
    Timer {
        id: fullTextSoon
        interval: 60
        onTriggered: {
            fullText.running = false;
            fullText.running = true;
        }
    }
    onCurrentChanged: {
        if (mode !== "clipboard" || !current || current.image || current.line === fullText.line)
            return;
        fullText.line = current.line;
        fullText.text = current.title;
        fullText.count = current.title.length;
        fullTextSoon.restart();
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
        scale: 0.92 + 0.08 * openness.value
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
                presence: root.presence
                bloom: root.bloom
                track: [card.scale]
            }

            Icon {
                id: magnifier
                x: Tokens.space.xl
                anchors.verticalCenter: parent.verticalCenter
                glyph: Glyphs.magnifier
                size: 20
                opacity: root.focus
                color: Tokens.secondaryLabel
            }

            TextInput {
                id: field
                anchors.left: magnifier.right
                anchors.leftMargin: Tokens.space.m
                anchors.right: modes.left
                anchors.rightMargin: Tokens.space.m
                anchors.verticalCenter: parent.verticalCenter
                opacity: root.focus
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
                opacity: root.focus
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
            // The clipboard keeps its full height: the preview needs the room.
            readonly property int shownRows: root.mode === "clipboard" ? root.maxRows : Math.min(root.rows.length, root.maxRows)
            readonly property real wantedHeight: header.height + (root.rows.length ? shownRows * root.rowHeight : root.rowHeight) + Tokens.space.m * 2
            SpringValue { id: grow; to: results.wantedHeight; preset: Motion.smooth; epsilon: 0.5 }
            height: Math.max(1, grow.value)

            Glass {
                anchors.fill: parent
                backdrop: launcherBackdrop
                material: Tokens.glass.regular
                radius: 22
                presence: root.presence
                bloom: root.bloom
                track: [card.scale, results.height]
            }

            Item {
                anchors.fill: parent
                anchors.margins: Tokens.space.m
                opacity: root.focus
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
                    width: root.mode === "clipboard" ? Math.round(parent.width * 0.46) : parent.width
                    height: parent.height - header.height
                    model: root.rows
                    // Rows scrolled past the top stay under the section title.
                    clip: true
                    // Best match at the bottom, next to the field.
                    verticalLayoutDirection: ListView.BottomToTop
                    currentIndex: root.selected
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: Motion.reduced ? 0 : Motion.hover
                    boundsBehavior: Flickable.StopAtBounds
                    // ↑ into the hidden rows: keep the chosen one in view.
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: height
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

                            // An image clip: its thumbnail.
                            ClippingRectangle {
                                id: thumb
                                anchors.fill: parent
                                visible: thumbImage.status === Image.Ready
                                radius: 6
                                color: "transparent"
                                Image {
                                    id: thumbImage
                                    anchors.fill: parent
                                    source: root.imageOf(row.modelData)
                                    sourceSize: Qt.size(56, 56)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
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
                                visible: !appIcon.visible && !thumb.visible
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
                ScrollIndicator { flickable: listView; outside: false }

                // The chosen clip, in full.
                Item {
                    id: preview
                    visible: root.mode === "clipboard" && !!root.current
                    x: listView.width + Tokens.space.l
                    y: header.height
                    width: parent.width - x
                    height: parent.height - y

                    Rectangle {
                        x: -Tokens.space.l / 2
                        width: 1
                        height: parent.height
                        color: Tokens.separator
                    }

                    Item {
                        id: previewBody
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.space.s
                        anchors.rightMargin: Tokens.space.s
                        anchors.bottomMargin: previewInfo.height + Tokens.space.m

                        Image {
                            anchors.fill: parent
                            visible: !!root.current?.image
                            source: root.imageOf(root.current)
                            sourceSize: Qt.size(width * 2, height * 2)
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                        Text {
                            anchors.fill: parent
                            visible: !root.current?.image
                            text: root.current && fullText.line === root.current.line ? fullText.text : root.current?.title ?? ""
                            textFormat: Text.PlainText
                            wrapMode: Text.WrapAnywhere
                            elide: Text.ElideRight
                            color: Tokens.label
                            font.family: Tokens.family
                            font.pixelSize: Tokens.type.callout.size
                        }
                    }

                    // i18n-keys: launcher.previewText launcher.previewTextOne
                    Text {
                        id: previewInfo
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Tokens.space.xs
                        x: Tokens.space.s
                        width: parent.width - 2 * Tokens.space.s
                        text: !root.current ? ""
                            : root.current.image ? I18n.tr("launcher.previewImage", { size: root.current.size, bytes: root.current.bytes })
                            : I18n.tr(fullText.count === 1 ? "launcher.previewTextOne" : "launcher.previewText", { count: fullText.count })
                        color: Tokens.secondaryLabel
                        font.family: Tokens.family
                        font.pixelSize: Tokens.type.subheadline.size
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
