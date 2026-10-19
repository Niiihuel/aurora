import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"
import "../../components"
import "../../services"
import ".."

/**
 * General: about this computer (name, system, kernel, processor, memory,
 * graphics) and updating the system (`nixos-rebuild switch` on the dotfiles
 * flake, run in a terminal so its sudo prompt and progress show).
 */
Column {
    id: root
    property Item backdrop: null
    spacing: Tokens.space.xl

    property var about: ({})

    Process {
        running: true
        command: ["sh", "-c",
            "echo host=$(cat /proc/sys/kernel/hostname); " +
            ". /etc/os-release; echo os=$PRETTY_NAME; " +
            "echo kernel=$(uname -r); " +
            "echo cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//'); " +
            "echo cores=$(nproc); " +
            "echo memory=$(awk '/MemTotal/ { printf \"%.0f\", $2 / 1048576 }' /proc/meminfo); " +
            "echo gpu=$(lspci 2>/dev/null | grep -E 'VGA|3D' | sed 's/.*: //' | paste -sd '|' - | sed 's/|/ · /g')"]
        stdout: StdioCollector {
            onStreamFinished: {
                const info = {};
                for (const line of this.text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        info[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                root.about = info;
            }
        }
    }

    SettingsGroup {
        title: I18n.tr("settings.general.about")
        SettingsRow { title: I18n.tr("settings.general.name"); Value { text: root.about.host ?? "" } }
        SettingsRow { title: I18n.tr("settings.general.system"); Value { text: root.about.os ?? "" } }
        SettingsRow { title: I18n.tr("settings.general.kernel"); Value { text: root.about.kernel ?? "" } }
        SettingsRow { title: I18n.tr("settings.general.processor"); Value { text: root.about.cpu ? `${root.about.cpu} (${root.about.cores})` : "" } }
        SettingsRow { title: I18n.tr("settings.general.memory"); Value { text: root.about.memory ? I18n.tr("settings.general.gb", { n: root.about.memory }) : "" } }
        SettingsRow { title: I18n.tr("settings.general.graphics"); Value { text: root.about.gpu ?? "" } }
    }

    SettingsGroup {
        title: I18n.tr("settings.general.update")
        info: I18n.tr("settings.general.updateNote")
        SettingsRow {
            title: I18n.tr("settings.general.updateSystem")
            subtitle: "nixos-rebuild switch --flake ~/dotfiles#nixos"
            Button {
                text: I18n.tr("settings.general.updateNow")
                isDefault: true
                onClicked: Quickshell.execDetached(["kitty", "--title", "aurora · nixos-rebuild", "sh", "-c",
                    "sudo nixos-rebuild switch --flake \"$HOME/dotfiles#nixos\"; echo; read -p '⏎ ' _"])
            }
        }
    }

    component Value: Text {
        width: Math.min(implicitWidth, 380)
        color: Tokens.secondaryLabel
        font.family: Tokens.family
        font.pixelSize: Tokens.type.body.size
        elide: Text.ElideRight
    }
}
