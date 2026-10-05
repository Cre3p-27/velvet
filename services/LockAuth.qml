//  VELVET  ·  services/LockAuth.qml
//  The only file in the shell that imports PAM.
//
//  Quickshell's PAM support is a build-time option. On a build without it the
//  import below fails — and if that import lived in Locker.qml, the whole
//  service would fail to load and locking would simply do nothing, silently,
//  with no way to tell why. So it lives here, Locker creates this file with
//  Qt.createComponent(), and a failure comes back as an error string it can
//  show you instead of as silence.
import Quickshell.Services.Pam
import QtQuick

QtObject {
    id: root

    property string service: "login"
    property string username: ""
    property string pending: ""

    signal succeeded
    signal rejected
    signal errored(string reason)
    signal prompted          // PAM asked us something: proof it works here
    signal note(string text)

    function isSuccess(result: var): bool {
        if (typeof PamResult !== "undefined" && PamResult.Success !== undefined)
            return result === PamResult.Success;
        return result === 0;
    }

    function authenticate(password: string): bool {
        root.pending = password;
        return auth.start();
    }

    function abort(): void {
        root.pending = "";
        auth.abort();
    }

    function probe(): bool {
        return prober.start();
    }

    function abortProbe(): void {
        prober.abort();
    }

    readonly property PamContext auth: PamContext {
        config: root.service
        user: root.username

        onPamMessage: {
            if (auth.responseRequired) {
                root.prompted();
                auth.respond(root.pending);
            } else if (auth.message && !auth.messageIsError) {
                root.note(auth.message.toUpperCase());
            }
        }

        onCompleted: result => {
            root.pending = "";
            if (root.isSuccess(result))
                root.succeeded();
            else
                root.rejected();
        }

        onError: err => {
            root.pending = "";
            root.errored(`PAM ERROR (${err})`);
        }
    }

    // A conversation opened purely to see whether it reaches a prompt. Getting
    // there is what proves unlocking will be possible later.
    readonly property PamContext prober: PamContext {
        config: root.service
        user: root.username

        onPamMessage: {
            if (prober.responseRequired) {
                root.prompted();
                prober.abort();
            }
        }

        onError: err => root.errored(`PAM ERROR (${err})`)
    }
}
