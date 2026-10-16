import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../components"

/**
 * A macOS confirmation alert for actions that need one (Restart…, Shut
 * Down…, Log Out…): centered on the focused screen, regular glass, aurora's
 * mark, the question in bold, an explanation, and Cancel / the action. A
 * destructive action's button is red. With a countdown it runs the action
 * when the count reaches zero, like macOS's 60-second restart alert.
 * Return confirms, Esc cancels.
 */
PanelWindow {
    id: dialog

    readonly property var request: Dialogs.confirmation
    readonly property bool wanted: request !== null
    /** Kept while the close animation plays. */
    property var shown: ({})
    property int left: 0

    onRequestChanged: if (request) {
        shown = request;
        left = request.seconds ?? 0;
    }

    screen: {
        const focused = Hyprland.focusedMonitor;
        for (const s of Quickshell.screens)
            if (focused && s.name === focused.name)
                return s;
        return Quickshell.screens[0];
    }

    Timer {
        interval: 1000
        repeat: true
        running: dialog.wanted && dialog.left > 0
        onTriggered: {
            dialog.left -= 1;
            if (dialog.left === 0)
                Dialogs.resolve(true);
        }
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

    readonly property real margin: 48

    GlassBackdrop {
        id: dialogBackdrop
        screen: dialog.screen
        origin: Qt.point((dialog.screen.width - dialog.implicitWidth) / 2, (dialog.screen.height - dialog.implicitHeight) / 2)
        region: Qt.rect(origin.x + card.x, origin.y + card.y, card.width, card.height)
    }

    FocusScope {
        anchors.fill: parent
        focus: dialog.wanted

        Keys.onEscapePressed: Dialogs.resolve(false)
        Keys.onReturnPressed: Dialogs.resolve(true)
        Keys.onEnterPressed: Dialogs.resolve(true)

        Item {
            id: card
            x: dialog.margin
            y: dialog.margin
            width: 300
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
                        glyph: Glyphs.aurora
                        color: "white"
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: dialog.shown.title ?? ""
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.headline.size
                    font.weight: Font.Bold
                }

                Text {
                    visible: text.length > 0
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: (dialog.shown.message ?? "").split("{seconds}").join(String(dialog.left))
                    color: Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.callout.size
                }

                Row {
                    width: parent.width
                    spacing: Tokens.space.m
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        text: I18n.tr("common.cancel")
                        onClicked: Dialogs.resolve(false)
                    }
                    Button {
                        id: actionButton
                        width: (parent.width - parent.spacing) / 2
                        text: dialog.shown.action ?? ""
                        isDefault: true
                        onClicked: Dialogs.resolve(true)
                    }
                }
            }
        }
    }
}
