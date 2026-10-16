import QtQuick
import "../../core"
import "../../components"
import ".."

/** Language and region: the interface language and the format for dates and numbers. */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.xl

    SettingsGroup {
        SettingsRow {
            title: I18n.tr("settings.language.language")
            ChoiceButton {
                backdrop: root.backdrop
                choices: I18n.available.map(code => ({ value: code, label: I18n.nameOf(code) }))
                value: I18n.language
                onPicked: v => Settings.language = v
            }
        }
        SettingsRow {
            title: I18n.tr("settings.language.region")
            subtitle: I18n.locale.toString(new Date(), "dddd d MMMM yyyy · H:mm") + " · " + Number(1234.5).toLocaleString(I18n.locale)
            ChoiceButton {
                backdrop: root.backdrop
                choices: [
                    { value: "", label: I18n.tr("settings.language.automatic") },
                    { value: "es_AR", label: "Argentina" },
                    { value: "es_ES", label: "España" },
                    { value: "es_MX", label: "México" },
                    { value: "en_US", label: "United States" },
                    { value: "en_GB", label: "United Kingdom" }
                ]
                value: Settings.locale
                onPicked: v => Settings.locale = v
            }
        }
    }
}
