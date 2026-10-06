//  VELVET  ·  services/Actions.qml
//  Everything the settings menu can "do" rather than "set".
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property int _channel: 0

    function run(command: string): void {
        if (!command)
            return;
        const p = pool.objectAt(root._channel);
        if (p) {
            p.command = ["bash", "-c", command];
            p.running = false;
            p.running = true;
        }
        root._channel = (root._channel + 1) % pool.count;
    }

    // Locker decides: its own lock screen when it is enabled AND PAM has
    // proven it can authenticate, otherwise whatever locker you already had.
    function lock(): void {
        Locker.lock();
    }
    // Lock first and give the lock surface a beat to appear, so the
    // machine wakes up to the lock screen instead of the open desktop.
    function suspend(): void {
        if (Config.lock.listenToLogind && Locker.canLock && !Locker.locked) {
            Locker.lock();
            sleepLater.restart();
            return;
        }
        run("systemctl suspend");
    }

    Timer {
        id: sleepLater

        interval: 700
        onTriggered: root.run("systemctl suspend")
    }
    function hibernate(): void {
        run("systemctl hibernate");
    }
    function reboot(): void {
        run("systemctl reboot");
    }
    function shutdown(): void {
        run("systemctl poweroff");
    }
    function logout(): void {
        Hypr.exitSession();
    }
    function reloadHyprland(): void {
        run("hyprctl reload");
    }
    // Back through velvet-session, so the restarted shell is looked after
    // again (crash → restart). It waits until the old one is really gone:
    // the new one starts with --no-duplicate and would otherwise give way to
    // the shell that is still on its way out.
    function restartShell(): void {
        Quickshell.execDetached(["bash", "-c", "qs -c velvet kill >/dev/null 2>&1; for i in $(seq 40); do qs -c velvet ipc show >/dev/null 2>&1 || break; sleep 0.2; done; setsid -f \"$1\" >/dev/null 2>&1", "velvet", Quickshell.shellPath("bin/velvet-session")]);
    }

    Instantiator {
        id: pool
        model: 6
        delegate: Process {
            command: ["true"]
            // A button whose program is not installed used to do nothing at
            // all (the screenshot button without grim/slurp/wl-copy). Say
            // which program is missing instead of staying silent.
            stderr: StdioCollector {
                onStreamFinished: {
                    const missing = [];
                    const re = /([\w.+-]+): (?:command not found|Befehl nicht gefunden)/g;
                    let m;
                    while ((m = re.exec(`${text ?? ""}`)) !== null)
                        if (missing.indexOf(m[1]) < 0)
                            missing.push(m[1]);
                    if (missing.length > 0)
                        Toast.show(`NICHT INSTALLIERT  ·  ${missing.join(", ").toUpperCase()}`, "error", 5000);
                }
            }
        }
    }
}
