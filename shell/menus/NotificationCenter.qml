import QtQuick
import Quickshell
import "../core"
import "../components"
import "../services"

/**
  * Notification Center, after macOS Tahoe: opened from the clock, a panel of
 * glass holding the notifications grouped by app (newest group first) as
 * lighter platters of glass, "Clear All", and a month calendar below
 * (MonthCalendar) that pages between months. The list scrolls when it
 * outgrows the screen, with an overlay scroll bar.
 *
 * The menu layer's glass is the panel (`bare` stays false), like Control
 * Center. Clear All cascades: each card slides off to the right and fades,
 * then its row collapses so the ones below move up and the panel shrinks
 * with them; only then are they dismissed.
 */
Item {
    id: root

    property Item backdrop: null
    property bool chrome: false
    readonly property bool isMenuPanel: true
        readonly property bool bare: false
    readonly property real pad: Tokens.notificationCenter.padding
    readonly property real panelRadius: Tokens.radius.tile + pad
    property Item highlighted: null
    property var track: []

    readonly property real gap: Tokens.space.m
        readonly property real maxListHeight: (Quickshell.screens[0]?.height ?? 900) - Tokens.bar.height - calendar.height - 4 * gap - 60 - 2 * pad

    /**
     * [{ app, items, start }] newest group first, keeping each app's
     * notifications newest first; `start` is the group's first card's place
     * in the whole list (for the Clear All cascade).
     */
    readonly property var groups: {
        const byApp = [];
        for (const n of Notifications.all) {
            const app = n.appName || n.desktopEntry || "";
            let group = byApp.find(g => g.app === app);
            if (!group) {
                group = { app, items: [] };
                byApp.push(group);
            }
            group.items.push(n);
        }
        let start = 0;
        for (const g of byApp) {
            g.start = start;
            start += g.items.length;
        }
        return byApp;
    }

    /**
     * Clear All, like macOS: the cards slide off to the right one after the
     * other, fading, and only then are they dismissed.
     */
    property bool clearing: false
        readonly property int cascadeStep: 35
    readonly property int slideOut: 260
        /** A cleared card's row folds up over this, from halfway through its slide, moving the rest up behind it. */
    readonly property int collapse: 180
    function clearAll() {
        if (Motion.reduced) {
            Notifications.clearAll();
            return;
        }
        clearing = true;
                        clearDone.interval = Notifications.all.length * cascadeStep + slideOut / 2 + collapse + 40;
        clearDone.restart();
    }
    Timer {
        id: clearDone
        onTriggered: {
            Notifications.clearAll();
            root.clearing = false;
        }
    }

    property real now: Date.now()
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = Date.now()
    }

        implicitWidth: Tokens.notificationCenter.width + 2 * pad
    readonly property real headerSpace: header.visible ? header.height + gap : 0
    implicitHeight: 2 * pad + headerSpace + Math.min(list.contentHeight, maxListHeight) + gap + calendar.height

    // The menu layer's keyboard: nothing to walk here yet.
    function move(step) {}
    function activate() {}

    Item {
        id: inner
        x: root.pad
        y: root.pad
        width: parent.width - 2 * root.pad
        height: parent.height - 2 * root.pad

    // --- Header: Clear All ---------------------------------------------------

    Item {
        id: header
        visible: Notifications.all.length > 0
        opacity: root.clearing ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: root.slideOut } }
        width: parent.width
        height: 28

        Item {
            anchors.right: parent.right
            height: parent.height
            width: clearLabel.implicitWidth + 2 * Tokens.space.l

            Glass {
                anchors.fill: parent
                backdrop: root.backdrop
                                material: Tokens.glass.module
                radius: height / 2
                shadow: false
                held: clearTouch.pressed
                track: [root.track]
            }
            Text {
                id: clearLabel
                anchors.centerIn: parent
                text: I18n.tr("notifications.clearAll")
                color: Tokens.label
                font.family: Tokens.family
                font.pixelSize: Tokens.type.callout.size
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: clearTouch
                anchors.fill: parent
                onClicked: root.clearAll()
            }
        }
    }

    // --- Notifications -----------------------------------------------------------

    Flickable {
        id: list
        y: root.headerSpace
        width: parent.width
        height: Math.min(contentHeight, root.maxListHeight)
        contentHeight: column.height
        clip: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: column
            width: parent.width
            spacing: root.gap

                        // Empty: a quiet line on the panel saying so.
            Item {
                visible: Notifications.all.length === 0
                width: parent.width
                height: 56
                Text {
                    anchors.centerIn: parent
                    text: I18n.tr("notifications.empty")
                    color: Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.callout.size
                }
            }

            Repeater {
                model: root.groups
                delegate: Column {
                    id: group
                    required property var modelData
                    width: parent.width
                    spacing: root.gap

                                        // The app's name over its notifications; it folds up after its last card.
                    Item {
                        id: groupTitle
                        width: parent.width
                        height: 18
                        visible: group.modelData.app.length > 0
                        SequentialAnimation {
                            running: root.clearing
                                                        PauseAnimation { duration: (group.modelData.start + group.modelData.items.length - 1) * root.cascadeStep + root.slideOut / 2 }
                            NumberAnimation { target: groupTitle; property: "height"; to: 0; duration: root.collapse; easing.type: Easing.InOutCubic }
                        }

                        Text {
                            x: Tokens.space.xs
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: root.clearing ? 0 : 1
                            Behavior on opacity { NumberAnimation { duration: root.slideOut } }
                            text: group.modelData.app
                            color: Tokens.label
                            font.family: Tokens.family
                            font.pixelSize: Tokens.type.subheadline.size
                            font.weight: Font.DemiBold
                        }
                    }

                    Repeater {
                        model: group.modelData.items
                        delegate: NotificationCard {
                            id: card
                            required property var modelData
                            required property int index
                            notification: modelData
                                                        backdrop: root.backdrop
                            material: Tokens.glass.module
                            radius: Tokens.radius.tile
                            now: root.now
                            track: [root.track, group.y, x, y, list.contentY]

                            SequentialAnimation {
                                running: root.clearing
                                PauseAnimation { duration: (group.modelData.start + card.index) * root.cascadeStep }
                                                                ParallelAnimation {
                                    NumberAnimation { target: card; property: "x"; to: card.width + 24; duration: root.slideOut; easing.type: Easing.InCubic }
                                    NumberAnimation { target: card; property: "opacity"; to: 0; duration: root.slideOut; easing.type: Easing.InQuad }
                                    // Halfway out, its row folds behind it so the rest move up and the panel shrinks with them.
                                    SequentialAnimation {
                                        PauseAnimation { duration: root.slideOut / 2 }
                                        NumberAnimation { target: card; property: "height"; to: 0; duration: root.collapse; easing.type: Easing.InOutCubic }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ScrollIndicator { flickable: list; outside: false }

    // --- Calendar --------------------------------------------------------------

    MonthCalendar {
        id: calendar
        y: list.y + list.height + root.gap
        width: parent.width
        height: implicitHeight
                backdrop: root.backdrop
        material: Tokens.glass.module
        radius: Tokens.radius.tile
        track: root.track
        now: root.now
    }
    }
}
