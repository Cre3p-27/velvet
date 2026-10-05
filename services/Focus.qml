//  VELVET  ·  services/Focus.qml
//  "Leave me alone" as a single switch. Nothing here has state of its own —
//  it reads Config and hands out one plain boolean per consequence, so a
//  module never has to know what focus mode means, only whether it applies.
//
//  Everything it suppresses is additive: turning focus mode off restores
//  exactly the settings you had, because it never wrote to them.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property bool active: Config.services.focusMode

    // ------------------------------------------------------------ consequences
    readonly property bool silences: root.active && Config.services.focusSilences
    readonly property bool keepsAwake: root.active && Config.services.focusKeepsAwake
    readonly property bool hidesBar: root.active && Config.services.focusHidesBar
    readonly property bool mutesShell: root.active && Config.services.focusMutesShell
    // The spotlight half: dim every window you are not looking at (through
    // the live Hyprland path) and shade the desktop behind them.
    readonly property bool dims: root.active && Config.services.focusDims
    readonly property bool shades: root.active && Config.services.focusShades

    // What the toast and the settings row say it is doing right now.
    readonly property string summary: {
        const bits = [];
        if (Config.services.focusSilences)
            bits.push("NOTIFICATIONS SILENCED");
        if (Config.services.focusKeepsAwake)
            bits.push("SCREEN STAYS AWAKE");
        if (Config.services.focusHidesBar)
            bits.push("BAR HIDDEN");
        if (Config.services.focusMutesShell)
            bits.push("SHELL MUTED");
        if (Config.services.focusDims)
            bits.push("OTHER WINDOWS DIMMED");
        return bits.length ? bits.join("  ·  ") : "NOTHING SELECTED — PICK WHAT IT DOES BELOW";
    }

    // How many notifications arrived while you were away, so coming back out
    // of focus mode tells you what you missed instead of silently dropping it.
    property int missed: 0

    function noteMissed(): void {
        if (root.silences)
            root.missed = root.missed + 1;
    }

    function set(on: bool): void {
        if (Config.services.focusMode === on)
            return;
        Config.set("services.focusMode", on);
    }

    function toggle(): void {
        root.set(!root.active);
    }

    // ------------------------------------------------------------- spotlight
    // Borrow Hyprland's dim, and give it back the moment focus goes off.
    onDimsChanged: {
        if (root.dims)
            HyprConf.overrideDim(true, Config.services.focusDimStrength);
        else
            HyprConf.reapply();
    }

    // Focus can be left on across a restart, and the shell's own startup push
    // lands at ~1.4 s; borrow the dim again just after it.
    Timer {
        running: true
        interval: 1900
        onTriggered: {
            if (root.dims)
                HyprConf.overrideDim(true, Config.services.focusDimStrength);
        }
    }

    onActiveChanged: {
        if (root.active) {
            root.missed = 0;
            Toast.show(`FOCUS MODE ON  ·  ${root.summary}`, "ok", 3200);
        } else {
            Toast.show(root.missed > 0 ? `FOCUS MODE OFF  ·  ${root.missed} NOTIFICATION${root.missed === 1 ? "" : "S"} WHILE YOU WERE AWAY` : "FOCUS MODE OFF", "info", 3200);
            root.missed = 0;
        }
    }

    // ---------------------------------------------------------------- shortcut
    GlobalShortcut {
        name: "focus"
        description: "Toggle Velvet focus mode"
        onPressed: root.toggle()
    }

    //   qs -c velvet ipc call focus toggle
    IpcHandler {
        target: "focus"

        function toggle(): void {
            root.toggle();
        }
        function on(): void {
            root.set(true);
        }
        function off(): void {
            root.set(false);
        }
        function status(): string {
            return root.active ? "on" : "off";
        }
    }
}
