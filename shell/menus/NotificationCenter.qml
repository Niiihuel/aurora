import QtQuick
import Quickshell
import "../core"
import "../components"
import "../services"

/**
 * Notification Center, after macOS Tahoe: opened from the clock, a column of
 * separate liquid glass pieces with no panel behind them — the notifications
 * grouped by app (newest group first) with "Clear All", and a month
 * calendar below (MonthCalendar) that pages between months. The list
 * scrolls when it outgrows the screen.
 *
 * It's a bare panel for the menu layer (its glass carries the pop out of the
 * clock and hands over to the cards), like Control Center.
 */
Item {
    id: root

    property Item backdrop: null
    property bool chrome: false
    readonly property bool isMenuPanel: true
    readonly property bool bare: true
    readonly property real panelRadius: Tokens.radius.banner
    property Item highlighted: null
    property var track: []

    readonly property real gap: Tokens.space.m
    readonly property real maxListHeight: (Quickshell.screens[0]?.height ?? 900) - Tokens.bar.height - calendar.height - 4 * gap - 60

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
    function clearAll() {
        if (Motion.reduced) {
            Notifications.clearAll();
            return;
        }
        clearing = true;
        clearDone.interval = Notifications.all.length * cascadeStep + slideOut + 40;
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

    implicitWidth: 344
    readonly property real headerSpace: header.visible ? header.height + gap : 0
    implicitHeight: headerSpace + Math.min(list.contentHeight, maxListHeight) + gap + calendar.height

    // The menu layer's keyboard: nothing to walk here yet.
    function move(step) {}
    function activate() {}

    // --- Header: Clear All -------------------------------------------------------

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
                material: Tokens.glass.regularSmall
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

            // Empty: one quiet piece of glass saying so.
            Item {
                visible: Notifications.all.length === 0
                width: parent.width
                height: 56

                Glass {
                    anchors.fill: parent
                    backdrop: root.backdrop
                    material: Tokens.glass.regular
                    radius: Tokens.radius.banner
                    shadow: false
                    track: [root.track]
                }
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

                    // The app's name over its notifications.
                    Item {
                        width: parent.width
                        height: 18
                        visible: group.modelData.app.length > 0

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
                            now: root.now
                            track: [root.track, group.y, x, y, list.contentY]

                            SequentialAnimation {
                                running: root.clearing
                                PauseAnimation { duration: (group.modelData.start + card.index) * root.cascadeStep }
                                ParallelAnimation {
                                    NumberAnimation { target: card; property: "x"; to: card.width + 24; duration: root.slideOut; easing.type: Easing.InCubic }
                                    NumberAnimation { target: card; property: "opacity"; to: 0; duration: root.slideOut; easing.type: Easing.InQuad }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Calendar ------------------------------------------------------------------

    MonthCalendar {
        id: calendar
        y: list.y + list.height + root.gap
        width: parent.width
        height: implicitHeight
        backdrop: root.backdrop
        track: root.track
        now: root.now
    }
}
