//  VELVET  ·  services/Monitors.qml
//  Every screen at its best, from the first moment: its own (native)
//  resolution, the fastest refresh at it, a scale that suits its size
//  (bin/velvet-monitors reads all that from the screen itself). Set live at
//  start, when a screen is plugged in, and again after every Hyprland config
//  reload (the reload puts the hand-written monitor lines back), and written
//  into velvet.lua (HyprConf) so the next login starts right.
//  DISPLAY → AUTO SCREEN SETUP turns it off; RESOLUTION and SCALE override it.
//
//  The fastest mode a screen lists is not always one its port and cable can
//  carry (4K at 240 Hz over HDMI: refused every time on the processor's
//  graphics, every few plug-ins on the graphics card — the screen then shows
//  "no signal" and drops the cable). `velvet-monitors --watch` reads Hyprland's
//  log and says so the moment it happens; the mode is then remembered for that
//  port and that screen (~/.config/velvet/screens.json) and the screen steps
//  down to the fastest mode below it at once. DISPLAY → TRY THE FAST MODES
//  AGAIN (or `velvet display forget`) forgets it.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property bool manage: Config.display.manage
    property var screens: []            // what velvet-monitors said
    property string status: "…"
    readonly property string script: `${Qt.resolvedUrl("../bin/velvet-monitors")}`.replace(/^file:\/\//, "")

    // What failed where: { "<output>|<description>": { bad: [mode…], fails: { mode: { count, last, why } } } }
    property var book: ({})
    readonly property string bookPath: `${Quickshell.env("HOME")}/.config/velvet/screens.json`
    // the last screen seen on each output WITH its EDID — a failure is often
    // reported while the screen is away (it dropped the cable)
    property var known: ({})

    function keyOf(s: var): string {
        return `${s.name}|${s.description}`;
    }

    function badOf(s: var): var {
        const e = s ? root.book[root.keyOf(s)] : null;
        return e && Array.isArray(e.bad) ? e.bad : [];
    }

    // A failed mode is a ceiling: nothing at that resolution as fast as it or
    // faster (240.02 failed → 239.76 would fail the same way).
    function allowed(s: var, mode: string): bool {
        const p = root.parse(mode);
        if (!p)
            return false;
        const bad = root.badOf(s);
        for (let i = 0; i < bad.length; i++) {
            const b = root.parse(bad[i]);
            if (b && b.w === p.w && b.h === p.h && p.rr >= b.rr - 0.5)
                return false;
        }
        return true;
    }

    // The screen's own resolution at the fastest refresh that works on this port.
    function bestOf(s: var): string {
        if (root.allowed(s, s.best.mode))
            return s.best.mode;
        let pick = null;
        for (let i = 0; i < (s.modes ?? []).length; i++) {
            const p = root.parse(s.modes[i]);
            if (p && p.w === s.best.w && p.h === s.best.h && root.allowed(s, s.modes[i]) && (!pick || p.rr > pick.rr))
                pick = Object.assign({ mode: s.modes[i] }, p);
        }
        return pick ? pick.mode : root.safeOf(s);
    }

    // SAFE: the screen's own resolution at 60 Hz (or the nearest below) —
    // every port and every cable carries that.
    function safeOf(s: var): string {
        let pick = null;
        for (let i = 0; i < (s.modes ?? []).length; i++) {
            const p = root.parse(s.modes[i]);
            if (p && p.w === s.best.w && p.h === s.best.h && p.rr <= 60.5 && (!pick || p.rr > pick.rr))
                pick = Object.assign({ mode: s.modes[i] }, p);
        }
        return pick ? pick.mode : s.best.mode;
    }

    // What a screen should run: AUTO (the screen's own best that works here),
    // SAFE, or what the menu says — a resolution only where that screen offers it.
    function target(s: var): var {
        const want = Config.display.mode;
        let mode;
        if (want === "safe")
            mode = root.safeOf(s);
        else if (want !== "auto" && (s.modes ?? []).indexOf(want) >= 0 && root.allowed(s, want))
            mode = want;
        else
            mode = root.bestOf(s);
        const scaleWant = Number(Config.display.scale);
        const scale = Config.display.scale !== "auto" && scaleWant >= 0.5 && scaleWant <= 4 ? scaleWant : s.best.scale;
        return {
            mode: mode,
            scale: scale
        };
    }

    function parse(mode: string): var {
        const m = String(mode).match(/^(\d+)x(\d+)@([\d.]+)/);
        return m ? {
            w: +m[1],
            h: +m[2],
            rr: +m[3]
        } : null;
    }

    function hz(mode: string): string {
        const p = root.parse(mode);
        return p ? `${Math.round(p.rr)} HZ` : mode;
    }

    function luaStr(s: string): string {
        return `"${String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
    }

    // A screen Velvet leaves alone: switched off, or one that did not say what
    // it is (no EDID — Hyprland shows 1024×768 until the screen answers).
    function skip(s: var): bool {
        return s.disabled || s.edid === false;
    }

    // The rules for velvet.lua / velvet.conf (HyprConf writes them last, so
    // they win over the monitor lines of hyprland.lua at the next login).
    readonly property string luaRules: {
        if (!root.manage)
            return "";
        let out = "";
        for (let i = 0; i < root.screens.length; i++) {
            const s = root.screens[i];
            if (root.skip(s))
                continue;
            const t = root.target(s);
            out += `hl.monitor({ output = ${root.luaStr(s.name)}, mode = ${root.luaStr(t.mode)}, position = "${s.current.x}x${s.current.y}", scale = "${t.scale}" })\n`;
        }
        return out;
    }
    readonly property string confRules: {
        if (!root.manage)
            return "";
        let out = "";
        for (let i = 0; i < root.screens.length; i++) {
            const s = root.screens[i];
            if (root.skip(s))
                continue;
            const t = root.target(s);
            out += `monitor = ${s.name}, ${t.mode}, ${s.current.x}x${s.current.y}, ${t.scale}\n`;
        }
        return out;
    }

    // The choices the menu offers for RESOLUTION: the first screen's modes
    // (Config.monitorModes, so Schema needs no service).
    function publish(): void {
        const s = root.screens.find(x => !root.skip(x)) ?? null;
        const out = [];
        if (s) {
            const auto = root.parse(root.bestOf(s));
            const capped = root.bestOf(s) !== s.best.mode;
            out.push({
                value: "auto",
                label: `AUTO · ${auto.w}×${auto.h} @ ${Math.round(auto.rr)} HZ${capped ? ` · ${root.hz(s.best.mode)} FAILED ON ${s.name}` : ""}`
            });
            out.push({
                value: "safe",
                label: `SAFE · ${root.safeOf(s).replace("x", "×").replace(/@([\d.]+)$/, (m, r) => ` @ ${Math.round(+r)} HZ`)} · ANY CABLE`
            });
            for (let i = 0; i < s.modes.length; i++) {
                const p = root.parse(s.modes[i]);
                if (!p)
                    continue;
                const ok = root.allowed(s, s.modes[i]);
                out.push({
                    value: s.modes[i],
                    label: `${p.w}×${p.h} @ ${Math.round(p.rr * 100) / 100} HZ${s.modes[i] === s.best.mode ? " · THE SCREEN'S OWN" : ""}${ok ? "" : " · FAILED HERE"}`
                });
            }
        } else {
            out.push({ value: "auto", label: "AUTO" }, { value: "safe", label: "SAFE · 60 HZ" });
        }
        Config.monitorModes = out;
        root.status = root.describe();
    }

    function describe(): string {
        const shown = root.screens.filter(x => !x.disabled);
        if (shown.length === 0)
            return "NO SCREEN FOUND";
        const parts = [];
        for (let i = 0; i < shown.length; i++) {
            const s = shown[i];
            if (s.edid === false) {
                parts.push(`${s.name} · THE SCREEN DID NOT SAY WHAT IT IS (NO EDID) — CHECK THE CABLE`);
                continue;
            }
            const bad = root.badOf(s);
            parts.push(`${s.name} · ${s.current.w}×${s.current.h} @ ${Math.round(s.current.rr)} HZ · SCALE ${s.current.scale}${bad.length ? ` · ${bad.map(m => root.hz(m)).join(", ")} FAILED HERE` : ` — BEST ${s.best.w}×${s.best.h} @ ${Math.round(s.best.rr)} HZ`}`);
        }
        return parts.join("   ·   ");
    }

    // Puts a screen on its target when it is not there already. Twice per
    // screen per ten seconds at most: a mode that does not take must never
    // turn into a loop of mode changes (`force`: an asked-for change).
    property var lastApply: ({})
    // what was last sent per screen and when: the same change twice in a row
    // (a menu change and the call that made it) would be two mode changes —
    // two black flashes on a real screen
    property var sent: ({})

    // Lua first, the classic request when Lua is not understood — not decided
    // by HyprConf.lua: right after the start its probe has not answered yet and
    // the first change went out as `keyword`, which Hyprland 0.55+ refuses.
    function ruleFor(name: string, mode: string, x: int, y: int, scale: real): string {
        const lua = `hl.monitor({ output = ${root.luaStr(name)}, mode = ${root.luaStr(mode)}, position = "${x}x${y}", scale = "${scale}" })`.replace(/'/g, "");
        return `out=$(hyprctl eval '${lua}' 2>&1); [ "$out" = "ok" ] || hyprctl keyword monitor '${name},${mode},${x}x${y},${scale}'`;
    }

    function settle(force: bool): void {
        if (!root.manage || !Config.loaded)
            return;
        const cmds = [];
        const now = Date.now();
        const stamps = Object.assign({}, root.lastApply);
        for (let i = 0; i < root.screens.length; i++) {
            const s = root.screens[i];
            if (root.skip(s))
                continue;
            const t = root.target(s);
            const p = root.parse(t.mode);
            if (!p)
                continue;
            const c = s.current;
            const same = c.w === p.w && c.h === p.h && Math.abs(c.rr - p.rr) < 0.5 && Math.abs(c.scale - t.scale) < 0.01;
            if (same)
                continue;
            const seen = (stamps[s.name] ?? []).filter(at => now - at < 10000);
            if (seen.length >= 2 && !force)
                continue;
            const last = root.sent[s.name];
            if (last && last.mode === t.mode && Math.abs(last.scale - t.scale) < 0.01 && now - last.at < 1000)
                continue;
            stamps[s.name] = seen.concat([now]);
            root.note(s.name, t.mode, t.scale);
            cmds.push(root.ruleFor(s.name, t.mode, c.x, c.y, t.scale));
            console.log(`Velvet: screen ${s.name} ${c.w}x${c.h}@${c.rr} ×${c.scale} → ${t.mode} ×${t.scale}`);
        }
        root.lastApply = stamps;
        root.run(cmds);
    }

    function note(name: string, mode: string, scale: real): void {
        const next = Object.assign({}, root.sent);
        next[name] = { mode: mode, scale: scale, at: Date.now() };
        root.sent = next;
    }

    function run(cmds: var): void {
        if (cmds.length === 0)
            return;
        apply.command = ["bash", "-c", cmds.join("; ")];
        apply.running = false;
        apply.running = true;
        // read back what the screens really run now
        again.restart();
    }

    Process {
        id: apply

        command: ["true"]
    }

    Process {
        id: probe

        command: ["python3", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (Array.isArray(d))
                        root.screens = d;
                } catch (e) {
                    return;
                }
                const k = Object.assign({}, root.known);
                for (let i = 0; i < root.screens.length; i++)
                    if (root.screens[i].edid !== false)
                        k[root.screens[i].name] = root.screens[i];
                root.known = k;
                root.publish();
                root.settle(false);
            }
        }
    }

    function refresh(): void {
        probe.running = false;
        probe.running = true;
    }

    // ── what failed, learned — and the way out of it, at once
    function heard(line: string): void {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (e) {
            return;
        }
        if (ev.event === "fail")
            root.learn(ev.output, ev.mode, ev.why);
    }

    function learn(output: string, mode: string, why: string): void {
        const s = root.known[output];
        // a screen that never told us what it is, or a mode it does not list
        // (Hyprland's 1024×768 stand-in while the EDID was missing): nothing to learn
        if (!s || (s.modes ?? []).indexOf(mode) < 0) {
            console.log(`Velvet: screen ${output} failed ${mode} (${why}) — not one of its own modes, ignored`);
            return;
        }
        const key = root.keyOf(s);
        const book = JSON.parse(JSON.stringify(root.book));
        const e = book[key] ?? { bad: [], fails: {} };
        if (e.bad.indexOf(mode) < 0)
            e.bad.push(mode);
        const f = e.fails[mode] ?? { count: 0 };
        e.fails[mode] = { count: (f.count ?? 0) + 1, last: Date.now(), why: why };
        book[key] = e;
        root.book = book;
        bookFile.setText(JSON.stringify(book, null, 2) + "\n");
        // a RESOLUTION picked by hand that failed: back to AUTO, which now steps round it
        if (Config.display.mode === mode)
            Config.display.mode = "auto";
        const t = root.target(s);
        console.log(`Velvet: screen ${output} could not run ${mode} (${why}) — remembered, now ${t.mode}`);
        // Straight to Hyprland, even while the screen is away: the rule stays
        // and the next connect already uses it (the old one would fail again).
        const c = (root.screens.find(x => x.name === output) ?? s).current;
        root.note(output, t.mode, t.scale);
        root.run([root.ruleFor(output, t.mode, c.x, c.y, t.scale)]);
        root.publish();
        // said once the picture is back (a screen needs a few seconds to sync)
        root.toastText = `${output} COULD NOT HOLD ${root.hz(mode)}${output.startsWith("HDMI") && (root.parse(mode)?.rr ?? 0) > 120 ? " OVER HDMI" : ""} — NOW ${root.hz(t.mode)}${output.startsWith("HDMI") && (root.parse(mode)?.rr ?? 0) > 120 ? " · DISPLAYPORT CARRIES IT" : ""} · SETTINGS → DISPLAY`;
        toastLater.restart();
    }

    property string toastText: ""

    Timer {
        id: toastLater

        interval: 3500
        onTriggered: Toast.show(root.toastText, "warn", 9000)
    }

    function forget(): void {
        root.book = ({});
        bookFile.setText("{}\n");
        // "try the fast modes" from SAFE means AUTO again
        if (Config.display.mode === "safe") {
            Config.display.mode = "auto";
        } else {
            root.publish();
            root.settle(true);
        }
        Toast.show("SCREENS FORGOT WHAT FAILED — TRYING THE FASTEST MODES AGAIN", "info", 4200);
    }

    // a change of the setting settles by itself (onModeChanged); the same
    // setting again (SAFE while SAFE, after a manual change) settles here
    function setMode(mode: string): void {
        if (Config.display.mode !== mode) {
            Config.display.mode = mode;
            return;
        }
        root.publish();
        root.settle(true);
    }

    FileView {
        id: bookFile

        path: root.bookPath
        printErrors: false
        watchChanges: true

        // `velvet display forget` moves the file away while the shell runs
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.book = d && typeof d === "object" && !Array.isArray(d) ? d : ({});
            } catch (e) {
                root.book = ({});
            }
            root.publish();
        }
        onLoadFailed: {
            root.book = ({});
            root.publish();
        }
    }

    // The watcher: one python process reading Hyprland's log for the whole
    // session (it sleeps on the file, ~0 % CPU). It comes back if it ends.
    Process {
        id: watcher

        command: ["python3", root.script, "--watch"]
        running: false
        stdout: SplitParser {
            onRead: line => root.heard(line)
        }
        onExited: {
            if (root.manage)
                rewatch.restart();
        }
    }

    Timer {
        id: rewatch

        interval: 5000
        onTriggered: {
            if (root.manage && Config.loaded)
                watcher.running = true;
        }
    }

    onManageChanged: {
        if (root.manage && Config.loaded)
            watcher.running = true;
        else
            watcher.running = false;
    }

    Timer {
        id: again

        interval: 1500
        onTriggered: root.refresh()
    }

    // at start, once the settings are in
    Timer {
        running: Config.loaded
        interval: 400
        onTriggered: {
            root.refresh();
            if (root.manage)
                watcher.running = true;
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            // a reload puts the monitor lines of hyprland.lua back first
            if (n === "monitoradded" || n === "monitorremoved" || n === "monitoraddedv2" || n === "configreloaded")
                later.restart();
        }
    }

    Timer {
        id: later

        interval: 700
        onTriggered: root.refresh()
    }

    // the menu changed RESOLUTION, SCALE or the switch: at once
    Connections {
        target: Config.display

        function onModeChanged(): void {
            root.publish();
            root.settle(true);
        }
        function onScaleChanged(): void {
            root.publish();
            root.settle(true);
        }
        function onManageChanged(): void {
            root.refresh();
        }
    }

    // velvet display [safe|auto|forget] and anything else that wants to know
    IpcHandler {
        target: "screens"

        function list(): string {
            return JSON.stringify(root.screens.map(s => ({
                        name: s.name,
                        description: s.description,
                        edid: s.edid !== false,
                        current: s.current,
                        best: s.best.mode,
                        target: root.skip(s) ? null : root.target(s).mode,
                        failed: root.badOf(s)
                    })));
        }
        function safe(): void {
            root.setMode("safe");
        }
        function auto(): void {
            root.setMode("auto");
        }
        function forget(): void {
            root.forget();
        }
        function refresh(): void {
            root.refresh();
        }
    }
}
