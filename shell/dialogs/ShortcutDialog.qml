import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../components"
import "../services"
import "../settings"

/**
 * "New Shortcut", from Settings' Keyboard page: a modal like the Wi-Fi
 * password prompt — centered on the focused screen, regular glass, the
 * keyboard mark, the title in bold — with a name, the command to run and
 * the keys (click and type them; a combination already in use says by
 * what). Cancel / Add: Add is the default (Return), Esc cancels (while the
 * keys are being recorded, Esc only stops recording).
 */
PanelWindow {
    id: dialog

    readonly property bool wanted: Dialogs.shortcutForm
    property string keys: ""
    onWantedChanged: if (wanted) {
        name.text = "";
        command.text = "";
        keys = "";
        Qt.callLater(name.focusField);
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
        to: dialog.wanted ? 1 : 0
        preset: dialog.wanted ? Motion.smooth : Motion.dismiss
    }

    visible: wanted || !openness.settled
    implicitWidth: card.width + 2 * margin
    implicitHeight: card.height + 2 * margin
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-dialog"
    WlrLayershell.keyboardFocus: wanted ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    /** Room around the card for its shadow. */
    readonly property real margin: 48
    readonly property bool ready: command.text.trim().length > 0

    function add() {
        if (!ready)
            return;
        Keybinds.addOwn(keys, name.text, command.text);
        Dialogs.shortcutForm = false;
    }

    GlassBackdrop {
        id: dialogBackdrop
        screen: dialog.screen
        origin: Qt.point((dialog.screen.width - dialog.implicitWidth) / 2, (dialog.screen.height - dialog.implicitHeight) / 2)
        region: Qt.rect(origin.x + card.x, origin.y + card.y, card.width, card.height)
    }

    FocusScope {
        anchors.fill: parent
        focus: dialog.wanted

        Keys.onEscapePressed: Dialogs.shortcutForm = false

        Item {
            id: card
            x: dialog.margin
            y: dialog.margin
            width: 340
            height: content.implicitHeight + 2 * Tokens.space.xxl
            opacity: openness.value
            scale: 0.94 + 0.06 * openness.value

            Glass {
                anchors.fill: parent
                backdrop: dialogBackdrop
                material: Tokens.glass.regular
                radius: Tokens.radius.dialog
                track: [card.scale]
            }

            Column {
                id: content
                x: Tokens.space.xxl
                y: Tokens.space.xxl
                width: card.width - 2 * Tokens.space.xxl
                spacing: Tokens.space.l

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 48; height: 48; radius: 24
                    color: Tokens.accent
                    Icon {
                        anchors.centerIn: parent
                        size: 26
                        glyph: Glyphs.keyboard
                        color: "white"
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: I18n.tr("settings.keys.newTitle")
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.headline.size
                    font.weight: Font.Bold
                }

                TextField {
                    id: name
                    width: parent.width
                    placeholder: I18n.tr("settings.keys.name")
                    onAccepted: command.focusField()
                }

                TextField {
                    id: command
                    width: parent.width
                    placeholder: I18n.tr("settings.keys.command")
                    onAccepted: dialog.add()
                }

                Item {
                    width: parent.width
                    height: 28
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("settings.keys.shortcut")
                        color: Tokens.label
                        font.family: Tokens.family
                        font.pixelSize: Tokens.type.body.size
                    }
                    ShortcutField {
                        id: field
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        keys: dialog.keys
                        emptyText: I18n.tr("settings.keys.choose")
                        emptyIsAction: true
                        onChosen: keys => {
                            const other = Keybinds.usedBy(keys, "");
                            if (other)
                                field.say(I18n.tr("settings.keys.takenShort"));
                            else
                                dialog.keys = keys;
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: Tokens.space.m
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        text: I18n.tr("common.cancel")
                        onClicked: Dialogs.shortcutForm = false
                    }
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        text: I18n.tr("settings.keys.addButton")
                        isDefault: true
                        enabled: dialog.ready
                        onClicked: dialog.add()
                    }
                }
            }
        }
    }
}
