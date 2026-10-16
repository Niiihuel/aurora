import QtQuick
import Quickshell.Widgets
import "../core"
import "../services"

/**
 * One notification on its own liquid glass, after macOS: the app's icon, the
 * title in bold with its age on the trailing side, the body (two lines, all
 * of it while hovered) and, when the sender attached a picture as well as
 * having an icon, that picture as a thumbnail. Hovering shows the close
 * button on the corner and the actions as glass capsules. A click runs the
 * default action (opens the app).
 *
 * Used for banners and in the Notification Center. `track` carries whatever
 * moves the card on screen (slide, scroll) so its glass re-maps.
 */
Item {
    id: root

    required property var notification
    property Item backdrop: null
    property var track: []
    /** Current time, for the age; the owner ticks it. */
    property real now: Date.now()

    readonly property bool hovered: hover.hovered
    readonly property string icon: Notifications.appIcon(notification)
    // A themed icon passed as the image is the app's icon (see appIcon), not a picture.
    readonly property string picture: (notification.image || "").startsWith("image://icon/") ? "" : (notification.image || "")
    readonly property var buttons: Notifications.buttons(notification)
    readonly property real pad: Tokens.space.l

    width: 344
    implicitHeight: Math.max(icon32.height, textColumn.implicitHeight) + 2 * pad + (actions.visible ? actions.height + Tokens.space.m : 0)
    height: implicitHeight

    HoverHandler { id: hover }

    Glass {
        anchors.fill: parent
        backdrop: root.backdrop
        material: Tokens.glass.regular
        radius: Tokens.radius.banner
        held: tap.pressed
        track: [root.track, root.width, root.height]
    }

    MouseArea {
        id: tap
        anchors.fill: parent
        onClicked: Notifications.activate(root.notification)
    }

    // The app: its icon, else the picture, else a bell. App icons come
    // shaped already, so no clipping (a transparent ClippingRectangle hid them).
    Item {
        id: icon32
        x: root.pad
        y: root.pad
        width: 32
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Tokens.toggleOff
            visible: appImage.status !== Image.Ready || appImage.implicitWidth <= 1
        }

        Image {
            id: appImage
            anchors.fill: parent
            source: root.icon.length ? root.icon : root.picture
            sourceSize: Qt.size(64, 64)
            fillMode: Image.PreserveAspectFit
        }
        Icon {
            visible: appImage.status !== Image.Ready || appImage.implicitWidth <= 1
            anchors.centerIn: parent
            glyph: Glyphs.bell
            size: 18
        }
    }

    ClippingRectangle {
        id: thumb
        visible: root.icon.length > 0 && root.picture.length > 0
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        y: root.pad
        width: visible ? 40 : 0
        height: 40
        radius: 8
        color: Tokens.toggleOff
        Image {
            anchors.fill: parent
            source: thumb.visible ? root.picture : ""
            sourceSize: Qt.size(80, 80)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        id: textColumn
        anchors.left: icon32.right
        anchors.leftMargin: Tokens.space.m + 2
        anchors.right: thumb.visible ? thumb.left : parent.right
        anchors.rightMargin: thumb.visible ? Tokens.space.m : root.pad
        y: root.pad - 1
        spacing: 1

        Item {
            width: parent.width
            height: title.implicitHeight

            Text {
                id: title
                anchors.left: parent.left
                anchors.right: age.left
                anchors.rightMargin: Tokens.space.s
                text: root.notification.summary || root.notification.appName
                color: Tokens.label
                font.family: Tokens.family
                font.pixelSize: Tokens.type.body.size
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                id: age
                anchors.right: parent.right
                anchors.baseline: title.baseline
                text: Notifications.age(root.notification, root.now)
                color: Tokens.secondaryLabel
                font.family: Tokens.family
                font.pixelSize: Tokens.type.subheadline.size
            }
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: root.notification.body
            textFormat: Text.PlainText
            color: Tokens.label
            font.family: Tokens.family
            font.pixelSize: Tokens.type.callout.size
            wrapMode: Text.Wrap
            maximumLineCount: root.hovered ? 8 : 2
            elide: Text.ElideRight
        }
    }

    Row {
        id: actions
        visible: root.hovered && root.buttons.length > 0
        anchors.left: textColumn.left
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.pad
        height: 26
        spacing: Tokens.space.s

        Repeater {
            model: root.buttons
            delegate: Item {
                id: button
                required property var modelData
                width: Math.min(label.implicitWidth + 2 * Tokens.space.l, (actions.width - (root.buttons.length - 1) * actions.spacing) / root.buttons.length)
                height: actions.height

                Glass {
                    anchors.fill: parent
                    backdrop: root.backdrop
                    material: Tokens.glass.regularSmall
                    radius: height / 2
                    shadow: false
                    held: press.pressed
                    track: [root.track, button.x, actions.y, root.hovered]
                }
                Text {
                    id: label
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 2 * Tokens.space.m)
                    text: button.modelData.text
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.callout.size
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                MouseArea {
                    id: press
                    anchors.fill: parent
                    onClicked: {
                        button.modelData.invoke();
                        if (!root.notification.resident)
                            Notifications.dismiss(root.notification);
                    }
                }
            }
        }
    }

    // Close, on the corner while hovered (macOS puts it top-left).
    Item {
        visible: root.hovered
        x: -6
        y: -6
        width: 20
        height: 20

        Glass {
            anchors.fill: parent
            backdrop: root.backdrop
            material: Tokens.glass.regularSmall
            radius: width / 2
            shadow: false
            track: [root.track, root.hovered]
        }
        Icon {
            anchors.centerIn: parent
            glyph: Glyphs.xmark
            size: 10
            stroke: 2
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -2
            onClicked: Notifications.dismiss(root.notification)
        }
    }
}
