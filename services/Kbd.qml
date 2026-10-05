//  VELVET  ·  services/Kbd.qml
//  Keyboard state for the lock: caps lock, num lock and the active layout,
//  straight from hyprctl. Polled only while the lock is up — the fluid lock's
//  StateMessage line ("CAPS LOCK IS ON · LAYOUT US") is the one thing on
//  the lock that needs to know what the keyboard is doing, and it needs
//  it fresh.
pragma Singleton

import qs.config
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool capsLock: false
    property bool numLock: false
    property string layout: ""
    // "English (US)" → "US", "Deutsch" → "DEUTSCH" — the short chip form.
    property string layoutShort: ""

    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: Locker.locked
        onTriggered: {
            probe.running = false;
            probe.running = true;
        }
    }

    Process {
        id: probe

        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            onStreamFinished: {
                const raw = text.trim();
                if (raw.length < 10)
                    return;
                try {
                    const data = JSON.parse(raw);
                    const kbs = data?.keyboards ?? [];
                    for (let i = 0; i < kbs.length; i++) {
                        const k = kbs[i];
                        if (!k.main)
                            continue;
                        root.capsLock = !!k.capsLock;
                        root.numLock = !!k.numLock;
                        root.layout = `${k.active_keymap ?? ""}`;
                        const m = root.layout.match(/\(([^()]+)\)$/);
                        root.layoutShort = m ? m[1] : (root.layout.split(" ").pop() ?? "");
                        return;
                    }
                } catch (e) {
                    // Last reading stays.
                }
            }
        }
    }
}
