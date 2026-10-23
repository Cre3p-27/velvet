//  VELVET  ·  services/NightShift.qml
//  Velly's night shift. When every screen has been dark for a while — switched
//  off, unplugged, or in standby — and no game holds the card, she works:
//  bin/velvet-night runs the books (bin/velvet-books), live wallpapers for new
//  favourites, her memory, the update count. The moment a screen wakes it
//  stops (SIGTERM reaches every job, the brain is put back to sleep), and the
//  first thing you see in the morning is what she did.
//
//  SCREEN OFF AFTER puts the screens into standby after N idle minutes — never
//  under a fullscreen window or while something plays. A monitor that stays
//  "connected" when its power button is pressed cannot be seen switching off
//  (the kernel reports nothing); the standby can. Any key or the mouse wakes
//  them again (`waker`, a one-second idle watch while they are off).
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

Singleton {
    id: root

    readonly property string helper: `${Qt.resolvedUrl("../bin/velvet-night")}`.replace(/^file:\/\//, "")
    readonly property string dir: `${Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")}/velvet`

    property bool known: false
    property bool dark: false
    property string darkWhy: ""
    property bool darkLong: false        // dark for START AFTER minutes
    property bool manual: false          // START NOW: works with the screen on, once
    property bool offByUs: false         // the standby is ours: input wakes the screens
    property var night: ({})             // ~/.config/velvet/night.json
    property string summaryLine: ""
    property string shownNight: "-"      // the night whose morning note was shown

    readonly property bool working: worker.running
    readonly property string doing: `${root.night.doing ?? ""}`
    readonly property bool wanted: Config.loaded && Config.night.enabled && (root.manual || (root.dark && root.darkLong))

    readonly property string status: {
        if (!Config.night.enabled)
            return "OFF";
        if (root.working)
            return root.doing ? `WORKING · ${root.doing.toUpperCase()}` : "WORKING";
        if (root.dark && !root.darkLong)
            return `SCREENS DARK · STARTS IN ${Math.max(1, Config.night.startAfter)} MIN`;
        if (root.dark)
            return "RESTING · NOTHING LEFT FOR NOW · LOOKS AGAIN IN 30 MIN";
        return "WAITS FOR THE SCREENS TO GO DARK";
    }
    readonly property string screenLine: !root.known ? "…" : (root.dark ? `DARK · ${root.darkWhy.toUpperCase()}` : `LIT · ${root.darkWhy.replace(/^lit: /, "").toUpperCase()}`)
    readonly property string lastLine: root.summaryLine.length > 0 ? root.summaryLine.toUpperCase() : "NOTHING YET"

    onWantedChanged: {
        if (root.wanted && !worker.running) {
            worker.running = true;
        } else if (!root.wanted && worker.running) {
            worker.running = false;
        }
    }

    onDarkChanged: {
        if (root.dark) {
            darkTimer.restart();
        } else {
            darkTimer.stop();
            root.darkLong = false;
            if (root.offByUs)
                root.offByUs = false;
            morning.restart();
        }
    }

    Timer {
        id: darkTimer

        interval: Math.max(0.05, Config.night.startAfter) * 60000
        onTriggered: root.darkLong = root.dark
    }

    // ── the screens: sysfs and hyprctl every 15 s, and at once on a monitor event
    Process {
        id: probe

        command: ["python3", root.helper, "screen"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.darkWhy = `${d.why ?? ""}`;
                    root.dark = d.dark === true;
                    root.known = true;
                } catch (e) {}
            }
        }
    }

    function look(): void {
        probe.running = false;
        probe.running = true;
    }

    Timer {
        running: Config.loaded && Config.night.enabled
        interval: 15000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.look()
    }

    Timer {
        id: lookSoon

        interval: 1500
        onTriggered: root.look()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.startsWith("monitor") || n === "dpms")
                lookSoon.restart();
        }
    }

    // ── the worker
    Process {
        id: worker

        command: ["nice", "-n", "8", "python3", root.helper, "run"]
        onRunningChanged: {
            stateFile.reload();
            if (!running) {
                root.manual = false;
                // ended by itself (nothing left, the shelf full): look again in half an hour
                if (root.wanted)
                    retry.restart();
            }
        }
    }

    Timer {
        id: retry

        interval: 30 * 60000
        onTriggered: {
            if (root.wanted && !worker.running)
                worker.running = true;
        }
    }

    function startNow(): void {
        root.manual = true;
        if (!worker.running)
            worker.running = true;
        Toast.show("VELLY STARTS HER NIGHT SHIFT NOW", "info", 2600);
    }

    function stop(): void {
        root.manual = false;
        retry.stop();
        worker.running = false;
    }

    FileView {
        id: stateFile

        path: `${root.dir}/night.json`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.night = JSON.parse(text());
            } catch (e) {}
        }
    }

    // ── the morning: what she did, once per night
    Timer {
        id: morning

        interval: 4000
        onTriggered: {
            summary.running = false;
            summary.running = true;
        }
    }

    Process {
        id: summary

        command: ["python3", root.helper, "summary"]
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.trim();
                root.summaryLine = line;
                const key = `${root.night.night ?? ""}` || new Date(Date.now() - 12 * 3600000).toDateString();
                if (line.length > 0 && key !== root.shownNight && !root.working) {
                    root.shownNight = key;
                    Toast.show(`VELLY'S NIGHT · ${line.toUpperCase()}`, "ok", 9000);
                    notify.command = ["notify-send", "-a", "Velly", "-i", "auto_awesome", "Velly · Nachtschicht", line];
                    notify.running = true;
                }
            }
        }
    }

    Process {
        id: notify

        command: ["true"]
    }

    // ── SCREEN OFF AFTER
    IdleMonitor {
        id: idle

        enabled: Config.loaded && Config.night.screenOff > 0
        timeout: Math.max(1, Config.night.screenOff) * 60
        respectInhibitors: true
        onIsIdleChanged: {
            console.log(`Velvet: night — ${idle.isIdle ? "idle" : "active again"} (screen off after ${idle.timeout} s)`);
            if (idle.isIdle)
                root.maybeOff();
        }
    }

    // idle, but something was in the way (a video, music): look again each minute
    Timer {
        running: idle.isIdle && !root.offByUs && !root.dark
        interval: 60000
        repeat: true
        onTriggered: root.maybeOff()
    }

    // a game or a film fills the screen, or music plays: no standby then
    // (truthy, not "!== null" — a bridge with no player yet answers undefined)
    function blocked(): bool {
        return Hypr.allCovered === true || !!MprisBridge.playingNow;
    }

    function maybeOff(): void {
        if (root.dark)
            return;
        if (root.blocked()) {
            console.log(`Velvet: night — idle, but ${Hypr.allCovered ? "a fullscreen window" : "something plays"}: the screens stay on`);
            return;
        }
        root.screensOff();
    }

    function screensOff(): void {
        console.log("Velvet: night — screens to standby");
        root.offByUs = true;
        Hypr.act("dpms off", 'hl.dsp.dpms({ action = "off" })');
        lookSoon.restart();
    }

    function screensOn(): void {
        root.offByUs = false;
        Hypr.act("dpms on", 'hl.dsp.dpms({ action = "on" })');
        lookSoon.restart();
    }

    // while the screens are off by us: the first key or move wakes them
    IdleMonitor {
        id: waker

        enabled: root.offByUs
        timeout: 1
        respectInhibitors: false
        onIsIdleChanged: {
            if (!waker.isIdle && root.offByUs)
                root.screensOn();
        }
    }

    readonly property bool started: Config.loaded

    IpcHandler {
        target: "night"

        function status(): string {
            return JSON.stringify({
                status: root.status,
                screen: root.screenLine,
                working: root.working,
                doing: root.doing,
                last: root.summaryLine
            });
        }
        function start(): void {
            root.startNow();
        }
        function stop(): void {
            root.stop();
        }
        // "Velly, mach den Bildschirm aus" — the night shift follows once it is dark long enough
        function screenOff(): void {
            root.screensOff();
        }
        function screenOn(): void {
            root.screensOn();
        }
    }
}
