import QtQuick
import "../core"
import "../components"

/**
 * The month calendar under Notification Center, after macOS: the month's
 * name in the accent color, the weekday initials from the locale's first
 * day, and always six weeks, so the card keeps its size from month to month
 * (like the Month widget) — the neighboring months' days in a quieter color,
 * weekends in secondary, today on an accent disc.
 *
 * Paging, after Calendar's mini month: ‹ and › step a month, Today comes
 * back (dimmed while already there), and so do the scroll wheel and a
 * sideways swipe. The new month slides in from the side it comes from.
 * It always opens on the current month (the panel is created per opening).
 */
Item {
    id: root

    property Item backdrop: null
    property var track: []
    property real now: Date.now()

    /** Months away from the current one. */
    property int offset: 0

    readonly property date today: new Date(now)
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property int firstDay: I18n.locale.firstDayOfWeek % 7
    readonly property int lead: (shown.getDay() - firstDay + 7) % 7

    readonly property real rowHeight: 24
    implicitHeight: grid.y + 20 + 6 * rowHeight + Tokens.space.l

    function step(by) {
        if (by === 0)
            return;
        offset += by;
        slide.snap(by > 0 ? 1 : -1);
    }
    function goToday() {
        if (offset !== 0)
            step(-offset);
    }

    // Slides the new month in: snapped to ±1 on a change, springs to 0.
    SpringValue {
        id: slide
        to: 0
        preset: Motion.snappy
    }

    Glass {
        anchors.fill: parent
        backdrop: root.backdrop
        material: Tokens.glass.regular
        radius: Tokens.radius.banner
        shadow: false
        track: [root.track, root.y]
    }

    // The wheel and a sideways swipe page the months; a notch (or a
    // swipe's worth of small deltas) is one month.
    property real wheelRest: 0
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const d = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? -wheel.angleDelta.x : -wheel.angleDelta.y;
            root.wheelRest += d;
            if (Math.abs(root.wheelRest) >= 120) {
                root.step(root.wheelRest > 0 ? 1 : -1);
                root.wheelRest = 0;
            }
            wheel.accepted = true;
        }
    }

    // --- Header: month, ‹ Today › ---------------------------------------------

    Text {
        id: title
        x: Tokens.space.l + 2
        y: Tokens.space.l
        width: controls.x - x - Tokens.space.s
        elide: Text.ElideRight
        text: {
            const s = I18n.locale.toString(root.shown, root.shown.getFullYear() === root.today.getFullYear() ? "MMMM" : "MMMM yyyy");
            return s.charAt(0).toUpperCase() + s.slice(1);
        }
        color: Tokens.accent
        font.family: Tokens.family
        font.pixelSize: Tokens.type.callout.size
        font.weight: Font.Bold
        opacity: 1 - 0.6 * Math.abs(slide.value)
        transform: Translate { x: 12 * slide.value }
    }

    component NavButton: Item {
        id: nav
        property var glyph: null
        property string text: ""
        property bool active: true
        signal clicked()
        width: text.length ? label.implicitWidth + 2 * Tokens.space.s : 22
        height: 22
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Tokens.toggleOff
            visible: hover.containsMouse && nav.active
        }
        Icon {
            visible: !!nav.glyph
            anchors.centerIn: parent
            glyph: nav.glyph
            size: 12
            stroke: 1.75
            color: Tokens.secondaryLabel
        }
        Text {
            id: label
            visible: nav.text.length > 0
            anchors.centerIn: parent
            text: nav.text
            color: nav.active ? Tokens.secondaryLabel : Tokens.tertiaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.footnote.size
            font.weight: Font.DemiBold
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            enabled: nav.active
            onClicked: nav.clicked()
        }
    }

    Row {
        id: controls
        anchors.right: parent.right
        anchors.rightMargin: Tokens.space.m
        y: Tokens.space.l - 3
        spacing: 2
        NavButton {
            glyph: Glyphs.chevronBack
            onClicked: root.step(-1)
        }
        NavButton {
            text: I18n.tr("calendar.today")
            active: root.offset !== 0
            onClicked: root.goToday()
        }
        NavButton {
            glyph: Glyphs.chevron
            onClicked: root.step(1)
        }
    }

    // --- Weekdays and days ---------------------------------------------------

    Item {
        id: grid
        x: Tokens.space.l
        y: 38
        width: parent.width - 2 * Tokens.space.l
        height: 20 + 6 * root.rowHeight
        clip: true
        readonly property real cell: width / 7

        // Weekday initials, starting on the locale's first day.
        Row {
            Repeater {
                model: 7
                delegate: Text {
                    required property int index
                    readonly property int weekday: (root.firstDay + index) % 7
                    width: grid.cell
                    height: 20
                    horizontalAlignment: Text.AlignHCenter
                    text: I18n.locale.dayName(weekday, Locale.NarrowFormat).toUpperCase()
                    color: weekday === 0 || weekday === 6 ? Tokens.tertiaryLabel : Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.caption2.size
                    font.weight: Font.DemiBold
                }
            }
        }

        Grid {
            y: 20
            columns: 7
            opacity: 1 - 0.6 * Math.abs(slide.value)
            transform: Translate { x: grid.width * 0.35 * slide.value }

            Repeater {
                model: 42
                delegate: Item {
                    required property int index
                    readonly property date date: new Date(root.shown.getFullYear(), root.shown.getMonth(), 1 - root.lead + index)
                    readonly property bool inMonth: date.getMonth() === root.shown.getMonth()
                    readonly property bool weekend: date.getDay() === 0 || date.getDay() === 6
                    readonly property bool isToday: date.getFullYear() === root.today.getFullYear()
                        && date.getMonth() === root.today.getMonth() && date.getDate() === root.today.getDate()
                    width: grid.cell
                    height: root.rowHeight

                    Rectangle {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        radius: 11
                        color: Tokens.accent
                        opacity: parent.inMonth ? 1 : 0.45
                        visible: parent.isToday
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.date.getDate()
                        color: parent.isToday ? "white"
                            : !parent.inMonth ? Tokens.tertiaryLabel
                            : parent.weekend ? Tokens.secondaryLabel : Tokens.label
                        font.family: Tokens.family
                        font.pixelSize: Tokens.type.footnote.size + 1
                        font.weight: parent.isToday ? Font.Bold : Font.Normal
                        font.features: ({ "tnum": 1 })
                    }
                }
            }
        }
    }
}
