import QtQuick
import Quickshell
import Quickshell.Services.Pam

/**
 * Checks the user's password with PAM (the "login" service, like the console
 * login). `submit` starts a conversation and answers its password prompt;
 * the outcome arrives as `succeeded` or `failed`. The password is dropped as
 * soon as PAM has it.
 */
Item {
    id: root

    readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || ""
    readonly property bool busy: pam.active
    /** PAM's own error text, if it said anything. */
    property string message: ""

    signal succeeded()
    signal failed()

    property string pending: ""

    function submit(password) {
        if (pam.active || !password.length)
            return;
        message = "";
        pending = password;
        pam.start();
    }

    PamContext {
        id: pam
        config: "login"
        user: root.user

        onResponseRequiredChanged: {
            if (responseRequired) {
                respond(root.pending);
                root.pending = "";
            }
        }
        onPamMessage: {
            if (messageIsError && message.length)
                root.message = message;
        }
        onCompleted: result => {
            root.pending = "";
            if (result === PamResult.Success)
                root.succeeded();
            else
                root.failed();
        }
        onError: {
            root.pending = "";
            root.failed();
        }
    }
}
