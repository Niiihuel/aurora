import QtQuick
import Quickshell
import "../../core"
import "../../services"
import ".."

/** Lock Screen: when the screen turns off, the session locks and the computer sleeps. */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.xl

    readonly property var minutes: [0, 1, 2, 5, 10, 15, 20, 30, 60]
    function choices() {
        return minutes.map(m => ({ value: m, label: m === 0 ? I18n.tr("settings.lock.never") : I18n.tr("settings.lock.minutes", { n: m }) }));
    }

    SettingsGroup {
        footer: I18n.tr("settings.lock.note")
        SettingsRow {
            title: I18n.tr("settings.lock.screenOff")
            ChoiceButton {
                backdrop: root.backdrop
                choices: root.choices()
                value: Settings.idleScreenOff
                onPicked: v => { Settings.idleScreenOff = v; Idle.apply(); }
            }
        }
        SettingsRow {
            title: I18n.tr("settings.lock.lockAfter")
            ChoiceButton {
                backdrop: root.backdrop
                choices: root.choices()
                value: Settings.idleLock
                onPicked: v => { Settings.idleLock = v; Idle.apply(); }
            }
        }
        SettingsRow {
            title: I18n.tr("settings.lock.sleepAfter")
            ChoiceButton {
                backdrop: root.backdrop
                choices: root.choices()
                value: Settings.idleSuspend
                onPicked: v => { Settings.idleSuspend = v; Idle.apply(); }
            }
        }
    }

    SettingsGroup {
        SettingsRow {
            title: I18n.tr("system.lock")
            interactive: true
            onClicked: Quickshell.execDetached(["loginctl", "lock-session"])
        }
    }
}
