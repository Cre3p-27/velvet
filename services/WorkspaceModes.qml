//  VELVET  ·  services/WorkspaceModes.qml
//  Each desktop can be told how its windows sit: NORMAL (as Hyprland and your
//  rules decide), TILING (every window tiles) or FLOATING (every window floats
//  — the infinite canvas). Set in SUPER+TAB → DESKTOP, kept in
//  scene.workspaceModes as { "<desktop>": "tiling" | "floating" }.
//
//  Two halves:
//    · a Hyprland window rule per forced desktop, so a window opens in the
//      right mode straight away (no tiled flash). Dialogs (modal windows) are
//      left out — a file picker should still float on a tiling desktop.
//    · the shell itself puts the windows that are already there into the mode
//      when you change it, and a window you carry onto a forced desktop.
//  After that the window is yours: SUPER+V or SUPER+D still toggles it — a
//  forced desktop does not fight you, it only decides how windows arrive.
//
//  Rules registered over `hyprctl eval` vanish with every config reload, so
//  they are sent again on `configreloaded`.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property var modes: {
        const m = Config.scene.workspaceModes;
        return m && typeof m === "object" ? m : ({});
    }

    function modeOf(ws: int): string {
        const m = root.modes[String(ws)];
        return m === "tiling" || m === "floating" ? m : "normal";
    }

    function setMode(ws: int, mode: string): void {
        if (ws < 1)
            return;
        const next = {};
        for (const k in root.modes)
            next[k] = root.modes[k];
        if (mode === "tiling" || mode === "floating")
            next[String(ws)] = mode;
        else
            delete next[String(ws)];
        Config.set("scene.workspaceModes", next);
    }

    // However the modes change (here, a look, the file by hand): the rules
    // follow, and the windows already on a desktop whose mode changed too.
    property var last: ({})

    onModesChanged: {
        const all = {};
        for (const k in root.modes)
            all[k] = true;
        for (const k in root.last)
            all[k] = true;
        for (const k in all)
            if ((root.modes[k] ?? "") !== (root.last[k] ?? ""))
                root.forget(parseInt(k));
        root.last = Object.assign({}, root.modes);
        root.pushRules();
        sweepSoon.restart();
    }

    // ── the rules ───────────────────────────────────────────────────────────
    // Every desktop that was ever forced keeps both of its named rules; the
    // one that does not apply is switched off, never left on.
    property var known: ({})

    function pushRules(): void {
        if (!Hypr.usingLua)
            return; // the classic dialect has no live rules: the sweep does it all
        const lines = [];
        const all = {};
        for (const k in root.known)
            all[k] = true;
        for (const k in root.modes)
            all[k] = true;
        for (const k in all) {
            const ws = parseInt(k);
            if (!(ws > 0))
                continue;
            const m = root.modeOf(ws);
            lines.push(`hl.window_rule({ name = "velvet-ws-${ws}-float", enabled = ${m === "floating"}, match = { workspace = "${ws}", modal = false }, float = true })`);
            lines.push(`hl.window_rule({ name = "velvet-ws-${ws}-tile", enabled = ${m === "tiling"}, match = { workspace = "${ws}", modal = false }, tile = true })`);
        }
        root.known = all;
        if (lines.length === 0)
            return;
        rules.command = ["hyprctl", "eval", lines.join("\n")];
        rules.running = false;
        rules.running = true;
    }

    Process {
        id: rules

        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (t && t !== "ok")
                    console.warn(`WorkspaceModes: rules → ${t}`);
            }
        }
    }

    // ── the sweep: windows already there, and windows carried in ───────────
    // Each window is put into its desktop's mode once per desktop it lands
    // on; a later toggle by hand is left alone.
    // The book outlives a shell restart (it sits in the runtime folder), so a
    // restart does not undo your toggles; a new login starts it empty.
    property var done: ({})
    property bool bookRead: false

    FileView {
        id: book

        path: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/velvet-wsmodes-done.json`
        printErrors: false
        blockLoading: true
        onLoaded: {
            try {
                const d = JSON.parse(book.text());
                if (d && typeof d === "object")
                    root.done = d;
            } catch (e) {}
            root.bookRead = true;
        }
        onLoadFailed: root.bookRead = true
    }

    function forget(ws: int): void {
        const next = {};
        for (const k in root.done)
            if (!k.endsWith(`@${ws}`))
                next[k] = root.done[k];
        root.done = next;
    }

    readonly property bool anyForced: Object.keys(root.modes).length > 0

    Timer {
        id: sweepSoon

        interval: 180
        onTriggered: {
            if (!root.anyForced)
                return;
            if (!root.bookRead) {
                sweepSoon.restart();
                return;
            }
            clients.running = false;
            clients.running = true;
        }
    }

    Process {
        id: clients

        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: root.sweep(text)
        }
    }

    function fixedClass(cls: string): bool {
        return cls.startsWith("dev.velvet.") || cls === "org.quickshell";
    }

    function sweep(json: string): void {
        let list = [];
        try {
            list = JSON.parse(json);
        } catch (e) {
            return;
        }
        const seen = {};
        const next = Object.assign({}, root.done);
        for (const c of list) {
            const ws = c.workspace?.id ?? -1;
            if (!(ws > 0) || !c.mapped)
                continue;
            const key = `${c.address}@${ws}`;
            seen[c.address] = true;
            if (next[key])
                continue;
            next[key] = true;
            const mode = root.modeOf(ws);
            if (mode === "normal" || c.pinned || c.fullscreen > 0 || root.fixedClass(c.class ?? ""))
                continue;
            if (c.title === "Velvet Settings" || c.title === "Welcome to Velvet")
                continue;
            if (mode === "floating" && !c.floating)
                Hypr.setFloating(c.address);
            else if (mode === "tiling" && c.floating)
                Hypr.setTiled(c.address);
        }
        // closed windows leave the book
        for (const k in next)
            if (!seen[k.split("@")[0]])
                delete next[k];
        root.done = next;
        book.setText(JSON.stringify(next));
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n === "configreloaded") {
                root.known = ({});
                root.pushRules();
            } else if (n === "openwindow" || n === "movewindowv2") {
                if (root.anyForced)
                    sweepSoon.restart();
            }
        }
    }

    // qs -c velvet ipc call wsmode set 3 tiling   (normal · tiling · floating)
    IpcHandler {
        target: "wsmode"

        function set(ws: int, mode: string): void {
            root.setMode(ws, mode);
        }
        function get(ws: int): string {
            return root.modeOf(ws);
        }
        function list(): string {
            return JSON.stringify(root.modes);
        }
    }

    // Startup: the rules, and one sweep — a window the book already knows (the
    // shell restarted) keeps whatever you made of it.
    Timer {
        running: true
        interval: 1600
        onTriggered: {
            root.pushRules();
            sweepSoon.restart();
        }
    }
}
