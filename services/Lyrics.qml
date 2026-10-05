//  VELVET  ·  services/Lyrics.qml
//  Time-synced lyrics for whatever is playing.
//
//  Source is lrclib.net: open, free, no key, no account, and it hands back an
//  LRC file — lines stamped with the millisecond they are sung at. MPRIS gives
//  the player's position; matching the two is the whole feature.
//
//  Everything here is written to fail quietly. No network, no match, an
//  instrumental, a player with no position — all of them end in "no lyrics"
//  rather than in an error, because a lyrics panel that shouts at you is worse
//  than one that stays empty.
//
//  Including the biggest failure of all: this singleton is created at startup,
//  and Quickshell's MPRIS service is a build-time option, so importing it here
//  would mean a build without it cannot start the shell at all. The import is
//  quarantined in MprisBridge.qml and created dynamically below.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "romanise.js" as Roman

Singleton {
    id: root

    readonly property bool ready: Config.lyrics.enabled
    // Fetching and following the song: for the desktop's lyrics, or for the
    // lock's lyric line while it is locked (LOCK SCREEN → LYRICS) — the
    // lock needs no lyrics panel switched on.
    readonly property bool active: Config.lyrics.enabled || (Config.lock.lyrics && Locker.locked)

    onActiveChanged: {
        if (root.active)
            root.look();
        else
            root.clear();
    }

    // ---------------------------------------------------------------- player
    property var bridge: null
    property string bridgeError: ""

    readonly property bool hasPlayer: root.bridge?.has ?? false

    function makeBridge(): void {
        if (root.bridge !== null || root.bridgeError !== "")
            return;
        const comp = Qt.createComponent(Qt.resolvedUrl("MprisBridge.qml"), Component.PreferSynchronous);
        if (comp.status === Component.Error) {
            root.bridgeError = comp.errorString().trim();
            console.warn("Velvet: MPRIS unavailable —", root.bridgeError);
            return;
        }
        const obj = comp.createObject(root);
        if (!obj) {
            root.bridgeError = "MprisBridge.qml could not be created";
            return;
        }
        root.bridge = obj;
    }

    // A Singleton is not an Item, so there is no Component.onCompleted here —
    // a one-shot Timer is how everything in this shell does its first tick.
    Timer {
        running: true
        interval: 1
        onTriggered: root.makeBridge()
    }

    readonly property string title: root.bridge?.title ?? ""
    readonly property string artist: root.bridge?.artist ?? ""
    readonly property string album: root.bridge?.album ?? ""
    readonly property real duration: root.bridge?.length ?? 0
    readonly property bool playing: root.bridge?.playing ?? false

    readonly property string key: `${root.artist} ${root.title}`

    // ----------------------------------------------------------------- state
    //  lines: [{ t: seconds, text: "…" }] sorted by t
    property var lines: []
    property string plain: ""
    property int index: -1
    property string status: "IDLE"     // IDLE | LOOKING | SYNCED | PLAIN | NONE | OFFLINE
    property string lastKey: ""

    readonly property bool hasSynced: root.lines.length > 0
    readonly property string current: root.shown(root.index >= 0 && root.index < root.lines.length ? (root.lines[root.index]?.text ?? "") : "")
    readonly property string upcoming: root.shown(root.index + 1 < root.lines.length ? (root.lines[root.index + 1]?.text ?? "") : "")
    readonly property string previous: root.shown(root.index > 0 && root.index - 1 < root.lines.length ? (root.lines[root.index - 1]?.text ?? "") : "")

    // LYRICS → ROMANISE: kana and hangul in Latin letters (romanise.js).
    function shown(text: string): string {
        return Config.lyrics.romanise ? Roman.romanise(text) : text;
    }

    property real position: 0

    // Where we are between this line and the next, 0…1 — the panel uses it to
    // wipe the current line as it is sung.
    readonly property real lineProgress: {
        if (root.index < 0 || root.index >= root.lines.length)
            return 0;
        const a = root.lines[root.index].t;
        const b = root.index + 1 < root.lines.length ? root.lines[root.index + 1].t : a + 4;
        const span = Math.max(0.35, b - a);
        return Math.max(0, Math.min(1, (root.position - a) / span));
    }

    readonly property real progress: root.duration > 0 ? Math.max(0, Math.min(1, root.position / root.duration)) : 0

    // ------------------------------------------------------------ word timing
    // LRC stamps lines, not words. Spreading a line's words evenly across its
    // own duration is not real word timing and never claims to be — but at one
    // word on screen at a time it lands on the beat closely enough to sing to,
    // which is the whole point of showing it that way.
    readonly property var words: {
        const line = root.current.trim();
        if (!line)
            return [];
        return line.split(/\s+/).filter(w => w.length > 0);
    }

    readonly property int wordIndex: {
        const n = root.words.length;
        if (n === 0)
            return -1;
        return Math.max(0, Math.min(n - 1, Math.floor(root.lineProgress * n)));
    }

    readonly property string word: root.wordIndex >= 0 ? root.words[root.wordIndex] : ""

    // What is actually shown, whichever mode you are in.
    readonly property string display: Config.lyrics.mode === "word" ? root.word : root.current

    function fmt(seconds: real): string {
        if (!(seconds > 0))
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    // ------------------------------------------------------------------ LRC
    //  [mm:ss.xx] one line of text
    //  Several stamps can share one line, and lrclib does use that.
    function parse(lrc: string): var {
        const out = [];
        if (!lrc)
            return out;
        const rows = lrc.split(String.fromCharCode(10));
        const stamp = /\[(\d+):(\d+(?:[.:]\d+)?)\]/g;

        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            const text = row.replace(/\[[^\]]*\]/g, "").trim();
            stamp.lastIndex = 0;
            let m;
            while ((m = stamp.exec(row)) !== null) {
                const t = parseInt(m[1], 10) * 60 + parseFloat(m[2].replace(":", "."));
                if (!isFinite(t))
                    continue;
                out.push({
                    t: t,
                    text: text
                });
            }
        }
        out.sort((a, b) => a.t - b.t);
        return out;
    }

    // Which line belongs to `pos`. Linear from the last index, because the
    // position almost always moves forward by one line at a time — a binary
    // search here would be more code for less speed.
    function locate(pos: real): int {
        const l = root.lines;
        if (l.length === 0)
            return -1;
        let i = root.index;
        if (i < 0 || i >= l.length || l[i].t > pos)
            i = 0;
        while (i + 1 < l.length && l[i + 1].t <= pos)
            i++;
        return l[i].t <= pos ? i : -1;
    }

    // ------------------------------------------------------------- fetching
    function clear(): void {
        root.lines = [];
        root.plain = "";
        root.index = -1;
    }

    function look(): void {
        if (!root.active)
            return;
        if (!root.title || !root.artist) {
            root.clear();
            root.status = "IDLE";
            return;
        }
        if (root.key === root.lastKey && (root.hasSynced || root.status === "LOOKING"))
            return;

        root.lastKey = root.key;
        root.clear();
        root.status = "LOOKING";

        const q = s => encodeURIComponent(s).replace(/'/g, "%27");
        const dur = root.duration > 0 ? `&duration=${Math.round(root.duration)}` : "";
        const url = `https://lrclib.net/api/get?artist_name=${q(root.artist)}&track_name=${q(root.title)}` + (root.album ? `&album_name=${q(root.album)}` : "") + dur;
        const alt = `https://lrclib.net/api/search?artist_name=${q(root.artist)}&track_name=${q(root.title)}`;
        const ua = "velvet-shell";

        // One curl, two chances: the exact match first, then a search whose
        // first timed hit is taken. `-f` so a 404 fails rather than handing
        // back a body of JSON that says "TrackNotFound".
        fetcher.command = ["bash", "-c", `curl -fsSL --max-time 8 -A '${ua}' '${url}' || curl -fsSL --max-time 8 -A '${ua}' '${alt}'`];
        fetcher.running = false;
        fetcher.running = true;
    }

    Process {
        id: fetcher

        command: ["true"]

        stdout: StdioCollector {
            onStreamFinished: {
                let data;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    root.status = text.trim() === "" ? "OFFLINE" : "NONE";
                    return;
                }

                // /api/search answers with an array; take the first entry that
                // actually carries timed lyrics, then any entry at all.
                if (Array.isArray(data)) {
                    let pick = null;
                    for (let i = 0; i < data.length; i++)
                        if (data[i]?.syncedLyrics) {
                            pick = data[i];
                            break;
                        }
                    data = pick ?? data[0] ?? null;
                }

                if (!data || data.instrumental === true) {
                    root.status = "NONE";
                    return;
                }

                const synced = data.syncedLyrics ?? "";
                if (synced) {
                    root.lines = root.parse(synced);
                    root.index = -1;
                    root.status = root.lines.length > 0 ? "SYNCED" : "NONE";
                    return;
                }

                root.plain = data.plainLyrics ?? "";
                root.status = root.plain ? "PLAIN" : "NONE";
            }
        }
    }

    onKeyChanged: lookDebounce.restart()

    // Players rewrite the metadata a field at a time when a track changes, so
    // a fetch on every change would fire three times per song.
    Timer {
        id: lookDebounce
        interval: 700
        onTriggered: root.look()
    }


    // ------------------------------------------------------------- the clock
    // MPRIS position is a poll, not a stream. Reading it every frame would be
    // a D-Bus call every frame, so it is read a few times a second and run
    // forward locally in between.
    Timer {
        running: root.active && root.hasPlayer
        interval: 900
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.bridge)
                return;
            root.position = root.bridge.position() + Config.lyrics.offsetMs / 1000;
            root.index = root.locate(root.position);
        }
    }

    Timer {
        running: root.active && root.playing && root.hasSynced
        interval: 100
        repeat: true
        onTriggered: {
            root.position = root.position + 0.1;
            const i = root.locate(root.position);
            if (i !== root.index)
                root.index = i;
        }
    }

    // ------------------------------------------------------------------ ipc
    IpcHandler {
        target: "lyrics"

        function toggle(): void {
            Config.set("lyrics.enabled", !Config.lyrics.enabled);
        }
        function refetch(): void {
            root.lastKey = "";
            root.look();
        }
        function line(): string {
            return root.current;
        }
    }

    GlobalShortcut {
        name: "lyrics"
        description: "Show or hide the Velvet lyrics panel"
        onPressed: Config.set("lyrics.enabled", !Config.lyrics.enabled)
    }
}
