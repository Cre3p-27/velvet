//  VELVET  ·  services/Sfx.qml
//  The shell's sounds. Every one is loaded once and played straight from
//  memory (QtMultimedia's SoundEffect): a sound starts with the click that
//  asked for it. (It used to start a player program per click and arrived
//  late — the clicks felt detached from the hand.)
//
//  Six timbres in one key (tools/make_sounds.py) — SHELL → SOUND → SOUNDS:
//  soft (wooden taps) · glass (crystal bells) · pop (bubbles) · pluck (a
//  kalimba) · keys (a good keyboard) · digital (clean blips). PITCH,
//  BRIGHTNESS and LENGTH reshape any of them: the set is made anew (in a
//  fraction of a second, kept in ~/.cache/velvet/sounds per setting). Each
//  kind of sound has its own loudness, and a WAV of your own in
//  ~/.config/velvet/sounds/<name>.wav replaces that one sound.
//  Velly's chirps (assets/sfx/velly) are her own.
//
//  Quiet on purpose: no sound when the pointer only passes over things
//  (HOVER SOUNDS, off by default), the cursor's tap is rate-limited, and the
//  sounds you hear most are the softest.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQml
import QtQuick
import QtMultimedia

Singleton {
    id: root

    readonly property string dir: `${Qt.resolvedUrl("../assets/sfx")}`.replace(/^file:\/\//, "")
    readonly property string set: ["soft", "glass", "pop", "pluck", "keys", "digital"].indexOf(Config.sfx.set) >= 0 ? Config.sfx.set : "soft"
    readonly property string maker: `${Qt.resolvedUrl("../tools/make_sounds.py")}`.replace(/^file:\/\//, "")
    readonly property string mine: `${Quickshell.env("HOME")}/.config/velvet/sounds`

    // the dials: at their defaults the shipped set plays; otherwise a set
    // made for exactly these dials (one folder per setting, so the players
    // load it anew)
    readonly property real pitch: Math.round(Math.max(-12, Math.min(12, Config.sfx.pitch)))
    readonly property real bright: Math.round(Math.max(0, Math.min(1, Config.sfx.bright)) * 20) / 20
    readonly property real length: Math.round(Math.max(0.5, Math.min(2, Config.sfx.length)) * 20) / 20
    readonly property bool shaped: root.pitch !== 0 || root.bright !== 0.5 || root.length !== 1
    readonly property string shapedDir: `${Quickshell.env("HOME")}/.cache/velvet/sounds/${root.set}_p${root.pitch}_b${root.bright}_l${root.length}`
    property string setDir: `${root.dir}/${root.set}`
    // the names you put a WAV of your own in for
    property var own: ({})

    readonly property var kind: ({
            cursor: "vClicks",
            select: "vClicks",
            back: "vClicks",
            toggle: "vSwitches",
            snap: "vSwitches",
            open: "vWindows",
            close: "vWindows",
            launch: "vWindows",
            whoosh: "vWindows",
            quest: "vSuccess",
            charge: "vSuccess"
        })

    function remake(): void {
        if (!root.shaped) {
            root.setDir = `${root.dir}/${root.set}`;
            return;
        }
        shaper.command = ["bash", "-c", `[ -s "$1/select.wav" ] || python3 "$2" --timbre "$3" --pitch "$4" --bright "$5" --length "$6" --out "$1" >/dev/null 2>&1; [ -s "$1/select.wav" ] && echo ok`, "shape", root.shapedDir, root.maker, root.set, `${root.pitch}`, `${root.bright}`, `${root.length}`];
        shaper.running = false;
        shaper.running = true;
    }

    onShapedDirChanged: remakeSoon.restart()
    onShapedChanged: remakeSoon.restart()
    onSetChanged: remakeSoon.restart()

    Timer {
        id: remakeSoon

        interval: 250
        onTriggered: root.remake()
    }

    Process {
        id: shaper

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.indexOf("ok") >= 0)
                    root.setDir = root.shapedDir;
            }
        }
    }

    // your own WAVs: looked for at start and whenever the settings open
    function findOwn(): void {
        ownFinder.running = false;
        ownFinder.running = true;
    }

    Process {
        id: ownFinder

        running: true
        command: ["bash", "-c", `mkdir -p "$1" && cd "$1" && ls -1 -- *.wav 2>/dev/null`, "own", root.mine]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n"))
                    if (l.endsWith(".wav"))
                        o[l.slice(0, -4)] = true;
                root.own = o;
            }
        }
    }

    Connections {
        target: Panels

        function onSettingsChanged(): void {
            if (Panels.settings)
                root.findOwn();
        }
    }
    // (kept for old callers that waited for a player to be found)
    readonly property string player: "soundeffect"

    readonly property var names: ["cursor", "select", "back", "open", "close", "toggle", "launch", "whoosh", "quest", "charge", "tick", "nope", "pop", "boing", "snap"]
    readonly property var velly: ["wake", "listen", "heard", "done", "error", "giggle", "purr", "boing", "whee"]
    // the fidget sounds (FIDGET FEEL)
    readonly property var shared: ["tick", "nope", "pop", "boing", "snap"]

    // name → its loaded SoundEffect
    property var fx: ({})

    function play(name: string, gain: real): var {
        if (!Config.sfx.enabled || Focus.mutesShell)
            return null;
        const fidget = root.shared.indexOf(name) >= 0;
        if (fidget && !Config.sfx.fidget)
            return null;
        const e = root.fx[name];
        if (!e)
            return null;
        const k = name.startsWith("velly:") ? Config.sfx.vVelly : (root.kind[name] ? Config.sfx[root.kind[name]] : 1);
        if (k <= 0)
            return null;
        e.volume = Math.max(0, Math.min(1, Config.sfx.volume * (gain > 0 ? gain : 1) * (fidget ? Config.sfx.fidgetVolume : 1) * k));
        e.stop();
        e.play();
        return e;
    }

    // moving through a list with the keys: a tap, never a rattle
    property double lastCursor: 0

    function cursor(): void {
        const now = Date.now();
        if (now - root.lastCursor < 70)
            return;
        root.lastCursor = now;
        play("cursor", 0.8);
    }
    // the pointer passing over something: silent unless HOVER SOUNDS is on
    function hover(): void {
        if (Config.sfx.hover)
            root.cursor();
    }
    // FIDGET FEEL lays a small tick under a press and a flip
    function select(): void {
        play("select");
        if (Config.sfx.fidget)
            root.tick(0.25);
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

    // ── FIDGET FEEL: the toy sounds. A tick is rate-limited, so a slider
    // dragged fast clicks like a ratchet instead of buzzing.
    property double lastTick: 0

    function tick(gain: real): void {
        const now = Date.now();
        if (now - root.lastTick < 45)
            return;
        root.lastTick = now;
        play("tick", gain > 0 ? gain : 0.7);
    }
    function nope(): void {
        play("nope", 0.8);
    }
    function pop(): void {
        play("pop", 0.75);
    }
    function boing(): void {
        play("boing", 0.7);
    }
    function snap(): void {
        play("snap", 0.85);
    }

    // Finishing a task — SHELL → GAME FEEL.
    function quest(): void {
        play("quest");
    }

    // Charging the long press that wakes Velly: it starts once the press has
    // proven it is a hold, and a hold that turns into a drag cuts it off.
    property var charging: null

    function charge(): void {
        root.charging = play("charge", 0.7);
    }

    function stopCharge(): void {
        if (root.charging)
            root.charging.stop();
        root.charging = null;
    }

    // ── Velly's chirps: wake · listen · heard · done · error · giggle · purr
    function chirp(name: string): void {
        if (!Config.sfx.velly)
            return;
        play(`velly:${name}`, 1);
    }

    // SHELL → SOUND → SOUNDS: changing the set plays a little of it, so you
    // hear what you chose
    function demo(): void {
        demoRun.step = 0;
        demoRun.restart();
    }

    property bool settled: false

    // a new sound to hear: play a little of it (not at start)
    onSetDirChanged: {
        if (root.settled)
            demoSoon.restart();
    }

    Timer {
        running: true
        interval: 5000
        onTriggered: root.settled = true
    }

    // the new set needs a moment to load
    Timer {
        id: demoSoon

        interval: 450
        onTriggered: root.demo()
    }

    Timer {
        id: demoRun

        property int step: 0
        interval: 260
        repeat: true
        onTriggered: {
            const order = ["select", "toggle", "back", "quest"];
            if (demoRun.step >= order.length) {
                demoRun.stop();
                return;
            }
            root.play(order[demoRun.step++], 1);
        }
    }

    Instantiator {
        model: root.names.map(n => ({
                    key: n,
                    file: root.own[n] ? `${root.mine}/${n}.wav` : `${root.setDir}/${n}.wav`
                })).concat(root.velly.map(n => ({
                    key: `velly:${n}`,
                    file: `${root.dir}/velly/${n}.wav`
                })))

        delegate: SoundEffect {
            required property var modelData

            source: `file://${modelData.file}`
        }

        onObjectAdded: (i, o) => {
            const next = Object.assign({}, root.fx);
            next[o.modelData.key] = o;
            root.fx = next;
        }
        onObjectRemoved: (i, o) => {
            const next = Object.assign({}, root.fx);
            if (next[o.modelData.key] === o)
                delete next[o.modelData.key];
            root.fx = next;
        }
    }
}
