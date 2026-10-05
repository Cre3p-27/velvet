//  VELVET  ·  services/Combo.qml
//  The combo meter — game juice for the ordinary desktop.
//
//  Quick, related actions chain: open a window, switch a desktop, finish a
//  task, and a small counter keeps the streak. It decays after a few quiet
//  seconds, so a chain is something you did, not something you have. The
//  chip that shows it is modules/osd/Combo.qml; this service owns only the
//  arithmetic, so any module can feed it and any module could show it.
//
//  Nothing here fires unless it is switched on in SHELL → GAME FEEL.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool enabled: Config.services.comboMeter

    // How long a chain survives without a new hit, and how long the chip
    // stays up after the last one. The chip outlives the chain on purpose:
    // you should see the streak you just lost, not have it blink away.
    readonly property int chainWindow: 4200
    readonly property int chipHold: 1900

    property int count: 0
    property int best: 0
    property bool shown: false
    property double lastHit: 0
    // The workspace id also changes once while the shell settles; chains only
    // start after that, so boot noise never fakes a streak.
    property bool settled: false

    // Milestones get a word and a whoosh; everything else gets the tick.
    readonly property var milestones: ({
            3: "TRIPLE",
            5: "ON A ROLL",
            8: "UNSTOPPABLE",
            12: "LEGENDARY"
        })

    function hit(what: string): void {
        if (!root.enabled)
            return;
        const now = Date.now();
        if (now - root.lastHit > root.chainWindow)
            root.count = 0;
        root.lastHit = now;
        root.count = root.count + 1;
        if (root.count > root.best)
            root.best = root.count;
        root.shown = true;
        decay.restart();
        if (what === "quest")
            Sfx.launch();
        else if (root.milestones[root.count] !== undefined)
            Sfx.whoosh();
        else
            Sfx.cursor();
    }

    function reset(): void {
        root.count = 0;
        root.shown = false;
    }

    Timer {
        running: true
        interval: 1600
        onTriggered: root.settled = true
    }

    Timer {
        id: decay

        interval: root.chipHold
        onTriggered: {
            root.shown = false;
            root.count = 0;
        }
    }

    // ── what counts as a chain ─────────────────────────────────────────────
    //  Windows arriving and desktops changing are the two rhythms of a
    //  working desktop; tasks finishing are the third. Listening here — on
    //  the services, not in the widgets — means every source counts no
    //  matter which screen or module it happened through.

    Connections {
        target: Hypr

        function onWindowOpened(): void {
            root.hit("window");
        }
        function onActiveWsIdChanged(): void {
            if (root.settled)
                root.hit("desktop");
        }
    }

    //   qs -c velvet ipc call combo status   ·   hit
    IpcHandler {
        target: "combo"

        function hit(): void {
            root.hit("ipc");
        }
        function status(): string {
            return `${root.count}${root.shown ? " shown" : ""} best ${root.best}`;
        }
    }
}
