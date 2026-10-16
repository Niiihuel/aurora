import QtQuick
import "../core"
import "../components/menu"
import "../services"

/**
 * The battery extra's menu, after macOS: the title with the charge level, the
 * power source and time remaining (or until full), and the energy mode with a
 * checkmark on the current one. Changing the mode keeps the menu open.
 */
MenuPanel {
    id: root

    panelWidth: 260

    // i18n-keys: battery.mode.saver battery.mode.balanced battery.mode.performance
    readonly property var modes: BatteryStatus.hasPerformance ? ["saver", "balanced", "performance"] : ["saver", "balanced"]

    Item {
        width: parent.width
        height: 30
        MenuHeader { title: I18n.tr("battery.title") }
        Text {
            anchors.right: parent.right
            anchors.rightMargin: Tokens.menu.itemInset
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("common.percent", { n: Math.round(BatteryStatus.level * 100) })
            color: Tokens.secondaryLabel
            font.family: Tokens.family
            font.pixelSize: Tokens.type.body.size
            font.features: ({ "tnum": 1 })
        }
    }

    MenuInfo {
        text: I18n.tr("battery.source", { source: BatteryStatus.pluggedIn ? I18n.tr("battery.source.adapter") : I18n.tr("battery.source.battery") })
    }

    MenuInfo {
        readonly property real seconds: BatteryStatus.charging ? BatteryStatus.timeToFull : BatteryStatus.timeToEmpty
        visible: seconds > 0 && !BatteryStatus.full
        text: BatteryStatus.charging
            ? I18n.tr("battery.untilFull", { time: BatteryStatus.duration(seconds) })
            : I18n.tr("battery.remaining", { time: BatteryStatus.duration(seconds) })
    }

    MenuInfo {
        visible: BatteryStatus.full
        text: I18n.tr("battery.full")
    }

    MenuSeparator {}
    MenuSectionTitle { text: I18n.tr("battery.mode") }

    Repeater {
        model: root.modes
        delegate: MenuItem {
            required property string modelData
            text: I18n.tr("battery.mode." + modelData)
            reserveMark: true
            checked: BatteryStatus.mode === modelData
            closeOnTrigger: false
            onTriggered: BatteryStatus.setMode(modelData)
        }
    }

    MenuSeparator {}

    MenuItem {
        text: I18n.tr("battery.settings")
        onTriggered: Session.openSettings("battery")
    }
}
