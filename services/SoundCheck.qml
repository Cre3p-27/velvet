//  VELVET  ·  services/SoundCheck.qml
//  Why the sound drops, and what keeps it from dropping — Settings → AUDIO →
//  SOUND PROBLEMS, `velvet sound`, Velly. bin/velvet-sound reads the facts
//  (outputs, Bluetooth dropouts in the journal, the Wi-Fi band, the codec).
//
//  RECONNECT AFTER A DROP: WirePlumber logs "Failure in Bluetooth audio
//  transport …/dev_<MAC>/…" when a device's link breaks — not when you switch
//  the device off. The device is then connected again (after 2, 8 and 25 s;
//  measured on this machine it never came back by itself), and the sound
//  follows it back (WirePlumber keeps it as the default output).
//  BLUETOOTH SOUND: BEST (aptX HD, LDAC …), STABLE (aptX/AAC/SBC — a lower
//  bitrate rides out a busy 2.4 GHz band), SAFEST (SBC) — applied whenever a
//  Bluetooth output appears. KEEP MUSIC QUALITY is WirePlumber's own setting
//  (autoswitch to the headset's call mode), read back from WirePlumber.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string helper: `${Qt.resolvedUrl("../bin/velvet-sound")}`.replace(/^file:\/\//, "")
    property var facts: ({})
    property bool known: false
    readonly property bool keepQuality: root.facts.keepQuality === true
    readonly property var findings: root.facts.findings ?? []

    // ── the short lines the settings rows show (one line each, ~40 characters)
    function upper(s: string): string {
        return String(s ?? "").toUpperCase();
    }

    readonly property var playing: (root.facts.outputs ?? []).find(o => o.default) ?? null
    readonly property string plays: {
        const o = root.playing;
        if (!root.known)
            return "…";
        if (!o)
            return "NO OUTPUT";
        const how = o.codec ? o.codec.replace("_", " ") : o.kind;
        return `${root.upper(o.description)} · ${root.upper(how)}`;
    }
    readonly property string dropLine: {
        if (!root.known)
            return "…";
        const n = root.facts.dropsTotal ?? 0;
        if (n === 0)
            return "NONE IN 24 H";
        const devices = Object.keys(root.facts.drops ?? {}).length;
        return `${n}× IN 24 H · LAST ${root.facts.lastDrop} · ${devices} DEVICE${devices === 1 ? "" : "S"}`;
    }
    readonly property string wifiLine: {
        const w = root.facts.wifi ?? {};
        if (!root.known)
            return "…";
        if (!w.band)
            return "NO WI-FI · CLEAR OF BLUETOOTH";
        if (w.band === "2.4")
            return root.facts.chip === "MediaTek" ? "2.4 GHZ · SHARES BLUETOOTH'S ANTENNA" : "2.4 GHZ · BLUETOOTH'S BAND";
        return `${w.band} GHZ · CLEAR OF BLUETOOTH`;
    }
    readonly property string verdict: {
        if (!root.known)
            return "…";
        const d = root.facts.drops ?? {};
        const devices = Object.keys(d);
        if (devices.length >= 2)
            return "THE PC'S BLUETOOTH LINK — NOT THE SPEAKERS";
        if (devices.length === 1) {
            const name = (root.facts.names ?? {})[devices[0]] ?? devices[0];
            return (root.facts.wifi?.band === "2.4") ? `${root.upper(name)} DROPS · WI-FI ON ITS BAND` : `${root.upper(name)} DROPS · CHECK DISTANCE`;
        }
        if ((root.facts.findings ?? []).some(f => f.level === "bad"))
            return root.upper(root.facts.findings.find(f => f.level === "bad").text);
        return "NOTHING DROPPED TODAY";
    }

    function refresh(): void {
        probe.running = false;
        probe.running = true;
    }

    Process {
        id: probe

        command: ["python3", root.helper]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d && typeof d === "object") {
                        root.facts = d;
                        root.known = true;
                    }
                } catch (e) {}
            }
        }
    }

    // ── actions
    property string testNote: ""

    function test(): void {
        tester.running = false;
        tester.running = true;
        Toast.show("♪ A SHORT CHIME ON THE OUTPUT THAT PLAYS NOW", "info", 2200);
    }

    Process {
        id: tester

        command: ["python3", root.helper, "test"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    Toast.show(r.ok ? `PLAYED ON ${root.upper(r.description)} — HEARD IT? THAT OUTPUT WORKS` : `COULD NOT PLAY ON ${root.upper(r.output ?? "THE OUTPUT")}`, r.ok ? "ok" : "warn", 5200);
                } catch (e) {
                    Toast.show("THE TEST SOUND DID NOT PLAY — NO OUTPUT?", "warn", 4200);
                }
            }
        }
    }

    function setKeepQuality(on: bool): void {
        keeper.command = ["python3", root.helper, "keep-quality", on ? "on" : "off"];
        keeper.running = false;
        keeper.running = true;
    }

    Process {
        id: keeper

        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    Toast.show(r.keepQuality ? "BLUETOOTH HEADSETS STAY IN MUSIC MODE" : "A HEADSET MAY SWITCH TO CALL MODE FOR ITS MICROPHONE AGAIN", r.ok ? "ok" : "warn", 3600);
                } catch (e) {}
                root.refresh();
            }
        }
    }

    // BEST | STABLE | SAFEST, on every Bluetooth output that appears
    function applyCodec(): void {
        const want = Config.services.btQuality;
        codec.command = ["python3", root.helper, "bt", want];
        codec.running = false;
        codec.running = true;
    }

    Process {
        id: codec

        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    const changed = (r.devices ?? []).filter(d => d.changed);
                    if (changed.length)
                        Toast.show(`BLUETOOTH SOUND · ${root.upper(Config.services.btQuality)} · ${changed.map(d => root.upper(d.codec.replace("_", " "))).join(", ")}`, "ok", 3200);
                } catch (e) {}
                root.refresh();
            }
        }
    }

    Connections {
        target: Config.services

        function onBtQualityChanged(): void {
            root.applyCodec();
        }
    }

    // a Bluetooth output appeared (connected, or back after a drop)
    readonly property string sinkName: Audio.sink?.name ?? ""

    onSinkNameChanged: {
        if (root.sinkName.startsWith("bluez_output") && Config.services.btQuality !== "best")
            codecLater.restart();
        refreshLater.restart();
    }

    Timer {
        id: codecLater

        interval: 1500
        onTriggered: root.applyCodec()
    }

    Timer {
        id: refreshLater

        interval: 1200
        onTriggered: root.refresh()
    }

    // ── RECONNECT AFTER A DROP
    property var retry: ({})        // mac → { name, tries, at }
    readonly property var waits: [2000, 8000, 25000]

    function dropped(line: string): void {
        const m = String(line).match(/dev_([0-9A-Fa-f]{2}(?:_[0-9A-Fa-f]{2}){5})/);
        if (!m)
            return;
        const mac = m[1].replace(/_/g, ":").toUpperCase();
        // the name from bluez, else from the last facts (bluez may not have listed it yet)
        const name = Bluetooth.byMac(mac)?.name ?? (root.facts.names ?? {})[mac] ?? mac;
        console.log(`Velvet: Bluetooth ${name} dropped (transport failure)`);
        refreshLater.restart();
        if (!Config.services.btReconnect)
            return;
        const next = Object.assign({}, root.retry);
        if (next[mac])
            return;     // already on it
        next[mac] = { name: name, tries: 0, at: Date.now() + root.waits[0] };
        root.retry = next;
        Toast.show(`${root.upper(name)} DROPPED — CONNECTING IT AGAIN`, "warn", 3000);
        retryTick.start();
    }

    Timer {
        id: retryTick

        interval: 500
        repeat: true
        onTriggered: {
            const now = Date.now();
            const next = Object.assign({}, root.retry);
            let left = 0;
            for (const mac in next) {
                const r = next[mac];
                if (r.busy) {
                    left++;
                    continue;
                }
                // back already (by itself or by hand): nothing to do
                if (r.tries > 0 && Bluetooth.byMac(mac)?.connected) {
                    delete next[mac];
                    continue;
                }
                // one connect at a time (bluez pages one device at a time anyway)
                if (now < r.at || joiner.running) {
                    left++;
                    continue;
                }
                if (r.tries >= root.waits.length) {
                    Toast.show(`${root.upper(r.name)} DID NOT COME BACK — IS IT ON AND IN REACH?`, "warn", 5200);
                    delete next[mac];
                    continue;
                }
                r.busy = true;
                r.tries++;
                root.reconnect(mac);
                left++;
            }
            root.retry = next;
            if (left === 0)
                stop();
        }
    }

    // one bluetoothctl per try: its exit code says whether it worked
    function reconnect(mac: string): void {
        joiner.mac = mac;
        joiner.command = ["bash", "-c", `out=$(timeout 15 bluetoothctl connect "${mac}" 2>&1); echo "$out" | grep -qiE "Connection successful|AlreadyConnected|already connected" && echo OK || echo NO`];
        joiner.running = true;
    }

    Process {
        id: joiner

        property string mac: ""

        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const mac = joiner.mac;
                const next = Object.assign({}, root.retry);
                const r = next[mac];
                if (!r)
                    return;
                if (text.trim() === "OK") {
                    Toast.show(`${root.upper(r.name)} IS BACK`, "ok", 2600);
                    console.log(`Velvet: Bluetooth ${r.name} reconnected after a drop (try ${r.tries})`);
                    delete next[mac];
                } else {
                    r.busy = false;
                    r.at = Date.now() + (root.waits[r.tries] ?? 0);
                }
                root.retry = next;
                Bluetooth.refreshSoon();
                root.refresh();
            }
        }
    }

    // journalctl sleeps on the journal: ~0 % CPU for the whole session
    Process {
        id: dropWatch

        command: ["journalctl", "--user", "-f", "-n", "0", "-o", "cat", "-t", "wireplumber", "-g", "Failure in Bluetooth audio transport"]
        running: false
        stdout: SplitParser {
            onRead: line => root.dropped(line)
        }
        onExited: rewatch.restart()
    }

    Timer {
        id: rewatch

        interval: 10000
        onTriggered: dropWatch.running = true
    }

    // the facts again every 15 s while the settings window is open
    Timer {
        running: Panels.settings
        interval: 15000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // at start: the facts once, the watcher for good
    Timer {
        running: Config.loaded
        interval: 4000
        onTriggered: {
            root.refresh();
            dropWatch.running = true;
        }
    }

    IpcHandler {
        target: "sound"

        function check(): string {
            return JSON.stringify({
                plays: root.plays,
                drops: root.dropLine,
                wifi: root.wifiLine,
                verdict: root.verdict,
                findings: root.findings
            });
        }
        function test(): void {
            root.test();
        }
        function dropped(mac: string): void {
            // a drop by hand (tests): what the journal line would do
            root.dropped(`Failure in Bluetooth audio transport /org/bluez/hci0/dev_${mac.replace(/:/g, "_")}/sep1/fd0`);
        }
    }
}
