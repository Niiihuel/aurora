import QtQuick
import "../core"
import "../services"
import "../core/keys.mjs" as Chord

/**
 * A shortcut in Settings: its keycaps (or "Off"), and, unless `fixed`, a
 * click to record a new one, as macOS's Keyboard Shortcuts does. While
 * recording it takes the keyboard (and Keybinds pauses Hyprland's own
 * shortcuts), shows "Type the shortcut…" in an accent ring, and reads the
 * next combination: Escape cancels, Backspace or Delete turns it off, a key
 * that can't be a shortcut says why for a moment. Losing focus cancels.
 * `chosen(keys)` hands over the new keys ("" = off); the owner decides.
 */
Item {
    id: root

    property string keys: ""
    property bool fixed: false
    /** What an empty one says: "Off" in a list, "Choose shortcut" in a form. */
    property string emptyText: I18n.tr("settings.keys.off")
    property bool emptyIsAction: false
    /** A message to show for a moment instead of the keycaps. */
    property string note: ""
    readonly property bool recording: input.activeFocus
    signal chosen(string keys)

    implicitWidth: Math.max(64, (recording || note.length ? message.implicitWidth : row.implicitWidth) + 2 * Tokens.space.s)
    implicitHeight: 24

    function record() {
        if (fixed)
            return;
        input.forceActiveFocus();
    }
    function say(text) {
        note = text;
        noteTimer.restart();
    }

    Timer {
        id: noteTimer
        interval: 1800
        onTriggered: root.note = ""
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: 9
        color: "transparent"
        border.width: 3
        border.color: Qt.alpha(Tokens.accent, 0.5)
        visible: root.recording
    }
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.recording ? (Tokens.dark ? Qt.rgba(1, 1, 1, 0.08) : "white") : "transparent"
        border.width: root.recording ? 1 : 0
        border.color: Tokens.separator
    }

    Row {
        id: row
        visible: !root.recording && !root.note.length
        anchors.right: parent.right
        anchors.rightMargin: Tokens.space.s
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        opacity: root.fixed ? 0.6 : 1

        Text {
            visible: !root.keys.length
            text: root.emptyText
            color: root.emptyIsAction ? Tokens.accent : Tokens.tertiaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.subheadline.size
        }
        Repeater {
            model: root.keys.length ? Chord.caps(root.keys, name => I18n.tr("keys.cap." + name)) : []
            delegate: Rectangle {
                required property string modelData
                width: Math.max(height, cap.implicitWidth + 10)
                height: 20
                radius: 5
                color: Tokens.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
                border.width: Tokens.dark ? 0 : 1
                border.color: Tokens.separator
                Text {
                    id: cap
                    anchors.centerIn: parent
                    text: modelData
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.footnote.size
                    font.weight: Font.Medium
                }
            }
        }
    }

    Text {
        id: message
        visible: root.recording || root.note.length > 0
        anchors.centerIn: parent
        text: root.note.length ? root.note : I18n.tr("settings.keys.recording")
        color: root.note.length ? Tokens.destructive : Tokens.secondaryLabel
        font.family: Tokens.family
        font.pixelSize: Tokens.type.subheadline.size
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.fixed
        cursorShape: root.fixed ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: root.recording ? input.focus = false : root.record()
    }

    // The keyboard while recording.
    // i18n-keys: settings.keys.needsModifier settings.keys.badKey
    Item {
        id: input
        onActiveFocusChanged: activeFocus ? Keybinds.beginRecording() : Keybinds.endRecording()
        Keys.onPressed: event => {
            event.accepted = true;
            const r = Chord.fromEvent(event.key, event.modifiers, event.nativeScanCode);
            if (r.pending)
                return;
            input.focus = false;
            if (r.cancel)
                return;
            if (r.clear)
                root.chosen("");
            else if (r.keys)
                root.chosen(r.keys);
            else
                root.say(I18n.tr(r.error === "modifier" ? "settings.keys.needsModifier" : "settings.keys.badKey"));
        }
    }
}
