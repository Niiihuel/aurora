import QtQuick
import "../../core"
import "../../components"
import "../../services"
import "../../core/search.mjs" as Search
import ".."

/**
 * Apps: check for updates (what would change, package by package, built
 * aside without touching ~/dotfiles) and install them; apply pending
 * changes; and every installed app — searchable, with where it comes from
 * and a split button: Open, and in its menu Uninstall when the source allows
 * it (see services/Packages for what that means on NixOS).
 */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.l

    property string query: ""
    readonly property var apps: {
        const all = Apps.entries.slice().sort((a, b) => a.name.localeCompare(b.name));
        if (!query.trim().length)
            return all;
        return all.filter(e => Search.score(e.name, query) > 0 || Search.score(e.genericName || "", query, true) > 0);
    }

    Component.onCompleted: Packages.scan()

    // i18n-keys: settings.apps.state.checking settings.apps.state.preparing settings.apps.state.available settings.apps.state.uptodate settings.apps.state.building settings.apps.state.done settings.apps.state.failed
    SettingsGroup {
        title: I18n.tr("settings.apps.updates")
        footer: I18n.tr("settings.apps.updatesNote")
        SettingsRow {
            title: Packages.state === "available"
                ? I18n.tr("settings.apps.state.available", { n: Packages.updates.length })
                : Packages.state.length ? I18n.tr("settings.apps.state." + Packages.state) : I18n.tr("settings.apps.updateAll")
            subtitle: Packages.busy ? Packages.line : ""
            glyph: Packages.busy ? null : Glyphs.apps
            busy: Packages.busy
            Button {
                visible: !Packages.busy
                text: Packages.state === "available" ? I18n.tr("settings.apps.install") : I18n.tr("settings.apps.check")
                isDefault: Packages.state === "available"
                onClicked: Packages.state === "available" ? Packages.applyUpdates() : Packages.checkUpdates()
            }
        }
        SettingsRow {
            visible: Packages.pending
            title: I18n.tr("settings.apps.pending")
            subtitle: I18n.tr("settings.apps.pendingNote")
            Button {
                text: I18n.tr("settings.apps.apply")
                enabled: !Packages.busy
                onClicked: Packages.apply()
            }
        }
    }

    // What the update would change, package by package.
    SettingsGroup {
        visible: Packages.updates.length > 0
        title: I18n.tr("settings.apps.changes", { n: Packages.updates.length })
        Repeater {
            model: Packages.updates.slice(0, 60)
            delegate: SettingsRow {
                required property var modelData
                title: modelData.name
                subtitle: `${modelData.from} → ${modelData.to}`
                Text {
                    text: modelData.size
                    color: Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.subheadline.size
                }
            }
        }
        SettingsRow {
            visible: Packages.updates.length > 60
            title: I18n.tr("settings.apps.more", { n: Packages.updates.length - 60 })
        }
    }

    SearchField {
        width: Math.min(parent.width, 320)
        onTextChanged: root.query = text
    }

    // i18n-keys: settings.apps.kind.managed settings.apps.kind.profile settings.apps.kind.local settings.apps.kind.system
    // i18n-keys: settings.apps.uninstallMessage.managed settings.apps.uninstallMessage.profile settings.apps.uninstallMessage.local
    SettingsGroup {
        title: I18n.tr("settings.apps.installed", { n: root.apps.length })
        footer: I18n.tr("settings.apps.note")
        Repeater {
            model: root.apps
            delegate: SettingsRow {
                id: row
                required property var modelData
                // Re-read when the scan finishes (sources is replaced as a whole).
                readonly property var source: { void Packages.sources; return Packages.sourceOf(modelData); }
                title: modelData.name
                subtitle: [modelData.genericName || modelData.comment || "", I18n.tr("settings.apps.kind." + source.kind)].filter(s => s.length).join(" · ")
                image: Apps.iconFor(modelData)
                SplitButton {
                    text: I18n.tr("settings.apps.open")
                    backdrop: root.backdrop
                    onClicked: Apps.launch(row.modelData)
                    menu: [
                        { label: I18n.tr("settings.apps.open"), act: () => Apps.launch(row.modelData) },
                        {
                            label: row.source.kind === "system" ? I18n.tr("settings.apps.uninstallSystem") : I18n.tr("settings.apps.uninstall") + "…",
                            destructive: true,
                            enabled: row.source.kind !== "system",
                            act: () => Dialogs.confirm({
                                title: I18n.tr("settings.apps.uninstallTitle", { name: row.modelData.name }),
                                message: I18n.tr("settings.apps.uninstallMessage." + row.source.kind),
                                action: I18n.tr("settings.apps.uninstall"),
                                destructive: true,
                                run: () => Packages.uninstall(row.modelData)
                            })
                        }
                    ]
                }
            }
        }
    }
}
