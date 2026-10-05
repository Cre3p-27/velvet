//  VELVET  ·  services/Pad.qml
//  Which player your game controller is — QUICK SETTINGS → CONTROLLER.
//  Games number pads in the order the kernel lists them, so a lone
//  controller is always player 1. PLAYER 2 runs bin/velvet-pad, which makes
//  the live pad come second (see that file for how). PLAYER 1 runs nothing
//  at all. The choice is in config.json, so it is re-applied at login.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property int player: Config.loaded ? Math.max(1, Math.min(2, Config.pad.player)) : 1
    readonly property string script: `${Qt.resolvedUrl("../bin/velvet-pad")}`.replace(/^file:\/\//, "")
    readonly property string statePath: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/velvet-pad.json`

    // What the helper reports: the pads it holds, in player order.
    property var pads: []
    readonly property bool active: root.player === 2 && root.pads.length > 0
    readonly property string summary: {
        if (root.player !== 2)
            return "KERNEL ORDER";
        if (root.pads.length === 0)
            return "WAITING FOR A CONTROLLER";
        const p = root.pads[0];
        return `${p.name.toUpperCase()} · ${p.bus.toUpperCase()} · PLAYER ${p.player}`;
    }

    // Steam hands games a virtual pad in its OWN order; the helper moves the
    // pad to Steam's slot 2 through Steam's local DevTools port (bin/_steam.py).
    // state: off | no-steam | idle | needs-flag | needs-restart | closed |
    //        ready | applied | stuck | several | error
    property var steam: ({
            state: "off",
            detail: "",
            slot: 0
        })
    readonly property string steamState: root.player === 2 ? (root.steam.state ?? "off") : "off"
    readonly property bool steamVisible: ["needs-flag", "needs-restart", "closed", "applied", "stuck", "several", "error", "ready"].indexOf(root.steamState) >= 0
    readonly property string steamLabel: {
        switch (root.steamState) {
        case "needs-flag":
            return "STEAM · ALLOW ORDER";
        case "needs-restart":
            return "STEAM · RESTART IT";
        case "applied":
            return "STEAM · PLAYER 2";
        case "closed":
            return "STEAM · STARTING";
        case "several":
            return "STEAM · SEVERAL PADS";
        case "ready":
            return "STEAM · CHECKING";
        default:
            return "STEAM · NOT SWITCHED";
        }
    }

    property bool steamHinted: false

    onSteamStateChanged: {
        if (root.steamState === "needs-flag" && !root.steamHinted) {
            root.steamHinted = true;
            Toast.warn("Steam games need one more step for player 2 — tap STEAM · ALLOW ORDER in Quick Settings");
        }
    }

    function steamTap(): void {
        switch (root.steamState) {
        case "needs-flag":
            Quickshell.execDetached(["python3", root.script, "steam", "enable"]);
            Toast.warn("Steam: close it completely and start it once more — then player 2 reaches Steam games");
            break;
        case "needs-restart":
            Toast.warn("Steam: close it completely (Steam → Exit) and start it again");
            break;
        case "applied":
            Toast.ok("Steam has your controller on player 2");
            break;
        case "several":
            Toast.warn("Several controllers: Steam's order is left to you (Steam → Controller order)");
            break;
        default:
            Toast.warn(root.steam.detail ? `Steam: ${root.steam.detail}` : "Steam is not switched yet");
        }
    }

    // Games that read the pad straight from hidraw (SDL's HIDAPI, Steam, Wine)
    // ignore the evdev arrangement; this wraps a program so they do not.
    readonly property string launchOption: `${root.script} launch -- %command%`
    readonly property string launchPrefix: "export SDL_JOYSTICK_HIDAPI=0; "

    function copyLaunchOption(): void {
        Hypr.exec(`printf '%s' '${root.launchOption}' | wl-copy`);
        Toast.ok("Launch option copied — for games that run without Steam Input");
    }

    function toggle(): void {
        root.setPlayer(root.player === 2 ? 1 : 2);
    }

    function setPlayer(n: int): void {
        Config.set("pad.player", n === 2 ? 2 : 1);
    }

    onPlayerChanged: {
        root.pads = [];
        root.steam = {
            state: "off",
            detail: "",
            slot: 0
        };
    }

    Process {
        id: helper

        command: ["python3", root.script, "run", "--player", "2"]
        running: root.player === 2
        onExited: root.pads = []
    }

    // The helper ends its grabs when it ends; this just makes sure a stale
    // one from before a shell reload is gone too.
    Process {
        id: stopper

        command: ["python3", root.script, "stop"]
        running: Config.loaded && root.player === 1
    }

    Timer {
        interval: 1500
        repeat: true
        running: root.player === 2
        onTriggered: padState.reload()
    }

    FileView {
        id: padState

        path: root.statePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.pads = Array.isArray(data.slots) ? data.slots : [];
                root.steam = data.steam ?? {
                    state: "off",
                    detail: "",
                    slot: 0
                };
            } catch (e) {
                root.pads = [];
            }
        }
        onLoadFailed: root.pads = []
    }
}
