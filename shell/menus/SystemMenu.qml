import QtQuick
import "../core"
import "../components/menu"
import "../services"

/**
 * aurora's system menu, the equivalent of macOS's Apple menu: about and
 * settings, sleep and the power actions, then locking and logging out.
 * Items with an ellipsis confirm first (Restart…, Shut Down… with macOS's
 * 60-second countdown; Log Out…), exactly as the HIG prescribes.
 */
MenuPanel {
    id: root

    panelWidth: 240

    MenuItem {
        text: I18n.tr("system.about")
        enabled: false
    }

    MenuSeparator {}

    MenuItem {
        text: I18n.tr("system.settings")
        enabled: false
    }

    MenuSeparator {}

    MenuItem {
        text: I18n.tr("system.sleep")
        onTriggered: Session.sleep()
    }

    MenuItem {
        text: I18n.tr("system.restart")
        onTriggered: Dialogs.confirm({
            title: I18n.tr("system.restart.title"),
            message: I18n.tr("system.restart.message"),
            action: I18n.tr("system.restart.action"),
            seconds: 60,
            run: Session.restart
        })
    }

    MenuItem {
        text: I18n.tr("system.shutDown")
        onTriggered: Dialogs.confirm({
            title: I18n.tr("system.shutDown.title"),
            message: I18n.tr("system.shutDown.message"),
            action: I18n.tr("system.shutDown.action"),
            seconds: 60,
            run: Session.shutDown
        })
    }

    MenuSeparator {}

    MenuItem {
        text: I18n.tr("system.lock")
        onTriggered: Session.lock()
    }

    MenuItem {
        text: I18n.tr("system.logOut", { user: Session.user })
        onTriggered: Dialogs.confirm({
            title: I18n.tr("system.logOut.title"),
            message: I18n.tr("system.logOut.message"),
            action: I18n.tr("system.logOut.action"),
            seconds: 60,
            run: Session.logOut
        })
    }
}
