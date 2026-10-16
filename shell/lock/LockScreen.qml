import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../core"
import "../components"
import "../services"

/**
 * One screen of the lock, after macOS Tahoe: the wallpaper, the date over a
 * big clock of frosted glass numerals, Now Playing below it when something
 * plays, Wi-Fi and battery on the top right, and at the bottom the user's
 * picture, name and a password capsule of liquid glass. Like macOS, the
 * wallpaper is sharp at rest and blurs as soon as you touch a key or the
 * pointer (so the field reads first), clearing again after a while without
 * input; a wrong password shakes the field and clears it.
 *
 * Only the `primary` screen asks for the password; the others show the
 * wallpaper and the clock. `leaving` plays the unlock: everything fades and
 * the wallpaper settles, then the owner releases the lock.
 */
Item {
    id: root

    required property ShellScreen screen
    property bool primary: true
    required property Item auth
    property bool leaving: false

    signal cancelled()

    function rejected() {
        field.text = "";
        shake.restart();
        wrong = true;
    }
    property bool wrong: false

    /** Someone is at the keyboard or mouse: the wallpaper blurs. */
    property bool awake: false
    function wake() {
        awake = true;
        sleepTimer.restart();
    }
    Timer {
        id: sleepTimer
        interval: 10000
        onTriggered: {
            if (field.text.length)
                restart();
            else
                root.awake = false;
        }
    }

    Component.onCompleted: if (primary) field.forceActiveFocus()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // --- The wallpaper ----------------------------------------------------------------

    Image {
        id: wallpaper
        anchors.fill: parent
        source: {
            const path = Wallpaper.pathFor(root.screen.name);
            return path.length ? "file://" + path : "";
        }
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        scale: root.leaving ? 1 : 1.03
        Behavior on scale { NumberAnimation { duration: 420; easing.type: Motion.easeOut } }
    }

    // Typing pulls the wallpaper out of focus, so the field reads first.
    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        scale: wallpaper.scale
        blurEnabled: true
        blurMax: 48
        blur: 1
        brightness: -0.08
        opacity: root.awake && !root.leaving ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Motion.easeOut } }
    }

    GlassBackdrop {
        id: lockBackdrop
        screen: root.screen
        captureWindows: false
        region: Qt.rect(0, 0, root.width, root.height)
    }

    // --- Everything on top fades out when unlocking ------------------------------------------

    Item {
        anchors.fill: parent
        opacity: root.leaving ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.InQuad } }

        // Wi-Fi and battery, as on the Mac's lock screen.
        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Tokens.space.xl
            spacing: Tokens.space.l

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                glyph: NetworkStatus.kind === "wired" ? Glyphs.ethernet
                     : NetworkStatus.kind === "wifi" ? Glyphs.wifi(NetworkStatus.bars)
                     : NetworkStatus.kind === "wifi-off" ? Glyphs.wifiOff : Glyphs.wifi(0)
                color: "white"
                dimColor: Qt.rgba(1, 1, 1, 0.35)
            }
            Row {
                visible: BatteryStatus.present
                spacing: Tokens.space.xs
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("common.percent", { n: Math.round(BatteryStatus.level * 100) })
                    color: "white"
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                    font.features: ({ "tnum": 1 })
                }
                BatteryIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    level: BatteryStatus.level
                    charging: BatteryStatus.charging
                    low: BatteryStatus.low
                }
            }
        }

        // The date and the clock.
        Column {
            id: header
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.09)
            spacing: -Tokens.space.m

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const s = I18n.locale.toString(clock.date, "dddd, d 'de' MMMM");
                    return s.charAt(0).toUpperCase() + s.slice(1);
                }
                color: Qt.rgba(1, 1, 1, 0.92)
                font.family: Tokens.family
                font.pixelSize: Tokens.type.title2.size + 3
                font.weight: Font.DemiBold
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowOpacity: 0.45 }
            }

            // Frosted glass numerals: the glass, cut to the digits' shape.
            Item {
                id: time
                anchors.horizontalCenter: parent.horizontalCenter
                width: digits.implicitWidth
                height: digits.implicitHeight

                Text {
                    id: digits
                    visible: false
                    layer.enabled: true
                    text: I18n.locale.toString(clock.date, "H:mm")
                    color: "white"
                    font.family: Tokens.family
                    font.pixelSize: Math.round(root.height * 0.15)
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                }
                Glass {
                    id: frost
                    anchors.fill: parent
                    backdrop: lockBackdrop
                    material: Tokens.glass.clock
                    radius: 0
                    edge: false
                    shadow: false
                    track: [time.x, header.y, digits.text]
                    // Cut to the digits: the mask is applied to this glass's own layer.
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: digits
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 0.5
                    }
                }
                // The lit rim along the numerals' edges.
                Text {
                    anchors.fill: parent
                    text: digits.text
                    font: digits.font
                    color: "transparent"
                    style: Text.Outline
                    styleColor: Qt.rgba(1, 1, 1, 0.5)
                }
                // Depth: a soft shade under the numerals keeps them legible on bright wallpapers.
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowBlur: 0.8
                    shadowOpacity: 0.35
                    shadowVerticalOffset: 2
                }
            }
        }

        // Now Playing, when something plays.
        Item {
            visible: MediaStatus.present && root.primary
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: header.bottom
            anchors.topMargin: Tokens.space.xxl
            width: 344
            height: 76

            Glass {
                anchors.fill: parent
                backdrop: lockBackdrop
                material: Tokens.glass.regular
                radius: Tokens.radius.banner
                shadow: false
                track: [parent.y]
            }
            ClippingRectangle {
                id: art
                x: Tokens.space.l
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                height: 48
                radius: 10
                color: Tokens.toggleOff
                Image {
                    anchors.fill: parent
                    source: MediaStatus.art
                    sourceSize: Qt.size(96, 96)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                anchors.left: art.right
                anchors.leftMargin: Tokens.space.l
                anchors.right: controls.left
                anchors.rightMargin: Tokens.space.m
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: parent.width
                    text: MediaStatus.title
                    color: "white"
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: MediaStatus.artist
                    color: Qt.rgba(1, 1, 1, 0.7)
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.callout.size
                    elide: Text.ElideRight
                }
            }
            Row {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: Tokens.space.l
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.space.m
                Repeater {
                    model: [
                        { glyph: Glyphs.backward, act: () => MediaStatus.previous() },
                        { glyph: MediaStatus.playing ? Glyphs.pause : Glyphs.play, act: () => MediaStatus.toggle() },
                        { glyph: Glyphs.forward, act: () => MediaStatus.next() }
                    ]
                    delegate: Item {
                        required property var modelData
                        width: 26
                        height: 26
                        Icon {
                            anchors.centerIn: parent
                            glyph: modelData.glyph
                            size: 16
                            color: "white"
                            scale: tap.pressed ? 0.88 : 1
                        }
                        MouseArea {
                            id: tap
                            anchors.fill: parent
                            onClicked: modelData.act()
                        }
                    }
                }
            }
        }

        // The user and the password.
        Column {
            visible: root.primary
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(root.height * 0.1)
            spacing: Tokens.space.m

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64
                height: 64
                Glass {
                    anchors.fill: parent
                    backdrop: lockBackdrop
                    material: Tokens.glass.regular
                    radius: width / 2
                    track: [parent.y]
                }
                Text {
                    anchors.centerIn: parent
                    text: who.name.charAt(0).toUpperCase()
                    color: "white"
                    font.family: Tokens.family
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: who.name
                color: "white"
                font.family: Tokens.family
                font.pixelSize: Tokens.type.title3.size
                font.weight: Font.DemiBold
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowOpacity: 0.5 }
            }

            Item {
                id: capsule
                anchors.horizontalCenter: parent.horizontalCenter
                width: 220
                height: 34
                opacity: root.auth.busy ? 0.6 : 1

                property real shakeX: 0
                transform: Translate { x: capsule.shakeX }
                // macOS's wrong-password shake.
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: capsule; property: "shakeX"; to: -12; duration: 50; easing.type: Easing.OutQuad }
                    NumberAnimation { target: capsule; property: "shakeX"; to: 10; duration: 80; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: capsule; property: "shakeX"; to: -7; duration: 70; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: capsule; property: "shakeX"; to: 4; duration: 60; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: capsule; property: "shakeX"; to: 0; duration: 50; easing.type: Easing.InQuad }
                }

                Glass {
                    anchors.fill: parent
                    backdrop: lockBackdrop
                    material: Tokens.glass.regular
                    radius: height / 2
                    track: [parent.y, capsule.shakeX]
                }

                TextInput {
                    id: field
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.space.l
                    anchors.right: submit.left
                    anchors.rightMargin: Tokens.space.s
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: "white"
                    selectionColor: Tokens.accent
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                    enabled: !root.auth.busy && !root.leaving
                    clip: true
                    onTextChanged: {
                        if (text.length)
                            root.wrong = false;
                        root.wake();
                    }
                    Keys.onPressed: root.wake()

                    Text {
                        visible: !field.text.length
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("lock.password")
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font: field.font
                    }

                    Keys.onReturnPressed: root.auth.submit(field.text)
                    Keys.onEnterPressed: root.auth.submit(field.text)
                    Keys.onEscapePressed: {
                        if (field.text.length)
                            field.text = "";
                        else
                            root.cancelled();
                    }
                }

                // The arrow appears once there's something to send.
                Item {
                    id: submit
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    opacity: field.text.length ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Motion.hover } }

                    Glass {
                        anchors.fill: parent
                        backdrop: lockBackdrop
                        material: Tokens.glass.toggleOn
                        radius: width / 2
                        shadow: false
                        track: [capsule.y, capsule.shakeX]
                    }
                    Icon {
                        anchors.centerIn: parent
                        glyph: Glyphs.arrowRight
                        size: 13
                        stroke: 2
                        color: Tokens.accent
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: field.text.length > 0
                        onClicked: root.auth.submit(field.text)
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.tr("lock.wrong")
                color: Qt.rgba(1, 1, 1, 0.8)
                font.family: Tokens.family
                font.pixelSize: Tokens.type.callout.size
                opacity: root.wrong ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.quick } }
            }
        }
    }

    // A click anywhere gives the field its focus back.
    MouseArea {
        anchors.fill: parent
        z: -1
        hoverEnabled: true
        onPositionChanged: root.wake()
        onPressed: {
            root.wake();
            if (root.primary)
                field.forceActiveFocus();
        }
    }

    // The user's display name (GECOS), else the login name, capitalized.
    Process {
        id: who
        property string name: {
            const u = root.auth.user;
            return u.charAt(0).toUpperCase() + u.slice(1);
        }
        running: true
        command: ["getent", "passwd", root.auth.user]
        stdout: StdioCollector {
            onStreamFinished: {
                const gecos = (this.text.split(":")[4] || "").split(",")[0].trim();
                if (gecos.length)
                    who.name = gecos.charAt(0).toUpperCase() + gecos.slice(1);
            }
        }
    }
}
