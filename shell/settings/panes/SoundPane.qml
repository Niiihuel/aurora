import QtQuick
import "../../core"
import "../../components"
import "../../components/menu"
import "../../services"
import ".."

/** Sound: output volume and device, input level and device. */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.xl

    SettingsGroup {
        title: I18n.tr("sound.output")
        SettingsRow {
            title: I18n.tr("settings.sound.volume")
            glyph: Glyphs.speaker(AudioStatus.waves)
            glyphTint: Tokens.destructive
            MenuSlider {
                width: 260
                backdrop: root.backdrop
                value: AudioStatus.muted ? 0 : AudioStatus.volume
                onMoved: v => AudioStatus.setVolume(v)
            }
        }
        SettingsRow {
            title: I18n.tr("settings.sound.mute")
            MenuSwitch {
                checked: AudioStatus.muted
                onToggled: on => AudioStatus.setMuted(on)
            }
        }
        Repeater {
            model: AudioStatus.outputs
            delegate: SettingsRow {
                required property var modelData
                title: AudioStatus.nameOf(modelData)
                interactive: true
                onClicked: AudioStatus.setOutput(modelData)
                Icon {
                    visible: modelData === AudioStatus.sink
                    glyph: Glyphs.checkmark
                    size: 14
                    stroke: 1.75
                    color: Tokens.accent
                }
            }
        }
    }

    SettingsGroup {
        visible: AudioStatus.inputs.length > 0
        title: I18n.tr("settings.sound.input")
        SettingsRow {
            title: I18n.tr("settings.sound.inputLevel")
            MenuSlider {
                width: 260
                backdrop: root.backdrop
                value: AudioStatus.inputVolume
                onMoved: v => AudioStatus.setInputVolume(v)
            }
        }
        Repeater {
            model: AudioStatus.inputs
            delegate: SettingsRow {
                required property var modelData
                title: AudioStatus.nameOf(modelData)
                interactive: true
                onClicked: AudioStatus.setInput(modelData)
                Icon {
                    visible: modelData === AudioStatus.source
                    glyph: Glyphs.checkmark
                    size: 14
                    stroke: 1.75
                    color: Tokens.accent
                }
            }
        }
    }
}
