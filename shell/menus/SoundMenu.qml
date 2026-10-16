import QtQuick
import Quickshell
import "../core"
import "../components/menu"
import "../services"

/**
 * The sound extra's menu, after macOS: the title, a volume slider, the output
 * devices with a checkmark on the current one, and the settings entry.
 * Picking an output keeps the menu open (state changes in place), like macOS.
 */
MenuPanel {
    id: root

    panelWidth: 280

    MenuHeader { title: I18n.tr("sound.title") }

    MenuSlider {
        backdrop: root.backdrop
        value: AudioStatus.muted ? 0 : AudioStatus.volume
        onMoved: v => AudioStatus.setVolume(v)
    }

    MenuSeparator {}

    MenuSectionTitle { text: I18n.tr("sound.output") }

    Repeater {
        model: ScriptModel { values: AudioStatus.outputs }
        delegate: MenuItem {
            required property var modelData
            text: AudioStatus.nameOf(modelData)
            reserveMark: true
            checked: modelData === AudioStatus.sink
            closeOnTrigger: false
            onTriggered: AudioStatus.setOutput(modelData)
        }
    }

    MenuSeparator {}

    MenuItem {
        text: I18n.tr("sound.settings")
        onTriggered: Session.openSettings("sound")
    }
}
