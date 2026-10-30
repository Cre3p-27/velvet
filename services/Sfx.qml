//  VELVET  ·  services/Sfx.qml
//  The shell's sounds. Every one is loaded once and played straight from
//  memory (QtMultimedia's SoundEffect): a sound starts with the click that
//  asked for it. (It used to start a player program per click and arrived
//  late — the clicks felt detached from the hand.)
//
//  Two sets, in one key (tools/make_sounds.py) — SHELL → SOUND → SOUNDS:
//    soft   little wooden taps, felt more than heard
//    glass  small crystal bells with a quiet ring
//  and Velly's own chirps (assets/sfx/velly), the same in both.
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
    readonly property string set: ["soft", "glass"].indexOf(Config.sfx.set) >= 0 ? Config.sfx.set : "soft"
    // (kept for old callers that waited for a player to be found)
    readonly property string player: "soundeffect"

    readonly property var names: ["cursor", "select", "back", "open", "close", "toggle", "launch", "whoosh", "quest", "charge", "tick", "nope", "pop", "boing", "snap"]
    readonly property var velly: ["wake", "listen", "heard", "done", "error", "giggle", "purr"]
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
        e.volume = Math.max(0, Math.min(1, Config.sfx.volume * (gain > 0 ? gain : 1) * (fidget ? Config.sfx.fidgetVolume : 1)));
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

    onSetChanged: {
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
                    file: `${root.dir}/${root.set}/${n}.wav`
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
