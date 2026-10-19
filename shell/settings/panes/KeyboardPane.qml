import QtQuick
import "../../core"
import "../../components"
import "../../services"
import "../../core/search.mjs" as Search
import "../../core/keys.mjs" as Chord
import ".."

/**
 * Keyboard: every shortcut, as macOS's Keyboard Shortcuts lists them —
 * grouped (windows, switching, desktops, apps, screenshots, system, media
 * keys), searchable, each with its keycaps. Click one and type the new
 * combination; a shortcut already in use asks before taking it over; a
 * changed one can be restored, or all at once. The user's own shortcuts
 * (a name and a command) are added with the button at the top, in the New
 * Shortcut modal (dialogs/ShortcutDialog), and changed and removed at the
 * end. The
 * switcher, media keys and mouse are listed but fixed. See services/Keybinds.
 */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.xl

    property string query: ""

    Component.onCompleted: Keybinds.refresh()
    Component.onDestruction: Keybinds.endRecording()

    // i18n-keys: settings.keys.group.window settings.keys.group.switcher settings.keys.group.workspace settings.keys.group.special settings.keys.group.app settings.keys.group.screenshot settings.keys.group.system settings.keys.group.media settings.keys.group.other
    readonly property var groups: [
        { key: "window", match: /^window\./ },
        { key: "switcher", match: /^switcher\./ },
        { key: "workspace", match: /^workspace\./ },
        { key: "special", match: /^(special|space)\./ },
        { key: "app", match: /^app\./ },
        { key: "screenshot", match: /^(screenshot|screen)\./ },
        { key: "system", match: /^system\./ },
        { key: "media", match: /^media\./ },
        { key: "other", match: /./ }
    ]

    // i18n-keys: keys.action.window.close keys.action.window.kill keys.action.window.fullscreen keys.action.window.float keys.action.window.minimize keys.action.window.minimized keys.action.window.drag keys.action.window.resize
    // i18n-keys: keys.action.switcher.next keys.action.switcher.previous keys.action.switcher.nextApp keys.action.switcher.cancel keys.action.switcher.commit
    // i18n-keys: keys.action.workspace.previous keys.action.workspace.next keys.action.workspace.scrollPrevious keys.action.workspace.scrollNext keys.action.workspace.go keys.action.workspace.send
    // i18n-keys: keys.action.special.private keys.action.special.privateSend keys.action.special.stash keys.action.special.stashSend keys.action.space.show keys.action.space.send
    // i18n-keys: keys.action.app.launcher keys.action.app.clipboard keys.action.app.terminal keys.action.app.files keys.action.app.colorPicker
    // i18n-keys: keys.action.screenshot.full keys.action.screenshot.monitor keys.action.screenshot.region keys.action.screenshot.monitorWindows keys.action.screen.record
    // i18n-keys: keys.action.system.lock keys.action.system.wallpaperPicker keys.action.system.wallpaperNext
    // i18n-keys: keys.action.media.volumeUp keys.action.media.volumeDown keys.action.media.mute keys.action.media.brightnessUp keys.action.media.brightnessDown keys.action.media.playPause keys.action.media.next keys.action.media.previous
    function nameOf(id) {
        let m = id.match(/^workspace\.(go|send)\.(\d+)$/);
        if (m)
            return I18n.tr("keys.action.workspace." + m[1], { n: m[2] });
        m = id.match(/^space\.(show|send)\.(.+)$/);
        if (m)
            return I18n.tr("keys.action.space." + m[1], { name: m[2].charAt(0).toUpperCase() + m[2].slice(1) });
        if (id.startsWith("run.")) {
            const o = Keybinds.own[Number(id.slice(4)) - 1];
            return o ? (o.name || o.command) : id;
        }
        const key = "keys.action." + id;
        const name = I18n.tr(key);
        return name === key ? id : name;
    }

    // i18n-keys: keys.cap.shift keys.cap.space keys.cap.return keys.cap.print keys.cap.backspace keys.cap.delete keys.cap.mouse272 keys.cap.mouse273 keys.cap.mouseup keys.cap.mousedown keys.cap.code64
    // i18n-keys: keys.cap.xf86audioraisevolume keys.cap.xf86audiolowervolume keys.cap.xf86audiomute keys.cap.xf86monbrightnessup keys.cap.xf86monbrightnessdown keys.cap.xf86audioplay keys.cap.xf86audionext keys.cap.xf86audioprev
    function capsText(keys) {
        return Chord.caps(keys, name => I18n.tr("keys.cap." + name)).join(" ");
    }

    function matches(id, keys) {
        const q = query.trim();
        if (!q.length)
            return true;
        return Search.score(nameOf(id), q, true) > 0 || capsText(keys).toLowerCase().includes(q.toLowerCase());
    }

    /** [{ key, rows: [{ id, keys }] }] for the built-in actions, filtered by the search. */
    readonly property var sections: {
        const taken = new Set();
        const out = [];
        for (const g of groups) {
            const rows = Keybinds.binds.filter(b => !b.id.startsWith("run.") && !taken.has(b.id) && g.match.test(b.id));
            rows.forEach(b => taken.add(b.id));
            // Built-in actions turned off aren't bound: list them from the changes.
            for (const id in Keybinds.changed)
                if (!taken.has(id) && Keybinds.changed[id] === "" && g.match.test(id)) {
                    rows.push({ id, keys: "" });
                    taken.add(id);
                }
            const shown = rows.filter(r => root.matches(r.id, r.keys));
            if (shown.length)
                out.push({ key: g.key, rows: shown });
        }
        return out;
    }

    /** A new combination for `id`: taken from another shortcut only after asking. */
    function choose(id, keys, field) {
        if (keys.length && Chord.same(keys, Keybinds.keysOf(id)))
            return;
        const other = Keybinds.usedBy(keys, id);
        if (!other) {
            Keybinds.set(id, keys);
            return;
        }
        if (Keybinds.isFixed(other)) {
            field.say(I18n.tr("settings.keys.taken", { name: nameOf(other) }));
            return;
        }
        Dialogs.confirm({
            title: I18n.tr("settings.keys.conflictTitle", { keys: capsText(keys) }),
            message: I18n.tr("settings.keys.conflictMessage", { other: nameOf(other), name: nameOf(id) }),
            action: I18n.tr("settings.keys.replace"),
            run: () => {
                const map = {};
                map[other] = "";
                map[id] = keys;
                Keybinds.setMany(map);
            }
        });
    }

    component LinkButton: Text {
        id: link
        signal clicked()
        color: hover.containsMouse ? Qt.lighter(Tokens.accent, 1.15) : Tokens.accent
        font.family: Tokens.family
        font.pixelSize: Tokens.type.subheadline.size
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        MouseArea {
            id: hover
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: link.clicked()
        }
    }

    // The search, how to change a shortcut (ⓘ), and adding one.
    Item {
        width: parent.width
        height: Math.max(search.height, addButton.height)
        SearchField {
            id: search
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(parent.width - addButton.width - keysInfo.width - 2 * Tokens.space.l, 320)
            placeholder: I18n.tr("settings.keys.search")
            onTextChanged: root.query = text
        }
        InfoButton {
            id: keysInfo
            anchors.left: search.right
            anchors.leftMargin: Tokens.space.m
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("settings.keys.note")
        }
        Button {
            id: addButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("settings.keys.add")
            onClicked: Dialogs.addShortcut()
        }
    }

    Repeater {
        model: root.sections
        delegate: SettingsGroup {
            id: section
            required property var modelData
            readonly property bool fixedGroup: modelData.rows.every(r => Keybinds.isFixed(r.id))
            title: I18n.tr("settings.keys.group." + modelData.key)
            footer: fixedGroup ? I18n.tr("settings.keys.fixedNote") : ""
            Repeater {
                model: section.modelData.rows
                delegate: SettingsRow {
                    id: row
                    required property var modelData
                    readonly property bool fixed: Keybinds.isFixed(modelData.id)
                    title: root.nameOf(modelData.id)
                    LinkButton {
                        visible: !row.fixed && Keybinds.isChanged(row.modelData.id)
                        text: I18n.tr("settings.keys.restore")
                        onClicked: Keybinds.reset(row.modelData.id)
                    }
                    ShortcutField {
                        id: field
                        keys: row.modelData.keys
                        fixed: row.fixed
                        onChosen: keys => root.choose(row.modelData.id, keys, field)
                    }
                }
            }
        }
    }

    // --- The user's own ----------------------------------------------------------

    SettingsGroup {
        id: ownGroup
        visible: ownRows.count > 0
        title: I18n.tr("settings.keys.group.own")

        Repeater {
            id: ownRows
            model: Keybinds.own.map((o, i) => ({ id: "run." + (i + 1), o })).filter(r => root.matches(r.id, r.o.keys))
            delegate: SettingsRow {
                id: ownRow
                required property var modelData
                title: modelData.o.name || modelData.o.command
                subtitle: modelData.o.name ? modelData.o.command : ""
                LinkButton {
                    text: I18n.tr("settings.keys.remove")
                    color: Tokens.destructive
                    onClicked: Keybinds.removeOwn(ownRow.modelData.id)
                }
                ShortcutField {
                    id: ownField
                    keys: ownRow.modelData.o.keys
                    onChosen: keys => root.choose(ownRow.modelData.id, keys, ownField)
                }
            }
        }

    }

    SettingsGroup {
        visible: Object.keys(Keybinds.changed).length > 0 && !root.query.trim().length
        SettingsRow {
            title: I18n.tr("settings.keys.restoreAll")
            Button {
                text: I18n.tr("settings.keys.restore")
                onClicked: Dialogs.confirm({
                    title: I18n.tr("settings.keys.restoreAllTitle"),
                    message: I18n.tr("settings.keys.restoreAllMessage"),
                    action: I18n.tr("settings.keys.restore"),
                    run: () => Keybinds.resetAll()
                })
            }
        }
    }
}
