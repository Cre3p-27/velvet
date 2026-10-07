//  VELVET  ·  services/ZoomPlugin.qml
//  Loads the desktop zoom-out plugin (plugin/velvetzoom) into Hyprland when the
//  shell starts, so the very first SUPER+ALT+wheel notch is already taken in
//  the compositor — smooth — instead of waking a script. Nothing happens when
//  the plugin was not built or does not match this Hyprland: the zoom keeps
//  its older fallback. Safe to run again (it only loads when not loaded).
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool ready: false

    // The plugin build this shell expects. Hyprland keeps the build it loaded
    // at login, so after an update the running one can be older — say so, and
    // how to fix it without logging out.
    readonly property string want: "0.6"
    property string loaded: ""

    Process {
        id: loader

        running: true
        command: ["python3", Quickshell.shellPath("scripts/desktop_zoom.py"), "load"]
        onExited: {
            root.ready = true;
            version.running = true;
        }
    }

    Process {
        id: version

        command: ["hyprctl", "plugin", "list", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {}
                const p = (list || []).find(x => x && x.name === "velvetzoom");
                root.loaded = p ? String(p.version) : "";
                // an older one still running is reported by Updates, whose
                // UPDATE & REPAIR swaps it in place
            }
        }
    }
}
