import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../core"
import "../components"
import "../services"

/**
 * The Wi-Fi password prompt, after macOS's: centered on the focused screen,
 * regular glass, the Wi-Fi mark, the request in bold, a password field with
 * "Show password", and Cancel / Join (Join is the default: Return; Esc
 * cancels). It appears with a short zoom-and-fade on the smooth spring and
 * leaves on the dismiss spring. NetworkManager keeps the network once joined.
 *
 * An unanchored layer surface is centered by the compositor, which is how the
 * dialog lands in the middle; `origin` mirrors that so the glass maps right.
 */
PanelWindow {
    id: dialog

    readonly property var network: Dialogs.wifiNetwork
    readonly property bool wanted: network !== null
    /** Kept while the close animation plays. */
    property string networkName: ""
    onNetworkChanged: if (network) {
        networkName = network.name;
        field.text = "";
        show.checked = false;
        Qt.callLater(field.focusField);
        if (Dialogs.wifiRejected)
            shake.restart();
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

    function join() {
        if (!network || field.text.length === 0)
            return;
        NetworkStatus.joinWithPassword(network, field.text);
        Dialogs.watchJoin(network);
        Dialogs.dismiss();
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

        Keys.onEscapePressed: Dialogs.dismiss()

        Item {
            id: card
            x: dialog.margin
            y: dialog.margin
            width: 300
            height: content.implicitHeight + 2 * Tokens.space.xxl
            opacity: openness.value
            scale: 0.94 + 0.06 * openness.value

            // macOS's "wrong password" shake: a quick side-to-side that dies out.
            property real shakeX: 0
            transform: Translate { x: card.shakeX }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: card; property: "shakeX"; to: -12; duration: 50; easing.type: Easing.OutQuad }
                NumberAnimation { target: card; property: "shakeX"; to: 10; duration: 80; easing.type: Easing.InOutQuad }
                NumberAnimation { target: card; property: "shakeX"; to: -7; duration: 70; easing.type: Easing.InOutQuad }
                NumberAnimation { target: card; property: "shakeX"; to: 4; duration: 60; easing.type: Easing.InOutQuad }
                NumberAnimation { target: card; property: "shakeX"; to: 0; duration: 50; easing.type: Easing.InQuad }
            }

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
                        glyph: Glyphs.wifi(3)
                        color: "white"
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: I18n.tr("network.passwordTitle", { name: dialog.networkName })
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.headline.size
                    font.weight: Font.Bold
                }

                Text {
                    visible: Dialogs.wifiRejected
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: I18n.tr("network.wrongPassword")
                    color: Tokens.destructive
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.callout.size
                }

                TextField {
                    id: field
                    width: parent.width
                    placeholder: I18n.tr("network.password")
                    secret: !show.checked
                    onAccepted: dialog.join()
                }

                CheckBox {
                    id: show
                    text: I18n.tr("network.showPassword")
                    onToggled: on => show.checked = on
                }

                Row {
                    width: parent.width
                    spacing: Tokens.space.m
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        text: I18n.tr("common.cancel")
                        onClicked: Dialogs.dismiss()
                    }
                    Button {
                        width: (parent.width - parent.spacing) / 2
                        text: I18n.tr("network.join")
                        isDefault: true
                        enabled: field.text.length > 0
                        onClicked: dialog.join()
                    }
                }
            }
        }
    }
}
