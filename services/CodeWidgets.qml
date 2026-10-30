//  VELVET  ·  services/CodeWidgets.qml
//  CODE WIDGETS: desktop widgets you write yourself — or have an AI write.
//  Each one is a single JavaScript file in ~/.config/velvet/widgets/ with a
//  `render(ctx, f)` that draws a frame on a canvas (components/CodeWidget.qml
//  runs it and reloads it the moment the file changes).
//
//  Three ways to make one (SUPER+TAB → DESKTOP → the tray → YOUR CODE WIDGETS):
//    NEW          a starter file opens in your editor — change it, save, watch
//    FOR MY AI    the instructions (this API, the starter, your idea) go to the
//                 clipboard for any AI chat; PASTE CODE brings its answer back
//    ASK VELLY    she writes it herself (widget.api, widget.make) and puts it
//                 on your desktop
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.config/velvet/widgets`
    readonly property string input: `${Qt.resolvedUrl("../bin/velvet-input")}`.replace(/^file:\/\//, "")

    // the widgets there are, by name (the file without .js) — looked up while
    // the settings are open (the tray shows them) and after every change here
    property var names: []

    function refresh(): void {
        lister.running = false;
        lister.running = true;
    }

    function fileOf(name: string): string {
        return `${root.dir}/${name}.js`;
    }

    function safeName(name: string): string {
        const n = `${name ?? ""}`.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 32);
        return n || "widget";
    }

    function freeName(base: string): string {
        let n = root.safeName(base);
        let i = 2;
        const b = n;
        while (root.names.indexOf(n) >= 0)
            n = `${b}-${i++}`;
        return n;
    }

    readonly property string starter: `// name: My widget
// size: 220x220
// A Velvet code widget. Change anything, save — it updates on the desktop at once.

function render(ctx, f) {
    const r = Math.min(f.w, f.h) / 2 - 12;
    // a ring that breathes with the music
    ctx.lineWidth = 6;
    ctx.strokeStyle = f.accent;
    ctx.beginPath();
    ctx.arc(f.w / 2, f.h / 2, r * (0.86 + 0.14 * f.level), 0, Math.PI * 2);
    ctx.stroke();
    // the time in the middle
    ctx.fillStyle = f.ink;
    ctx.font = "600 36px sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(Qt.formatTime(f.now, "HH:mm"), f.w / 2, f.h / 2);
}

function click(x, y, f) {
    f.store.clicks = (f.store.clicks || 0) + 1;
}
`

    readonly property string api: `VELVET CODE WIDGETS — the API
A widget is ONE JavaScript file: ~/.config/velvet/widgets/<name>.js
Optional header lines at the top:
  // name: Shown name
  // size: 220x160        its size on the desktop, in pixels (default 220x220)
  // fps: 30              how often it is drawn (1-60, default 30)
It defines:
  function render(ctx, f)   draws one frame — the canvas is cleared before each call
  function click(x, y, f)   optional: a click at x, y inside it
ctx is a 2D canvas context like the HTML canvas: fillRect, strokeRect, clearRect, beginPath,
moveTo, lineTo, arc, arcTo, bezierCurveTo, quadraticCurveTo, rect, closePath, fill, stroke,
fillText, strokeText, measureText, save, restore, translate, rotate, scale, globalAlpha,
fillStyle, strokeStyle, lineWidth, lineCap, lineJoin, font ("600 24px sans-serif"),
textAlign, textBaseline, createLinearGradient, createRadialGradient, shadowBlur, shadowColor.
No images, no network, no files: plain drawing.
f holds what the shell knows, fresh each frame:
  f.w, f.h        the widget's size        f.t, f.dt   seconds since it started, since the last frame
  f.now           a Date (Qt.formatTime(f.now, "HH:mm") formats it)
  f.accent, f.ink, f.dim, f.surface        the shell's colours ("#rrggbb") — use them
  f.audio         array of 0..1, the music's spectrum (lows first);  f.level  its loudness 0..1
  f.music         { title, artist, playing, length }
  f.cpu, f.ram    percent;  f.battery { percent (-1: none), charging }
  f.mouse         { x, y } while the pointer is over it, else null
  f.store         an object of your own that survives between frames (counters, particles …)
Rules: keep render() fast (no loops over thousands of things), draw everything with ctx,
use f.accent / f.ink so it matches every look. An error shows on the widget itself.`

    function prompt(idea: string): string {
        return `Write a desktop widget for my Velvet shell. Answer with the complete JavaScript file only.

What I want: ${idea && idea.trim() !== "" ? idea.trim() : "(describe it here)"}

${root.api}

A starter that works, to build on:
${root.starter}`;
    }

    // ── NEW: a starter file, opened in your editor
    function newWidget(): string {
        const name = root.freeName("my-widget");
        write.run(root.fileOf(name), root.starter, true);
        // on the desktop at once: every save shows there while you edit
        placeSoon.name = name;
        placeSoon.restart();
        return name;
    }

    function edit(name: string): void {
        Hypr.exec(`xdg-open ${Apps.shq(root.fileOf(name))}`);
    }

    // ── FOR MY AI: the instructions to the clipboard
    function copyForAi(idea: string): void {
        copier.command = [root.input, "copy", root.prompt(idea)];
        copier.running = false;
        copier.running = true;
        Toast.show("COPIED · PASTE IT INTO ANY AI CHAT, THEN COPY ITS CODE AND PRESS PASTE CODE", "ok", 5200);
    }

    // ── PASTE CODE: what an AI answered, from the clipboard into a new widget
    function pasteCode(): void {
        paster.running = false;
        paster.running = true;
    }

    // put one on the desktop (the desk's own widget layer)
    function place(name: string, known: bool): bool {
        if (!known && root.names.indexOf(name) < 0)
            return false;
        Scenes.add({
            kind: "widget",
            widget: `code:${name}`,
            name: name.toUpperCase(),
            x: 0.38,
            y: 0.3,
            w: 0.24,
            h: 0.3,
            opts: {
                frame: "glass",
                opacity: -1
            }
        });
        return true;
    }

    Process {
        id: lister

        running: true
        command: ["bash", "-c", `mkdir -p "$1" && cd "$1" && ls -1 -- *.js 2>/dev/null`, "list", root.dir]
        stdout: StdioCollector {
            onStreamFinished: root.names = text.split("\n").filter(l => l.endsWith(".js")).map(l => l.slice(0, -3))
        }
    }

    Timer {
        running: Panels.settings
        interval: 2500
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: copier
    }

    Process {
        id: paster

        command: [root.input, "paste"]
        stdout: StdioCollector {
            onStreamFinished: {
                // an AI likes to wrap code in a ``` fence: take what is inside
                let code = text;
                const fence = code.match(/```[a-zA-Z]*\n([\s\S]*?)```/);
                if (fence)
                    code = fence[1];
                if (code.indexOf("function render") < 0) {
                    Toast.show("THE CLIPBOARD HOLDS NO WIDGET · IT NEEDS A function render(ctx, f)", "warn", 4200);
                    return;
                }
                const named = code.match(/^\/\/\s*name:\s*(.+)$/m);
                const name = root.freeName(named ? named[1] : "ai-widget");
                write.run(root.fileOf(name), code, false);
                Toast.show(`${name.toUpperCase()} IS READY · IT IS IN THE TRAY, AND ON YOUR DESKTOP`, "ok", 4200);
                placeSoon.name = name;
                placeSoon.restart();
            }
        }
    }

    // the folder needs a moment to see a new file
    Timer {
        id: placeSoon

        property string name: ""
        interval: 900
        onTriggered: root.place(placeSoon.name, false)
    }

    QtObject {
        id: write

        function run(path: string, text: string, open: bool): void {
            writer.command = ["bash", "-c", `mkdir -p "$(dirname "$1")" && printf '%s' "$2" > "$1"${open ? ' && xdg-open "$1" >/dev/null 2>&1 &' : ""}`, "write", path, text];
            writer.running = false;
            writer.running = true;
        }
    }

    Process {
        id: writer

        onExited: root.refresh()
    }

    // qs -c velvet ipc call codewidgets list | place <name> | api
    IpcHandler {
        target: "codewidgets"

        function list(): string {
            return root.names.join("\n");
        }
        // (Velly writes the file herself: it is taken on trust, and the
        // widget says so on the desktop if the file is not there)
        function place(name: string): string {
            root.refresh();
            return root.place(name, true) ? `${name} is on the desktop` : `no widget called ${name}`;
        }
        function api(): string {
            return root.api;
        }
    }
}
