//  VELVET  ·  services/Updates.qml
//  Whether this install is out of step with itself: Velvet's Hyprland files in
//  ~/.config/hypr older than the shell's own, a zoom plugin that needs a build,
//  or Hyprland still running an older zoom plugin (it keeps the one it loaded
//  at login). Asked once a little after start (tools/update.sh --check); when
//  something is out of step a toast says so, and SUPER+TAB → SHELL → UPDATE &
//  REPAIR (tools/update.sh) puts all of it right in one go.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property bool checked: false
    property bool needed: false
    property var reasons: []

    readonly property string summary: !root.checked ? "CHECKING…" : (root.needed ? root.reasons.join("  ·  ").toUpperCase() : "EVERYTHING IS CURRENT")

    function check(): void {
        probe.running = false;
        probe.running = true;
    }

    // In a terminal, so you see each step (and a password prompt, should a
    // build need one).
    function run(): void {
        const cmd = `bash -c 'bash "$0"; echo; read -r -p "Press Enter to close" _' ${Quickshell.shellPath("tools/update.sh")}`;
        const line = Term.wrap("dev.velvet.update", "velvet-update", cmd, "");
        if (line)
            Quickshell.execDetached(["sh", "-c", line]);
        else
            Quickshell.execDetached(["bash", Quickshell.shellPath("tools/update.sh")]);
        Toast.show("UPDATING VELVET — THE SHELL RESTARTS WHEN IT IS DONE", "info", 5000);
    }

    Process {
        id: probe

        command: ["bash", Quickshell.shellPath("tools/update.sh"), "--check"]
        // the script ends with "status=pending" or "status=current" — read from
        // the text, not the exit code, which can arrive before the last line
        stdout: StdioCollector {
            onStreamFinished: root.read(text)
        }
    }

    function read(out: string): void {
        const all = (out || "").split("\n").map(l => l.trim()).filter(l => l.length > 0);
        // no verdict line: the check itself failed — say nothing rather than nag
        if (!all.some(l => l.startsWith("status=")))
            return;
        root.reasons = all.filter(l => !l.startsWith("status=")).map(l => {
            if (l.startsWith("hypr:"))
                return "Hyprland files are older";
            if (l.indexOf("running") >= 0)
                return "an older zoom plugin runs";
            if (l.startsWith("plugin:"))
                return "the zoom plugin needs a build";
            return l;
        });
        root.needed = all.indexOf("status=pending") >= 0;
        root.checked = true;
        if (root.needed)
            Toast.show(`VELVET IS OUT OF STEP: ${root.reasons.join(" · ").toUpperCase()}  ·  SUPER+TAB → SHELL → UPDATE & REPAIR`, "warn", 14000);
    }

    // qs -c velvet ipc call update run | check | status
    IpcHandler {
        target: "update"

        function run(): void {
            root.run();
        }
        function check(): void {
            root.check();
        }
        function status(): string {
            return root.summary;
        }
    }

    // after the start has settled (the zoom plugin is loaded by then)
    Timer {
        running: true
        interval: 6000
        onTriggered: root.check()
    }
}
