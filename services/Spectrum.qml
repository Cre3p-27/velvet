//  VELVET  ·  services/Spectrum.qml
//  The sound of the desktop.
//
//  bin/velvet-levels runs cava and writes a tiny JSON of eased bands to
//  ~/.config/velvet/levels.json. This service reads that file at 30 Hz while
//  something is audible and at 2 Hz while it is not (`live` says which, so
//  the file itself sets our polling rate), and hands the bands to whoever
//  wants to breathe with the music: the island's waveform, the bar's media
//  entry, the wave on the wallpaper.
//
//  Honest by construction — no cava, no levels. `available` goes false and
//  every consumer hides, because a meter that pretends is worse than none.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string path: `${Quickshell.env("HOME")}/.config/velvet/levels.json`
    readonly property string script: `${Qt.resolvedUrl("../bin/velvet-levels")}`.replace(/^file:\/\//, "")

    // Master switch — MODULES → AUDIO-REACTIVE (the desktop's surfaces),
    // plus the lock's own visualizer. Nobody watching, nobody listening:
    // with every surface switched off, cava and the sidecar do not run.
    // The lock's visualizer is its own switch (LOCK SCREEN → CAVA
    // VISUALIZER) and does not wait for the desktop's master switch: it
    // counts while the screen is actually locked — or while its live
    // preview (SETTINGS → LOCK SCREEN) is on screen.
    property bool lockPreview: false
    readonly property bool enabled: (Config.services.audioReactive && (Config.services.audioIsland || Config.services.audioBar || Config.services.audioWave)) || ((Config.lock.visualizer || ((Config.lock.vViz || Config.lock.vGlow) && Config.lock.look === "vibe")) && (Locker.locked || root.lockPreview))
        // the desk's CAVA modules, drawn on the wallpaper
        || (Scenes.drawnItems.length > 0 && !Locker.locked)

    property bool available: true    // false once the sidecar says cava is missing
    property bool live: false        // something was audible in the last few seconds
    property real level: 0           // overall loudness 0..1, eased down the pipe
    property var bands: []           // eased bands, 0..1

    readonly property int count: root.bands.length

    function at(i: int): real {
        return (i >= 0 && i < root.bands.length) ? root.bands[i] : 0;
    }

    // The average of the i-th of `of` slices of the spectrum: four equal bars
    // for the bar's media entry, twenty-four lines for the wallpaper.
    function group(i: int, of: int): real {
        if (of <= 0 || root.bands.length === 0)
            return 0;
        const from = Math.floor(i * root.bands.length / of);
        const to = Math.max(from + 1, Math.floor((i + 1) * root.bands.length / of));
        let sum = 0;
        let n = 0;
        for (let b = from; b < to && b < root.bands.length; b++) {
            sum += root.bands[b];
            n++;
        }
        return n > 0 ? sum / n : 0;
    }

    function ingest(raw: var): void {
        const s = `${raw ?? ""}`.trim();
        if (s.length < 8)
            return;
        let data = null;
        try {
            data = JSON.parse(s);
        } catch (e) {
            // A half-written frame must not blank the desktop — keep the
            // last good one and wait for the next poll.
            return;
        }
        if (!data || !data.bands)
            return;
        root.available = (data.available ?? 1) === 1;
        root.live = root.enabled && (data.live ?? 0) === 1;
        root.level = Number(data.level) || 0;
        root.bands = data.bands;
    }

    onEnabledChanged: {
        if (!root.enabled) {
            root.live = false;
            root.level = 0;
            root.bands = [];
        }
    }

    // The sidecar: cava in, levels.json out. Dies with the shell, and on its
    // own if it ever gets orphaned.
    Process {
        id: sidecar

        running: root.enabled
        command: ["python3", root.script]
    }

    // Poll while audible, idle-slow while quiet: the file is a few hundred
    // bytes and the reads cost less than a frame of animation.
    Timer {
        id: poll

        running: root.enabled
        interval: root.live ? 33 : 500
        repeat: true
        onTriggered: file.reload()
    }

    FileView {
        id: file

        path: root.path
        printErrors: false
        preload: true
        onTextChanged: root.ingest(file.text())
    }

    //   qs -c velvet ipc call spectrum status
    IpcHandler {
        target: "spectrum"

        function status(): string {
            return JSON.stringify({
                enabled: root.enabled,
                available: root.available,
                live: root.live,
                level: Math.round(root.level * 1000) / 1000,
                bands: root.bands
            });
        }
    }
}
