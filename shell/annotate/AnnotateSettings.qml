import QtQuick
import "../core"
import "../components"
import "../components/menu"
import "../services"

/**
 * The editor's settings (gear or ","; on the toolbar's GlassMorph): the
 * effects' strength — pixelate cell, blur radius, zoom factor — live on the
 * marks already made; saving — keep a copy on disk when copying, ask where
 * to save, copy to the clipboard when saving, and the folder; and a way to
 * the shortcuts (Settings › Keyboard). Everything persists in Settings.
 */
Item {
    id: root


    width: 300
    height: column.implicitHeight + 2 * Tokens.space.l

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            Annotate.popover = "";
            event.accepted = true;
        }
    }


    component Caption: Text {
        x: Tokens.space.s
        color: Tokens.secondaryLabel
        font.family: Tokens.family
        font.pixelSize: Tokens.type.footnote.size
        font.weight: Font.DemiBold
    }

    /** A labelled slider over [from, to], snapped to `step`. */
    component Setting: Column {
        id: setting
        property string label: ""
        property real value: 0
        property real from: 0
        property real to: 1
        property real step: 1
        property string shown: String(value)
        signal changed(real v)
        width: parent ? parent.width : 0
        spacing: 2
        Item {
            width: parent.width
            height: 18
            Text {
                x: Tokens.space.s
                text: setting.label
                color: Tokens.label
                font.family: Tokens.family
                font.pixelSize: Tokens.type.body.size
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: Tokens.space.s
                text: setting.shown
                color: Tokens.secondaryLabel
                font.family: Tokens.family
                font.pixelSize: Tokens.type.body.size
                font.features: ({ "tnum": 1 })
            }
        }
        MenuSlider {
            width: parent.width
            value: (setting.value - setting.from) / (setting.to - setting.from)
            onMoved: v => setting.changed(Math.round((setting.from + v * (setting.to - setting.from)) / setting.step) * setting.step)
        }
    }

    component Toggle: Item {
        id: toggle
        property string label: ""
        property bool checked: false
        signal toggled(bool on)
        width: parent ? parent.width : 0
        height: 30
        Text {
            x: Tokens.space.s
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - sw.width - 3 * Tokens.space.s
            text: toggle.label
            color: Tokens.label
            font.family: Tokens.family
            font.pixelSize: Tokens.type.body.size
            elide: Text.ElideRight
        }
        MenuSwitch {
            id: sw
            anchors.right: parent.right
            anchors.rightMargin: Tokens.space.s
            anchors.verticalCenter: parent.verticalCenter
            checked: toggle.checked
            onToggled: on => toggle.toggled(on)
        }
    }

    Column {
        id: column
        x: Tokens.space.m
        y: Tokens.space.l
        width: root.width - 2 * Tokens.space.m
        spacing: Tokens.space.s

        Text {
            x: Tokens.space.s
            text: I18n.tr("annotate.settings")
            color: Tokens.label
            font.family: Tokens.family
            font.pixelSize: Tokens.type.headline.size
            font.weight: Font.Bold
        }

        Caption { text: I18n.tr("annotate.effects") }
        Setting {
            label: I18n.tr("annotate.tool.pixelate")
            value: Settings.annotateMosaic
            from: 4; to: 40; step: 1
            onChanged: v => Settings.annotateMosaic = v
        }
        Setting {
            label: I18n.tr("annotate.tool.blur")
            value: Settings.annotateBlur
            from: 8; to: 128; step: 1
            onChanged: v => Settings.annotateBlur = v
        }
        Setting {
            label: I18n.tr("annotate.tool.zoom")
            value: Settings.annotateZoom
            from: 1.5; to: 4; step: 0.5
            shown: "×" + Settings.annotateZoom.toFixed(1)
            onChanged: v => Settings.annotateZoom = v
        }

        Caption { text: I18n.tr("annotate.saving") }
        Toggle {
            label: I18n.tr("annotate.keepCopy")
            checked: Settings.annotateKeepCopy
            onToggled: on => Settings.annotateKeepCopy = on
        }
        Toggle {
            label: I18n.tr("annotate.askWhere")
            checked: Settings.annotateAskWhere
            onToggled: on => Settings.annotateAskWhere = on
        }
        Toggle {
            label: I18n.tr("annotate.copyOnSave")
            checked: Settings.annotateCopyOnSave
            onToggled: on => Settings.annotateCopyOnSave = on
        }
        Item {
            width: parent.width
            height: 32
            Column {
                x: Tokens.space.s
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - choose.width - 3 * Tokens.space.s
                Text {
                    text: I18n.tr("annotate.folder")
                    color: Tokens.label
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.body.size
                }
                Text {
                    width: parent.width
                    text: Annotate.folder.replace(Annotate.home, "~")
                    color: Tokens.secondaryLabel
                    font.family: Tokens.family
                    font.pixelSize: Tokens.type.footnote.size
                    elide: Text.ElideMiddle
                }
            }
            Button {
                id: choose
                anchors.right: parent.right
                anchors.rightMargin: Tokens.space.s
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("annotate.choose")
                onClicked: Annotate.pickFolder()
            }
        }

        Caption { text: I18n.tr("annotate.shortcut") }
        Text {
            x: Tokens.space.s
            width: parent.width - 2 * Tokens.space.s
            text: I18n.tr("annotate.shortcutNote")
            color: linkHover.containsMouse ? Qt.lighter(Tokens.accent, 1.15) : Tokens.accent
            font.family: Tokens.family
            font.pixelSize: Tokens.type.subheadline.size
            wrapMode: Text.Wrap
            MouseArea {
                id: linkHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Annotate.close();
                    Session.openSettings("keyboard");
                }
            }
        }
    }
}
