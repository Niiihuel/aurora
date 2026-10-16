import QtQuick
import "../../core"
import "../../components"
import "../../services"
import "../../core/search.mjs" as Search
import ".."

/**
 * Apps: update everything (the flake's inputs, then a rebuild, with its live
 * progress), apply pending changes, and every installed app — searchable,
 * with where it comes from, Open, and Uninstall when its source allows it
 * (see services/Packages for what uninstall means on NixOS).
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

    // i18n-keys: settings.apps.state.updating settings.apps.state.building settings.apps.state.done settings.apps.state.failed
    SettingsGroup {
        title: I18n.tr("settings.apps.updates")
        footer: I18n.tr("settings.apps.updatesNote")
        SettingsRow {
            title: I18n.tr("settings.apps.updateAll")
            subtitle: Packages.state.length
                ? I18n.tr("settings.apps.state." + Packages.state) + (Packages.line.length ? " · " + Packages.line : "")
                : "nix flake update · nixos-rebuild switch"
            glyph: Glyphs.apps
            Button {
                text: I18n.tr("settings.apps.update")
                isDefault: true
                enabled: !Packages.busy
                onClicked: Packages.updateAll()
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
                Button {
                    text: I18n.tr("settings.apps.open")
                    onClicked: Apps.launch(row.modelData)
                }
                Button {
                    visible: row.source.kind !== "system"
                    text: I18n.tr("settings.apps.uninstall")
                    onClicked: Dialogs.confirm({
                        title: I18n.tr("settings.apps.uninstallTitle", { name: row.modelData.name }),
                        message: I18n.tr("settings.apps.uninstallMessage." + row.source.kind),
                        action: I18n.tr("settings.apps.uninstall"),
                        destructive: true,
                        run: () => Packages.uninstall(row.modelData)
                    })
                }
            }
        }
    }
}
