import QtQuick
import QtQuick.Effects
import "strings.js" as Strings

/**
 * aurora's login screen (SDDM), the lock screen's sibling (shell/lock/
 * LockScreen.qml), after macOS Tahoe's login window: the wallpaper, the date
 * over a big clock, and at the bottom the user's initial, name and a
 * password capsule of liquid glass, with Sleep, Restart and Shut Down under
 * it. Typing pulls the wallpaper out of focus so the field reads first; a
 * wrong password shakes the field and clears it.
 *
 * The greeter can't read $HOME: aurora publishes the wallpaper to
 * /var/lib/aurora/login (theme.conf `background`), and nix/login.nix bakes
 * in the language and the strings from shell/i18n.
 */
Item {
    id: root

    width: 1440
    height: 900

    readonly property string lang: config.language || "en"
    function tr(key) {
        return Strings.tr(lang, key);
    }

    readonly property bool primary: typeof primaryScreen === "undefined" || primaryScreen
    property string user: userModel.lastUser
    property string realName: ""
    property bool busy: false
    property bool wrong: false
    property bool leaving: false

    /** Someone is at the keyboard or mouse: the wallpaper blurs. */
    property bool awake: false
    function wake() {
        awake = true;
        sleepTimer.restart();
    }
    Timer {
        id: sleepTimer
        interval: 10000
        onTriggered: field.text.length ? restart() : root.awake = false
    }

    function submit() {
        if (!field.text.length || busy)
            return;
        busy = true;
        sddm.login(user, field.text, sessionModel.lastIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.busy = false;
            root.wrong = true;
            field.text = "";
            shake.restart();
            field.forceActiveFocus();
        }
        function onLoginSucceeded() {
            root.leaving = true;
        }
    }

    // The last user's real name (else the login name), capitalized.
    Repeater {
        model: userModel
        delegate: Item {
            required property int index
            required property string name
            required property string realName
            Component.onCompleted: {
                if (name !== root.user && !(root.user === "" && index === 0))
                    return;
                root.user = name;
                const shown = realName.length ? realName : name;
                root.realName = shown.charAt(0).toUpperCase() + shown.slice(1);
            }
        }
    }

    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // --- The wallpaper ----------------------------------------------------------------

    Rectangle {
        anchors.fill: parent
        color: "#1c1c1e" // until aurora has published a wallpaper
    }
    Image {
        id: wallpaper
        anchors.fill: parent
        source: config.background ? "file://" + config.background : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        scale: root.leaving ? 1 : 1.03
        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    }
    // What the glass bends: the wallpaper sharp, and blurred for its frost.
    ShaderEffectSource {
        id: sharpWallpaper
        sourceItem: wallpaper
        visible: false
    }
    MultiEffect {
        id: blurred
        anchors.fill: wallpaper
        source: wallpaper
        blurEnabled: true
        blurMax: 48
        blur: 1
        visible: false
    }
    ShaderEffectSource {
        id: frostedWallpaper
        sourceItem: blurred
        visible: false
    }
    // Typing pulls the wallpaper out of focus.
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
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
    }

    // --- Everything on top fades out when logging in ----------------------------------

    Item {
        anchors.fill: parent
        opacity: root.leaving ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.InQuad } }

        // The date and the clock.
        Column {
            id: header
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.09)
            spacing: -12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    const locale = Qt.locale(root.lang === "es" ? "es_AR" : "en_US");
                    const s = locale.toString(root.now, root.lang === "es" ? "dddd, d 'de' MMMM" : "dddd, MMMM d");
                    return s.charAt(0).toUpperCase() + s.slice(1);
                }
                color: Qt.rgba(1, 1, 1, 0.92)
                font.family: "Inter"
                font.pixelSize: 20
                font.weight: Font.DemiBold
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowOpacity: 0.45 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.now, "H:mm")
                color: Qt.rgba(1, 1, 1, 0.9)
                font.family: "Inter"
                font.pixelSize: Math.round(root.height * 0.15)
                font.weight: Font.Bold
                font.features: ({ "tnum": 1 })
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.8; shadowOpacity: 0.35; shadowVerticalOffset: 2 }
            }
        }

        // The user and the password.
        Column {
            visible: root.primary
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(root.height * 0.07)
            spacing: 12

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64
                height: 64
                Glass {
                    anchors.fill: parent
                    backdrop: root
                    frost: frostedWallpaper
                    sharp: sharpWallpaper
                    bend: 32
                }
                Text {
                    anchors.centerIn: parent
                    text: root.realName.charAt(0)
                    color: "white"
                    font.family: "Inter"
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.realName
                color: "white"
                font.family: "Inter"
                font.pixelSize: 15
                font.weight: Font.DemiBold
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowOpacity: 0.5 }
            }

            Item {
                id: capsule
                anchors.horizontalCenter: parent.horizontalCenter
                width: 220
                height: 34
                opacity: root.busy ? 0.6 : 1

                property real shakeX: 0
                transform: Translate { x: capsule.shakeX }
                // macOS's wrong-password shake (the lock screen's).
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
                    backdrop: root
                    frost: frostedWallpaper
                    sharp: sharpWallpaper
                    track: [capsule.shakeX]
                }

                TextInput {
                    id: field
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.right: arrow.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: "white"
                    font.family: "Inter"
                    font.pixelSize: 13
                    enabled: !root.busy && !root.leaving
                    focus: root.primary
                    clip: true
                    onTextChanged: {
                        if (text.length)
                            root.wrong = false;
                        root.wake();
                    }
                    Keys.onPressed: root.wake()
                    Keys.onReturnPressed: root.submit()
                    Keys.onEnterPressed: root.submit()
                    Keys.onEscapePressed: text = ""

                    Text {
                        visible: !field.text.length
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.tr("lock.password")
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font: field.font
                    }
                }

                // The arrow appears once there's something to send.
                Item {
                    id: arrow
                    anchors.right: parent.right
                    anchors.rightMargin: 5
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    opacity: field.text.length ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                    Glass {
                        anchors.fill: parent
                        backdrop: root
                        frost: frostedWallpaper
                        sharp: sharpWallpaper
                        veil: Qt.rgba(1, 1, 1, 0.86) // Tokens.glass.toggleOn
                        track: [capsule.shakeX]
                    }
                    Glyph {
                        anchors.centerIn: parent
                        size: 13
                        color: "#0a84ff"
                        parts: [{ d: "M3 8 H13 M8.75 3.75 L13 8 L8.75 12.25" }]
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.submit()
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.tr("lock.wrong")
                color: Qt.rgba(1, 1, 1, 0.8)
                font.family: "Inter"
                font.pixelSize: 12
                opacity: root.wrong ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }

            // Sleep, Restart and Shut Down, as under the Mac's login window.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 20
                spacing: 36

                Repeater {
                    model: [
                        { key: "login.sleep", can: sddm.canSuspend, act: () => sddm.suspend(),
                          parts: [{ d: "M13.5 9.9 A5.9 5.9 0 1 1 6.1 2.5 A4.6 4.6 0 0 0 13.5 9.9 Z", fill: true }] },
                        { key: "login.restart", can: sddm.canReboot, act: () => sddm.reboot(),
                          parts: [{ d: "M13 8 A5 5 0 1 1 11.5 4.45" }, { d: "M12 1.75 V4.75 H9" }] },
                        { key: "login.shutDown", can: sddm.canPowerOff, act: () => sddm.powerOff(),
                          parts: [{ d: "M8 1.75 V7.25" }, { d: "M4.75 4 A5.1 5.1 0 1 0 11.25 4" }] }
                    ]
                    delegate: Column {
                        required property var modelData
                        visible: modelData.can
                        spacing: 6
                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 40
                            height: 40
                            scale: tap.pressed ? 0.92 : 1
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Glass {
                                anchors.fill: parent
                                backdrop: root
                                frost: frostedWallpaper
                                sharp: sharpWallpaper
                            }
                            Glyph {
                                anchors.centerIn: parent
                                size: 16
                                parts: modelData.parts
                            }
                            MouseArea {
                                id: tap
                                anchors.fill: parent
                                onClicked: modelData.act()
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.tr(modelData.key)
                            color: Qt.rgba(1, 1, 1, 0.85)
                            font.family: "Inter"
                            font.pixelSize: 11
                            layer.enabled: true
                            layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.5; shadowOpacity: 0.5 }
                        }
                    }
                }
            }
        }
    }

    // Any input wakes it, and a click gives the field its focus back.
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
}
