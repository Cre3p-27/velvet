//  VELVET  ·  services/Time.qml
//  The time the shell shows (SHELL → TIME). SYSTEM is the computer's own
//  clock; a ZONE shows the time somewhere else (the bar, the lock, the
//  widgets, the island — all of them); BY HAND runs from a time you set, on
//  from there. The computer's own clock is never touched: the shell only
//  shows another time.
//
//  Everything that shows a time reads it here — components/ShellClock.qml
//  stands in for Quickshell's SystemClock with the same date/hours/minutes/
//  seconds, so a clock is one word different from before.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string mode: ["zone", "manual"].indexOf(Config.time.mode) >= 0 ? Config.time.mode : "system"
    readonly property string zone: `${Config.time.zone ?? ""}`.trim()

    // The chosen zone's distance from UTC in minutes, as `date` tells it
    // (re-read every ten minutes, so summer time comes and goes on its own)
    // and whether the zone exists at all.
    property int zoneMinutes: 0
    property bool zoneKnown: false
    property string zoneAbbrev: ""

    // ms to add to the computer's clock
    readonly property real shift: {
        if (root.mode === "manual")
            return Math.round(Config.time.manualOffset) * 60000;
        if (root.mode === "zone" && root.zoneKnown) {
            const local = -new Date(sec.date.getTime()).getTimezoneOffset();
            return (root.zoneMinutes - local) * 60000;
        }
        return 0;
    }

    SystemClock {
        id: sec

        precision: SystemClock.Seconds
    }

    SystemClock {
        id: min

        precision: SystemClock.Minutes
    }

    SystemClock {
        id: hour

        precision: SystemClock.Hours
    }

    // The shown time, ticking every second / minute / hour. Zone offsets and
    // times set by hand are whole minutes, so the minute still turns on :00.
    readonly property date now: new Date(sec.date.getTime() + root.shift)
    readonly property date minute: new Date(min.date.getTime() + root.shift)
    readonly property date hourly: new Date(hour.date.getTime() + root.shift)

    readonly property bool shifted: root.shift !== 0
    // a short tag for where the time is from: "NEW YORK", "BY HAND", ""
    readonly property string tag: {
        if (root.mode === "zone" && root.zoneKnown)
            return root.zone.split("/").pop().replace(/_/g, " ").toUpperCase();
        if (root.mode === "manual" && Config.time.manualOffset !== 0)
            return "BY HAND";
        return "";
    }

    // SHELL → TIME → RIGHT NOW
    readonly property string status: {
        const shown = Qt.formatDateTime(root.minute, Config.bar.clock.format24h ? "HH:mm" : "h:mm AP");
        const mine = Qt.formatDateTime(min.date, Config.bar.clock.format24h ? "HH:mm" : "h:mm AP");
        if (root.mode === "zone") {
            if (!root.zoneKnown)
                return root.zone === "" ? "NO ZONE CHOSEN YET — PICK A CITY BELOW · THE SHELL SHOWS YOUR COMPUTER'S TIME" : `NO TIME ZONE CALLED ${root.zone.toUpperCase()} · THE SHELL SHOWS YOUR COMPUTER'S TIME`;
            const h = root.zoneMinutes / 60;
            const utc = `UTC${h >= 0 ? "+" : "−"}${Math.abs(h) % 1 === 0 ? Math.abs(h) : Math.abs(h).toFixed(1)}`;
            return `SHOWS ${shown} · ${root.tag} (${root.zoneAbbrev || utc}, ${utc}) · YOUR COMPUTER: ${mine}`;
        }
        if (root.mode === "manual") {
            const d = Math.round(Config.time.manualOffset);
            if (d === 0)
                return `SHOWS ${shown} · SET A TIME BELOW, OR NUDGE IT`;
            const ahead = d > 0 ? "AHEAD" : "BEHIND";
            const a = Math.abs(d);
            const span = a >= 60 ? `${Math.floor(a / 60)} H ${a % 60} MIN` : `${a} MIN`;
            return `SHOWS ${shown} · ${span} ${ahead} OF YOUR COMPUTER (${mine})`;
        }
        return `SHOWS ${shown} · YOUR COMPUTER'S OWN TIME`;
    }

    // SET THE TIME (a text row): whatever is typed there is read as a time
    // once, and the row empties again.
    readonly property string typed: `${Config.time.setTo ?? ""}`.trim()
    onTypedChanged: {
        if (root.typed === "")
            return;
        if (!root.setByHand(root.typed))
            Toast.show(`"${root.typed.toUpperCase()}" IS NOT A TIME — TRY 7:45 OR 19:45`, "warn", 3600);
        else {
            Sfx.select();
            Toast.ok(`THE SHELL NOW SHOWS ${Qt.formatDateTime(root.minute, Config.bar.clock.format24h ? "HH:mm" : "h:mm AP")}`);
        }
        Config.set("time.setTo", "");
    }

    // the same in three letters, for a narrow bar: the zone's own short
    // name (JST, EST, CET) when it has one, else the city; SET by hand
    readonly property string shortTag: {
        if (root.tag === "")
            return "";
        if (root.mode === "manual")
            return "SET";
        if (/^[A-Z]{2,5}$/.test(root.zoneAbbrev))
            return root.zoneAbbrev;
        return root.tag.slice(0, 3);
    }

    // BY HAND: "7:45", "07:45", "19.45", "7:45 pm" → the shift (in whole
    // minutes, the nearest way round the clock) that makes the shown time
    // that. Returns false for something that is not a time.
    function setByHand(text: string): bool {
        const m = `${text ?? ""}`.trim().toLowerCase().match(/^(\d{1,2})(?:[:.h ](\d{2}))?\s*(am|pm)?$/);
        if (!m)
            return false;
        let h = parseInt(m[1]);
        const mi = m[2] !== undefined ? parseInt(m[2]) : 0;
        if (m[3] === "pm" && h < 12)
            h += 12;
        if (m[3] === "am" && h === 12)
            h = 0;
        if (h > 23 || mi > 59)
            return false;
        const real = new Date();
        const want = h * 60 + mi;
        const have = real.getHours() * 60 + real.getMinutes();
        let d = want - have;
        if (d > 720)
            d -= 1440;
        if (d < -720)
            d += 1440;
        Config.setMany({
            "time.mode": "manual",
            "time.manualOffset": d
        });
        return true;
    }

    // a zone typed by hand ("Europe/London", "tokyo", "new york")
    function setZone(text: string): void {
        const t = `${text ?? ""}`.trim();
        if (t === "")
            return;
        Config.setMany({
            "time.mode": "zone",
            "time.zone": t
        });
    }

    function backToSystem(): void {
        Config.setMany({
            "time.mode": "system",
            "time.manualOffset": 0
        });
    }

    // Reads the zone's offset with `date` (it knows every zone and its summer
    // time). A name typed loosely ("new york", "tokyo") is found in the zone
    // list first; what comes back is the zone's real name.
    function readZone(): void {
        if (root.zone === "") {
            root.zoneKnown = false;
            return;
        }
        probe.command = ["bash", "-c", `
            want="$1"
            Z=/usr/share/zoneinfo
            if [ -f "$Z/$want" ]; then name="$want"
            else
              key=$(printf '%s' "$want" | tr '[:upper:] ' '[:lower:]_')
              name=$(cd "$Z" && find . -type f ! -path './posix/*' ! -path './right/*' 2>/dev/null | sed 's|^\\./||' | awk -v k="$key" 'BEGIN{IGNORECASE=1} { n=tolower($0); split(n, p, "/"); if (p[length(p)] == k || n == k) { print $0; exit } }')
            fi
            [ -n "$name" ] && [ -f "$Z/$name" ] || { echo "none"; exit 0; }
            echo "$name"
            TZ="$name" date +%z
            TZ="$name" date +%Z
        `, "velvet-time", root.zone];
        probe.running = false;
        probe.running = true;
    }

    Process {
        id: probe

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                if (lines[0] === "none" || lines.length < 2) {
                    root.zoneKnown = false;
                    if (root.mode === "zone")
                        Toast.show(`NO TIME ZONE CALLED ${root.zone.toUpperCase()} — TRY A CITY LIKE EUROPE/LONDON`, "warn", 4200);
                    return;
                }
                const z = lines[1].trim();
                const sign = z.startsWith("-") ? -1 : 1;
                const hh = parseInt(z.slice(1, 3)) || 0;
                const mm = parseInt(z.slice(3, 5)) || 0;
                root.zoneMinutes = sign * (hh * 60 + mm);
                root.zoneAbbrev = (lines[2] ?? "").trim();
                root.zoneKnown = true;
                // the real name for a loosely typed one
                if (lines[0] !== root.zone && root.mode === "zone")
                    Config.set("time.zone", lines[0]);
            }
        }
    }

    onZoneChanged: root.readZone()
    onModeChanged: root.readZone()

    // the first read, once the config is in
    Timer {
        running: true
        interval: 400
        onTriggered: root.readZone()
    }

    Timer {
        running: root.mode === "zone"
        interval: 600000
        repeat: true
        onTriggered: root.readZone()
    }
}
