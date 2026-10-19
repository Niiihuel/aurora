import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../core"
import "../components"
import "../components/menu"
import "../services"

/**
 * The activity extra's menu, after Activity Monitor and iStat Menus: the CPU
 * load with its last minute and temperature, memory and swap, the GPU (and
 * whether the discrete one is asleep), network rates and disk space. Under
 * CPU and memory, the three processes using the most of each; helpers that
 * share a name are one row, named and drawn as their app when it has a window.
 *
 * Choosing a process shows its details in place (the glass reshapes, like the
 * Wi-Fi menu's network details): CPU, memory, threads, its user, Quit and
 * Force Quit… (confirmed by an alert). The back row or Esc returns.
 * Everything but the CPU is read only while this menu is open.
 */
MenuPanel {
    id: root

    panelWidth: 280

    /** The process name whose details are shown; empty for the overview. */
    property string detail: ""
    readonly property var detailRow: detail.length ? ActivityStatus.find(detail) : null
    readonly property var detailApp: ActivityStatus.app(detailRow)
    property string owner: ""

    function openDetail(name) {
        highlighted = null;
        owner = "";
        detail = name;
        const row = ActivityStatus.find(name);
        if (row) {
            ownerProbe.command = ["stat", "-c", "%U", "/proc/" + row.pids[0]];
            ownerProbe.running = true;
        }
    }

    /** Esc: leave the details. False on the overview. */
    function back() {
        if (!detail.length)
            return false;
        highlighted = null;
        detail = "";
        return true;
    }

    // The process quit between two samples: nothing left to show.
    onDetailRowChanged: if (detail.length && !detailRow) back()

    /** `precise`: one decimal under 10 %, like Activity Monitor's process list. */
    function percent(load, precise) {
        const p = load * 100;
        return I18n.tr("common.percent", { n: precise && p > 0 && p < 9.95 ? I18n.locale.toString(p, "f", 1) : Math.round(p) });
    }
    function celsius(t) {
        return I18n.tr("activity.celsius", { n: Math.round(t) });
    }
    function rate(r) {
        return r < 0 ? "–" : I18n.tr("activity.rate", { size: ActivityStatus.bytes(r) });
    }
    function ofTotal(used, total) {
        return I18n.tr("activity.ofTotal", { used: ActivityStatus.bytes(used), total: ActivityStatus.bytes(total) });
    }

    Component.onCompleted: ActivityStatus.watchers += 1
    Component.onDestruction: ActivityStatus.watchers -= 1

    Process {
        id: ownerProbe
        stdout: StdioCollector {
            onStreamFinished: root.owner = this.text.trim()
        }
    }

    /** A group's caption with its headline value on the trailing side. */
    component Caption: Item {
        property string text: ""
        property string value: ""
        width: parent ? parent.width : 0
        height: 22
        Text {
            x: Tokens.menu.itemInset
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            text: parent.text
            color: Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.subheadline.size
            font.weight: Font.DemiBold
        }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: Tokens.menu.itemInset
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            text: parent.value
            color: Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.subheadline.size
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
    }

    /** A measurement: what it is, and its value on the trailing side. */
    component Value: Item {
        id: valueRow
        property string text: ""
        property string value: ""
        width: parent ? parent.width : 0
        implicitWidth: valueLabel.implicitWidth + valueText.implicitWidth + 2 * Tokens.menu.itemInset + Tokens.space.xl
        height: 22
        Text {
            id: valueLabel
            x: Tokens.menu.itemInset
            anchors.verticalCenter: parent.verticalCenter
            text: valueRow.text
            color: Tokens.label
            font.family: Tokens.family
            font.pixelSize: Tokens.type.body.size
        }
        Text {
            id: valueText
            anchors.right: parent.right
            anchors.rightMargin: Tokens.menu.itemInset
            anchors.verticalCenter: parent.verticalCenter
            text: valueRow.value
            color: Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.body.size
            font.features: ({ "tnum": 1 })
        }
    }

    /** How full something is, as a capsule. */
    component Meter: Item {
        id: meter
        property real fraction: 0
        width: parent ? parent.width : 0
        height: 14
        Rectangle {
            id: track
            x: Tokens.menu.itemInset
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 2 * Tokens.menu.itemInset
            height: 6
            radius: 3
            color: Tokens.quaternaryLabel
            Rectangle {
                width: Math.max(height, track.width * Math.min(1, meter.fraction))
                height: parent.height
                radius: parent.radius
                color: Tokens.accent
            }
        }
    }

    /** One of the top processes: its app's icon and name, and how much it uses. */
    component ProcessRow: MenuItem {
        property var row: null
        readonly property var app: ActivityStatus.app(row)
        // Always there, so the menu doesn't grow when the first sample lands.
        enabled: !!row
        text: app.name
        image: app.icon
        closeOnTrigger: false
    }

    // --- Overview ------------------------------------------------------------------

    Column {
        width: parent.width
        visible: !root.detail.length

        MenuHeader { title: I18n.tr("activity.title") }

        MenuSeparator {}
        Caption { text: I18n.tr("activity.cpu"); value: root.percent(ActivityStatus.cpu) }

        // The last minute; the empty part fills in from the right as it's sampled.
        Item {
            width: parent.width
            height: 52
            Rectangle {
                id: chart
                x: Tokens.menu.itemInset
                y: 4
                width: parent.width - 2 * Tokens.menu.itemInset
                height: 44
                radius: Tokens.radius.menuItem
                color: Tokens.quaternaryLabel
                clip: true
                ActivityGraph {
                    anchors.fill: parent
                    anchors.topMargin: 4
                    values: ActivityStatus.history
                    length: ActivityStatus.historyLength
                    color: Tokens.accent
                    fillOpacity: 0.35
                    lineWidth: 1.5
                }
            }
        }

        Value {
            visible: !isNaN(ActivityStatus.cpuTemp)
            text: I18n.tr("activity.temperature")
            value: root.celsius(ActivityStatus.cpuTemp)
        }

        Repeater {
            model: 3
            delegate: ProcessRow {
                required property int index
                row: ActivityStatus.topCpu[index] ?? null
                detail: row ? root.percent(row.cpu, true) : ""
                onTriggered: root.openDetail(row.name)
            }
        }

        MenuSeparator {}
        Caption { text: I18n.tr("activity.memory"); value: root.ofTotal(ActivityStatus.memUsed, ActivityStatus.memTotal) }
        Meter { fraction: ActivityStatus.memTotal > 0 ? ActivityStatus.memUsed / ActivityStatus.memTotal : 0 }
        Value {
            visible: ActivityStatus.swapUsed > 0
            text: I18n.tr("activity.swap")
            value: ActivityStatus.bytes(ActivityStatus.swapUsed)
        }

        Repeater {
            model: 3
            delegate: ProcessRow {
                required property int index
                row: ActivityStatus.topMemory[index] ?? null
                detail: row ? ActivityStatus.bytes(row.rss) : ""
                onTriggered: root.openDetail(row.name)
            }
        }

        Column {
            width: parent.width
            visible: ActivityStatus.gpuBusy >= 0 || !isNaN(ActivityStatus.gpuTemp) || ActivityStatus.dgpu.length > 0

            MenuSeparator {}
            Caption { text: I18n.tr("activity.gpu"); value: ActivityStatus.gpuBusy >= 0 ? root.percent(ActivityStatus.gpuBusy) : "" }
            Value {
                visible: !isNaN(ActivityStatus.gpuTemp)
                text: I18n.tr("activity.temperature")
                value: root.celsius(ActivityStatus.gpuTemp)
            }
            // i18n-keys: activity.dgpu.active activity.dgpu.suspended
            Value {
                visible: ActivityStatus.dgpu.length > 0
                text: I18n.tr("activity.dgpu")
                value: ActivityStatus.dgpu.length ? I18n.tr("activity.dgpu." + ActivityStatus.dgpu) : ""
            }
        }

        MenuSeparator {}
        Caption { text: I18n.tr("activity.network") }
        Value { text: I18n.tr("activity.download"); value: root.rate(ActivityStatus.rxRate) }
        Value { text: I18n.tr("activity.upload"); value: root.rate(ActivityStatus.txRate) }

        Column {
            width: parent.width
            visible: ActivityStatus.diskTotal > 0

            MenuSeparator {}
            Caption { text: I18n.tr("activity.disk"); value: root.ofTotal(ActivityStatus.diskUsed, ActivityStatus.diskTotal) }
            Meter { fraction: ActivityStatus.diskUsed / ActivityStatus.diskTotal }
        }
    }

    // --- A process's details -----------------------------------------------------------

    Column {
        width: parent.width
        visible: !!root.detailRow

        MenuItem {
            text: I18n.tr("activity.title")
            glyph: Glyphs.chevronBack
            closeOnTrigger: false
            onTriggered: root.back()
        }

        Item {
            width: parent.width
            implicitWidth: appName.implicitWidth + 26 + Tokens.space.m + 2 * Tokens.menu.itemInset
            height: 44

            IconImage {
                x: Tokens.menu.itemInset - 2
                anchors.verticalCenter: parent.verticalCenter
                source: root.detailApp.icon
                implicitSize: 28
            }

            Column {
                x: Tokens.menu.itemInset + 26 + Tokens.space.m
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x - Tokens.menu.itemInset
                spacing: 1
                Text {
                    id: appName
                    width: parent.width
                    text: root.detailApp.name
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: !root.detailRow ? ""
                        : root.detailRow.pids.length > 1 ? I18n.tr("activity.processes", { count: root.detailRow.pids.length })
                        : I18n.tr("activity.pid", { pid: root.detailRow.pids[0] })
                    color: Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.subheadline.size
                    font.features: ({ "tnum": 1 })
                    elide: Text.ElideRight
                }
            }
        }

        MenuSeparator {}
        Value { text: I18n.tr("activity.cpu"); value: root.detailRow ? root.percent(root.detailRow.cpu, true) : "" }
        Value { text: I18n.tr("activity.memory"); value: root.detailRow ? ActivityStatus.bytes(root.detailRow.rss) : "" }
        Value { text: I18n.tr("activity.threads"); value: root.detailRow ? String(root.detailRow.threads) : "" }
        Value { visible: root.owner.length > 0; text: I18n.tr("activity.user"); value: root.owner }

        MenuSeparator {}

        // Someone else's processes (root's) can't be signalled from here.
        MenuItem {
            text: I18n.tr("activity.quit")
            enabled: root.owner === Session.user
            onTriggered: ActivityStatus.quit(root.detailRow, false)
        }

        MenuItem {
            text: I18n.tr("activity.forceQuit")
            destructive: true
            enabled: root.owner === Session.user
            onTriggered: {
                const row = root.detailRow;
                const name = root.detailApp.name;
                Dialogs.confirm({
                    title: I18n.tr("activity.forceQuit.title", { name }),
                    message: I18n.tr("activity.forceQuit.message"),
                    action: I18n.tr("activity.forceQuit.action"),
                    destructive: true,
                    run: () => ActivityStatus.quit(row, true)
                });
            }
        }
    }
}
