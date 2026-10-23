//  VELVET  ·  services/LiveWalls.qml
//  Live wallpapers — Velly's standing job. For every wallpaper you star she
//  reads the picture (its colours, its light, its stars) and makes it move:
//  leaves that fall, stars that twinkle, mist that drifts — a seamless loop
//  and a GIF (bin/velvet-livewall, one at a time, nice 19, never while a game
//  runs). The wallpaper plays it over the untouched still
//  (modules/wallpaper/Wallpaper.qml, assets/shaders/livewall.frag).
//
//  The index of what was made is ~/.local/share/velvet/livewalls/index.json
//  (the workshop writes it; this service only reads it). WALLPAPER → LIVE
//  WALLPAPERS holds every switch; `velvet livewall` and Velly reach the same.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string tool: `${Qt.resolvedUrl("../bin/velvet-livewall")}`.replace(/^file:\/\//, "")
    readonly property string dataDir: `${Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")}/velvet/livewalls`
    readonly property string indexPath: `${root.dataDir}/index.json`

    property var walls: ({})           // source path → what was made (meta)
    property bool ready: false

    // ── what plays
    function entry(path: string): var {
        const e = root.walls[path];
        return e && e.packed === true && e.version === 2 && e.video ? e : null;
    }

    // the moving layer for a wallpaper, "" when it has none (or live wallpapers are off)
    // a wallpaper you keep a still (THIS WALLPAPER MOVES off)
    function still(path: string): bool {
        return (Config.wallpaper.liveStills ?? []).indexOf(path) >= 0;
    }

    function videoFor(path: string): string {
        if (!Config.wallpaper.liveOn || !path || root.still(path))
            return "";
        const e = root.entry(path);
        return e ? `file://${e.video}` : "";
    }

    readonly property var current: root.entry(Config.wallpaper.current)
    readonly property int count: Object.keys(root.walls).filter(p => root.entry(p) !== null).length

    // ── the queue: one job at a time
    property var queue: []             // [{ path, style, why }]
    property var job: null             // { path, label, done, total, paused }
    property string lastError: ""
    property bool stopped: false       // STOP was pressed: no automatic jobs until asked again

    function name(path: string): string {
        return String(path).split("/").pop().replace(/\.[^.]+$/, "");
    }

    function queued(path: string): bool {
        return (root.job && root.job.path === path) || root.queue.some(q => q.path === path);
    }

    // `style` "" = the setting (STYLE), `force` = make again even when it is fresh
    // `prompt` in your own words (or "" for the settings alone), `variant` another take (new places)
    function enqueue(path: string, style: string, force: bool, front: bool, prompt: string, variant: int): void {
        if (!path || (root.queued(path) && !force))
            return;
        const item = { path: path, style: style || Config.wallpaper.liveStyle, force: force, prompt: prompt ?? "", variant: variant ?? 0 };
        const rest = root.queue.filter(q => q.path !== path);
        root.queue = front ? [item].concat(rest) : rest.concat([item]);
        root.stopped = false;
        kick.restart();
    }

    // the next take of a wallpaper: one more than the last, so a remake is never the same again
    function nextVariant(path: string): int {
        const e = root.entry(path);
        return e ? (e.variant ?? 0) + 1 : 0;
    }

    function makeThis(force: bool): void {
        if (!Config.wallpaper.current)
            return;
        const p = Config.wallpaper.current;
        root.unstill(p);
        root.enqueue(p, "", force, true, Config.wallpaper.livePrompt, force ? root.nextVariant(p) : 0);
        Toast.show(force ? "VELLY MAKES THIS WALLPAPER LIVE AGAIN" : "VELLY MAKES THIS WALLPAPER LIVE", "info", 2600);
    }

    // the favourites still without a live version (or with one of an older kind) — not a starred picture
    // whose file is gone (it would fail again every half hour)
    property var gone: ({})

    function missing(): var {
        return Wallpapers.favourites.filter(p => !root.entry(p) && !root.gone[p] && !root.still(p));
    }

    // MAKE IT LIKE THIS: the wallpaper that is up, with the description as it stands
    function makeWithPrompt(): void {
        const p = Config.wallpaper.current;
        if (!p)
            return;
        root.unstill(p);
        root.enqueue(p, "", true, true, Config.wallpaper.livePrompt, root.nextVariant(p));
        const said = root.previewSaid.length ? root.previewSaid.join(" · ") : "AS VELLY READS THE PICTURE";
        Toast.show(`VELLY MAKES IT · ${said}`, "info", 3400);
    }

    // THIS WALLPAPER MOVES: off keeps it a still (and Velly leaves it alone); on makes it live if it is not
    readonly property bool thisMoves: !!Config.wallpaper.current && !root.still(Config.wallpaper.current)

    function setThisMoves(on: bool): void {
        const p = Config.wallpaper.current;
        if (!p)
            return;
        const list = (Config.wallpaper.liveStills ?? []).filter(x => x !== p);
        if (!on)
            list.push(p);
        Config.wallpaper.liveStills = list;
        if (on && !root.entry(p))
            root.enqueue(p, "", false, true, Config.wallpaper.livePrompt, 0);
        Toast.show(on ? "THIS WALLPAPER MOVES AGAIN" : "THIS WALLPAPER STAYS A STILL · VELLY LEAVES IT ALONE", "info", 2800);
    }

    function unstill(path: string): void {
        if (root.still(path))
            Config.wallpaper.liveStills = (Config.wallpaper.liveStills ?? []).filter(x => x !== path);
    }

    // BACK TO THE LAST VERSION (again: forward)
    readonly property bool hasPrevious: root.current?.previous === true

    function undo(): void {
        const p = Config.wallpaper.current;
        if (!p || worker.running || restorer.running)
            return;
        if (!root.hasPrevious) {
            Toast.show("THERE IS NO EARLIER VERSION OF THIS ONE YET", "warn", 2800);
            return;
        }
        const args = ["python3", root.tool, "restore", p];
        if (Config.wallpaper.liveGif && Config.wallpaper.liveGifPictures)
            args.push("--gif-dir", root.gifDir);
        restorer.command = args;
        restorer.running = true;
    }

    Process {
        id: restorer

        command: ["true"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const ev = JSON.parse(line);
                    if (ev.event === "done")
                        Toast.show(`BACK TO THE VERSION BEFORE · ${String(ev.label).toUpperCase()}`, "ok", 3200);
                    else if (ev.event === "error")
                        Toast.show(String(ev.error).toUpperCase(), "warn", 3200);
                } catch (e) {}
            }
        }
        onExited: indexFile.reload()
    }

    // ── what Velly reads in a description, while you type it (bin/velvet-livewall understand)
    property var previewSaid: []
    property string previewText: ""
    readonly property string previewLine: root.previewText.trim() === "" ? "EMPTY · VELLY READS THE PICTURE AND CHOOSES"
        : (root.previewSaid.length ? `VELLY READS: ${root.previewSaid.join(" · ")}` : "VELLY FINDS NOTHING SHE KNOWS IN IT YET — TRY: LEAVES, SNOW, STARS, MIST, GOLD, SLOW, MANY …")

    // the same, short, for the settings row (its value has one line)
    readonly property string previewShort: root.previewText.trim() === "" ? "EMPTY · VELLY CHOOSES"
        : (root.previewSaid.length ? root.previewSaid.join(" · ") : "NOTHING SHE KNOWS YET")

    function preview(text: string): void {
        root.previewText = text;
        previewSoon.restart();
    }

    Timer {
        id: previewSoon

        interval: 220
        onTriggered: {
            reader.command = ["python3", root.tool, "understand", root.previewText];
            reader.running = false;
            reader.running = true;
        }
    }

    Process {
        id: reader

        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.previewSaid = JSON.parse(text).said ?? [];
                } catch (e) {
                    root.previewSaid = [];
                }
            }
        }
    }

    // the saved description, read once at start and whenever it changes (the settings row shows it)
    Connections {
        target: Config.wallpaper

        function onLivePromptChanged(): void {
            root.preview(Config.wallpaper.livePrompt);
        }
    }

    function makeFavourites(force: bool): void {
        const list = force ? Wallpapers.favourites.slice() : root.missing();
        for (let i = 0; i < list.length; i++)
            root.enqueue(list[i], "", force, false);
        if (list.length === 0)
            Toast.show(`ALL ${Wallpapers.favourites.length} FAVOURITES ARE LIVE ALREADY`, "ok", 2600);
        else
            Toast.show(`VELLY MAKES ${list.length} LIVE WALLPAPER${list.length === 1 ? "" : "S"} · ONE AFTER ANOTHER`, "info", 3200);
    }

    function stop(): void {
        root.queue = [];
        root.stopped = true;
        if (worker.running)
            worker.signal(15);
    }

    function removeAll(): void {
        root.stop();
        remover.command = ["python3", root.tool, "remove", "all"];
        remover.running = true;
    }

    // the automatic part: Velly's standing job for the favourites
    function sweep(): void {
        indexFile.reload();
        if (!Config.wallpaper.liveAuto || root.stopped || !Config.loaded)
            return;
        const list = root.missing();
        for (let i = 0; i < list.length; i++)
            root.enqueue(list[i], "", false, false);
    }

    Timer {
        id: kick

        interval: 400
        onTriggered: root.next()
    }

    function next(): void {
        if (worker.running || root.queue.length === 0)
            return;
        // something fullscreen has the machine (a game, a film): wait — the workshop would stop at once anyway.
        // Velvet's own settings window goes fullscreen too, and that is no reason to wait.
        if (root.busyScreen) {
            waitGame.restart();
            return;
        }
        const item = root.queue[0];
        root.queue = root.queue.slice(1);
        const args = ["nice", "-n", "19", "python3", root.tool, "make", item.path,
            "--style", item.style,
            "--intensity", String(Config.wallpaper.liveIntensity),
            "--amount", String(Config.wallpaper.liveAmount),
            "--speed", String(Config.wallpaper.liveSpeed),
            "--seconds", String(Config.wallpaper.liveSeconds),
            "--fps", String(Config.wallpaper.liveFps),
            "--gif-width", String(Config.wallpaper.liveGifWidth),
            "--colour", Config.wallpaper.liveColour,
            "--scale", String(Config.wallpaper.liveScale),
            "--wind", Config.wallpaper.liveWind,
            "--variant", String(item.variant ?? 0)];
        if ((item.prompt ?? "").trim() !== "")
            args.push("--prompt", item.prompt);
        if (!Config.wallpaper.liveGif)
            args.push("--no-gif");
        else if (Config.wallpaper.liveGifPictures)
            args.push("--gif-dir", root.gifDir);
        root.job = { path: item.path, label: "", done: 0, total: 0, paused: false, prompt: item.prompt ?? "" };
        worker.command = args;
        worker.running = true;
    }

    readonly property bool busyScreen: Hypr.allCovered && !Panels.settings

    // ~/Pictures/Velvet Live (the XDG pictures folder, in the language it has — ~/Bilder here; xdg-user-dir
    // answers the home folder itself when none is set, and then it is ~/Pictures)
    property string picturesDir: `${Quickshell.env("HOME")}/Pictures`
    readonly property string gifDir: `${root.picturesDir}/Velvet Live`

    Process {
        running: true
        command: ["bash", "-c", "d=$(xdg-user-dir PICTURES 2>/dev/null); [ -n \"$d\" ] && [ \"$d\" != \"$HOME\" ] && echo \"$d\" || echo \"$HOME/Pictures\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = text.trim();
                if (d)
                    root.picturesDir = d;
            }
        }
    }

    Timer {
        id: waitGame

        interval: 20000
        onTriggered: root.next()
    }

    Process {
        id: worker

        command: ["true"]
        stdout: SplitParser {
            onRead: line => root.heard(line)
        }
        onExited: (code, status) => {
            const was = root.job;
            root.job = null;
            // the workshop wrote the index (a file that did not exist yet is not watched)
            indexFile.reload();
            if (code === 75 && was) {
                // a game took the screen: the same picture again once it is over
                root.queue = [{ path: was.path, style: "", force: true }].concat(root.queue);
                waitGame.restart();
                return;
            }
            if (!root.stopped)
                kick.restart();
            // the last of a run: Velly says so once (a notification, so it waits for you)
            if (root.queue.length === 0 && root.madeInRow >= 2) {
                announce.command = ["notify-send", "-a", "Velly", "-i", "image-x-generic", "Velly",
                    `${root.madeInRow} wallpapers move now · leaves, stars, mist — whatever suits each one. The GIFs are in Pictures → Velvet Live.`];
                announce.running = true;
                root.madeInRow = 0;
            } else if (root.queue.length === 0) {
                root.madeInRow = 0;
            }
        }
    }

    property int madeInRow: 0

    Process {
        id: announce

        command: ["true"]
    }

    function heard(line: string): void {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        const j = Object.assign({}, root.job ?? {});
        switch (ev.event) {
        case "start":
            j.label = ev.label;
            j.why = ev.why;
            j.total = ev.frames;
            j.done = 0;
            j.paused = false;
            break;
        case "progress":
            j.done = ev.done;
            j.total = ev.total;
            j.paused = false;
            break;
        case "paused":
            j.paused = true;
            break;
        case "done":
            root.lastError = "";
            root.madeInRow++;
            if (ev.source === Config.wallpaper.current)
                Toast.show(`VELLY MADE THIS WALLPAPER LIVE · ${String(ev.label).toUpperCase()}`, "ok", 4200);
            console.log(`Velvet: live wallpaper made for ${root.name(ev.source)} — ${ev.label} (${ev.took} s)`);
            break;
        case "error":
            if (String(ev.error).indexOf("not there") >= 0 && ev.source) {
                const g = Object.assign({}, root.gone);
                g[ev.source] = true;
                root.gone = g;
            }
            root.lastError = `${root.name(ev.source ?? "")}: ${ev.error}`;
            console.log(`Velvet: live wallpaper failed — ${root.lastError}`);
            if (ev.source === Config.wallpaper.current)
                Toast.show(`NO LIVE WALLPAPER · ${String(ev.error).toUpperCase()}`, "warn", 5200);
            break;
        }
        root.job = j;
    }

    // ── a line for the settings and for Velly
    readonly property string status: {
        if (!Config.wallpaper.liveOn && !root.job)
            return "OFF";
        const j = root.job;
        if (j) {
            const left = root.queue.length;
            const pct = j.total > 0 ? Math.round(100 * j.done / j.total) : 0;
            return `${j.paused ? "PAUSED · SOMETHING RUNS FULLSCREEN · " : ""}MAKING ${root.name(j.path).toUpperCase()} · ${pct} %${left > 0 ? ` · ${left} MORE` : ""}`;
        }
        if (root.queue.length > 0)
            return root.busyScreen ? `${root.queue.length} WAITING · SOMETHING RUNS FULLSCREEN` : `${root.queue.length} WAITING`;
        const there = Wallpapers.favourites.filter(p => !root.gone[p]);
        const live = there.filter(p => root.entry(p) !== null).length;
        const lost = Wallpapers.favourites.length - there.length;
        const err = root.lastError && lost === 0 ? ` · LAST ERROR: ${root.lastError.toUpperCase()}` : "";
        return `${root.count} LIVE · ${live} OF ${there.length} FAVOURITES${lost ? ` · ${lost} STARRED PICTURE${lost === 1 ? " IS" : "S ARE"} GONE FROM THE DISK` : ""}${err}`;
    }

    readonly property string thisLine: {
        const e = root.current;
        if (root.job && root.job.path === Config.wallpaper.current)
            return "BEING MADE RIGHT NOW";
        if (root.still(Config.wallpaper.current))
            return e ? "KEPT A STILL · ITS MOTION IS STILL THERE" : "KEPT A STILL";
        if (!e)
            return Wallpapers.isFavourite(Config.wallpaper.current) ? "NOT MADE YET · IT IS IN VELLY'S QUEUE" : "STILL · STAR IT, OR MAKE IT LIVE BELOW";
        const how = (e.prompt ?? "").trim() !== "" ? "AS YOU DESCRIBED IT" : (e.why ?? "");
        return `${String(e.label).toUpperCase()} · ${String(how).toUpperCase()}${(e.variant ?? 0) > 0 ? ` · TAKE ${(e.variant ?? 0) + 1}` : ""}`;
    }

    // ── the index the workshop writes
    FileView {
        id: indexFile

        path: root.indexPath
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.walls = d && d.walls ? d.walls : ({});
            } catch (e) {
                root.walls = ({});
            }
            root.ready = true;
        }
        onLoadFailed: {
            root.walls = ({});
            root.ready = true;
        }
    }

    Process {
        id: remover

        command: ["true"]
        onExited: {
            indexFile.reload();
            Toast.show("EVERY LIVE WALLPAPER IS DELETED · THE STILLS STAY", "ok", 3200);
        }
    }

    // a star given (or the switch turned on): Velly looks again, a moment later
    // A star given: Velly looks again a few seconds later. The favourites ARRIVING at start are no star —
    // the first look waits the 90 s after login (it started after 5 s and competed with the login).
    property bool settled: false

    Connections {
        target: Wallpapers

        function onFavouritesChanged(): void {
            root.gone = ({});
            if (root.settled)
                sweepSoon.restart();
        }
    }

    Connections {
        target: Config.wallpaper

        function onLiveAutoChanged(): void {
            if (Config.wallpaper.liveAuto) {
                root.stopped = false;
                sweepSoon.restart();
            }
        }
    }

    Timer {
        id: sweepSoon

        interval: 5000
        onTriggered: root.sweep()
    }

    // after the login has settled, and every half hour (a picture changed, a job that failed)
    Timer {
        running: Config.loaded && root.ready
        interval: 90000
        onTriggered: {
            root.settled = true;
            root.sweep();
        }
    }

    Timer {
        running: Config.loaded && root.ready
        interval: 1800000
        repeat: true
        onTriggered: root.sweep()
    }

    IpcHandler {
        target: "livewall"

        function status(): string {
            return JSON.stringify({
                status: root.status,
                current: root.current ? { label: root.current.label, why: root.current.why, style: root.current.style } : null,
                making: root.job ? root.name(root.job.path) : "",
                queue: root.queue.map(q => root.name(q.path)),
                live: root.count,
                favourites: Wallpapers.favourites.length,
                on: Config.wallpaper.liveOn,
                auto: Config.wallpaper.liveAuto
            });
        }
        // path: "" or "current" for the wallpaper that is up; style: "" or "auto" for Velly's choice
        function make(path: string, style: string): string {
            const p = (!path || path === "current") ? Config.wallpaper.current : path;
            root.unstill(p);
            root.enqueue(p, style && style !== "auto" ? style : "auto", true, true, "", root.nextVariant(p));
            return `queued ${root.name(p)}`;
        }
        // in your own words ("langsamer goldener Schnee, viel, kein Nebel"); it is kept as THE description too
        function describe(path: string, prompt: string): string {
            const p = (!path || path === "current") ? Config.wallpaper.current : path;
            root.unstill(p);
            root.enqueue(p, "", true, true, prompt, root.nextVariant(p));
            return `queued ${root.name(p)} as described`;
        }
        function undo(): void {
            root.undo();
        }
        // "on" | "off": the wallpaper that is up moves, or stays a still
        function moves(on: string): void {
            root.setThisMoves(on !== "off" && on !== "false");
        }
        function favourites(): string {
            root.makeFavourites(false);
            return `${root.queue.length} queued`;
        }
        function stop(): void {
            root.stop();
        }
        function reload(): void {
            indexFile.reload();
        }
    }
}
