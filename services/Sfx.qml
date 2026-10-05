//  VELVET  ·  services/Sfx.qml
//  The menu clicks. A round-robin pool of players so rapid navigation
//  overlaps instead of cutting itself off.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQml
import QtQuick

Singleton {
    id: root

    // Resolved relative to this file so the shell works from any install path.
    readonly property string dir: `${Qt.resolvedUrl("../assets/sfx")}`.replace(/^file:\/\//, "")
    property string player: ""
    property int channel: 0
    // Which channel the current charge riser is on, so a hold that turns into
    // a drag can cut it off instead of letting it ring on over the swipe.
    property int chargeChannel: -1

    readonly property var files: ({
            cursor: "cursor.wav",
            select: "select.wav",
            back: "back.wav",
            open: "open.wav",
            close: "close.wav",
            toggle: "toggle.wav",
            launch: "launch.wav",
            whoosh: "whoosh.wav",
            quest: "quest.wav",
            charge: "charge.wav"
        })

    function play(name: string, gain: real): int {
        if (!Config.sfx.enabled || root.player === "" || Focus.mutesShell)
            return -1;

        const pack = ["arcade", "cyber", "terminal", "paper", "glass", "rpg", "brutal", "clean", "windows"].indexOf(Config.sfx.pack) >= 0 ? `${root.dir}/${Config.sfx.pack}` : root.dir;
        const file = `${pack}/${root.files[name] ?? root.files.cursor}`;
        const vol = Config.sfx.volume * (gain > 0 ? gain : 1);

        let cmd;
        if (root.player === "pw-play")
            cmd = ["pw-play", `--volume=${vol.toFixed(2)}`, file];
        else if (root.player === "paplay")
            cmd = ["paplay", `--volume=${Math.round(vol * 65536)}`, file];
        else
            cmd = ["aplay", "-q", file];

        const index = root.channel;
        const p = pool.objectAt(index);
        if (p) {
            p.command = cmd;
            p.running = false;
            p.running = true;
        }
        root.channel = (root.channel + 1) % pool.count;
        return index;
    }

    function cursor(): void {
        play("cursor");
    }
    function select(): void {
        play("select");
    }
    function back(): void {
        play("back");
    }
    function open(): void {
        play("open");
    }
    function close(): void {
        play("close");
    }
    function toggle(): void {
        play("toggle");
    }
    function launch(): void {
        play("launch");
    }
    function whoosh(): void {
        play("whoosh");
    }

    // Finishing a task — the game-menu flourish, SHELL → GAME FEEL.
    function quest(): void {
        play("quest");
    }

    // Charging the long press that wakes Velly. It plays once at the start of
    // the hold and runs out exactly when the pill's hairline fills — and it
    // only ever starts once the press has proven it is a hold, never on the
    // press that was really the beginning of a swipe.
    function charge(): void {
        root.chargeChannel = play("charge", 0.7);
    }

    function stopCharge(): void {
        if (root.chargeChannel < 0)
            return;
        const p = pool.objectAt(root.chargeChannel);
        if (p)
            p.running = false;
        root.chargeChannel = -1;
    }

    Instantiator {
        id: pool
        model: 8
        delegate: Process {
            command: ["true"]
        }
    }

    Process {
        id: detect

        running: true
        command: ["bash", "-c", "for p in pw-play paplay aplay; do command -v $p >/dev/null 2>&1 && { echo $p; break; }; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim();
                root.player = Config.sfx.player !== "auto" ? Config.sfx.player : found;
            }
        }
    }
}
