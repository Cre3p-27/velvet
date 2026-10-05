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

    Process {
        id: loader

        running: true
        command: ["python3", Quickshell.shellPath("scripts/desktop_zoom.py"), "load"]
        onExited: root.ready = true
    }
}
