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

    // ── the WIDGET STUDIO's ideas: ready to use, or to start from
    readonly property var gallery: [
        {
            id: "ring-clock",
            name: "Ring clock",
            about: "The time in a ring that breathes with the music",
            code: root.starter
        },
        {
            id: "music-bars",
            name: "Music bars",
            about: "The music as bars, the song underneath",
            code: `// name: Music bars
// size: 300x150
function render(ctx, f) {
    const n = 24, gap = 3, bw = (f.w - 20 - gap * (n - 1)) / n;
    for (let i = 0; i < n; i++) {
        const v = f.audio.length ? f.audio[Math.floor(i * f.audio.length / n)] : 0.08 + 0.06 * Math.sin(f.t * 3 + i);
        const h = Math.max(4, v * (f.h - 40));
        ctx.globalAlpha = 0.45 + 0.55 * v;
        ctx.fillStyle = f.accent;
        ctx.fillRect(10 + i * (bw + gap), f.h - 30 - h, bw, h);
    }
    ctx.globalAlpha = 1;
    ctx.fillStyle = f.dim;
    ctx.font = "600 13px sans-serif";
    ctx.fillText(f.music.title ? f.music.title + " · " + f.music.artist : "nothing playing", 10, f.h - 10);
}
`
        },
        {
            id: "focus-timer",
            name: "Focus timer",
            about: "Click to start 25 minutes of focus, click again to pause",
            code: `// name: Focus timer
// size: 220x220
// fps: 10
function render(ctx, f) {
    const s = f.store;
    if (s.left === undefined) { s.left = 25 * 60; s.run = false; }
    if (s.run) s.left = Math.max(0, s.left - f.dt);
    const r = Math.min(f.w, f.h) / 2 - 14, k = s.left / (25 * 60);
    ctx.lineCap = "round";
    ctx.lineWidth = 10;
    ctx.strokeStyle = f.dim;
    ctx.globalAlpha = 0.25;
    ctx.beginPath(); ctx.arc(f.w / 2, f.h / 2, r, 0, Math.PI * 2); ctx.stroke();
    ctx.globalAlpha = 1;
    ctx.strokeStyle = f.accent;
    ctx.beginPath(); ctx.arc(f.w / 2, f.h / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * k); ctx.stroke();
    const m = Math.floor(s.left / 60), sec = Math.floor(s.left % 60);
    ctx.fillStyle = f.ink;
    ctx.font = "600 34px sans-serif";
    ctx.textAlign = "center"; ctx.textBaseline = "middle";
    ctx.fillText((m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec, f.w / 2, f.h / 2 - 6);
    ctx.font = "600 12px sans-serif";
    ctx.fillStyle = f.dim;
    ctx.fillText(s.left === 0 ? "done — click to restart" : (s.run ? "focus" : "click to start"), f.w / 2, f.h / 2 + 24);
}
function click(x, y, f) {
    const s = f.store;
    if (s.left === 0) s.left = 25 * 60;
    s.run = !s.run;
}
`
        },
        {
            id: "system-rings",
            name: "System rings",
            about: "CPU, memory and battery as three rings",
            code: `// name: System rings
// size: 300x120
function ring(ctx, x, y, r, v, label, f) {
    ctx.lineWidth = 7; ctx.lineCap = "round";
    ctx.strokeStyle = f.dim; ctx.globalAlpha = 0.25;
    ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.stroke();
    ctx.globalAlpha = 1; ctx.strokeStyle = f.accent;
    ctx.beginPath(); ctx.arc(x, y, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0, Math.min(1, v / 100))); ctx.stroke();
    ctx.fillStyle = f.ink; ctx.font = "600 14px sans-serif"; ctx.textAlign = "center"; ctx.textBaseline = "middle";
    ctx.fillText(v < 0 ? "–" : Math.round(v) + "%", x, y);
    ctx.fillStyle = f.dim; ctx.font = "600 10px sans-serif";
    ctx.fillText(label, x, y + r + 14);
}
function render(ctx, f) {
    ring(ctx, 50, 50, 32, f.cpu, "CPU", f);
    ring(ctx, 150, 50, 32, f.ram, "MEMORY", f);
    ring(ctx, 250, 50, 32, f.battery.percent, f.battery.charging ? "CHARGING" : "BATTERY", f);
}
`
        },
        {
            id: "bubbles",
            name: "Bubbles",
            about: "Click and bubbles float up — a toy for your desk",
            code: `// name: Bubbles
// size: 220x260
function render(ctx, f) {
    const s = f.store;
    s.b = s.b || [];
    if (Math.random() < 0.03) s.b.push({ x: 20 + Math.random() * (f.w - 40), y: f.h, r: 4 + Math.random() * 10, v: 20 + Math.random() * 40 });
    s.b = s.b.filter(b => b.y + b.r > 0);
    for (const b of s.b) {
        b.y -= b.v * f.dt;
        b.x += Math.sin(f.t * 2 + b.r) * 0.3;
        ctx.strokeStyle = f.accent; ctx.lineWidth = 2; ctx.globalAlpha = 0.8;
        ctx.beginPath(); ctx.arc(b.x, b.y, b.r, 0, Math.PI * 2); ctx.stroke();
    }
    ctx.globalAlpha = 1;
}
function click(x, y, f) {
    for (let i = 0; i < 8; i++)
        f.store.b.push({ x: x + (Math.random() - 0.5) * 30, y: y, r: 4 + Math.random() * 12, v: 40 + Math.random() * 60 });
}
`
        }
    ]

    // ── the studio's hands
    function save(name: string, code: string): void {
        write.run(root.fileOf(name), code, false);
    }

    // the newest widget made (the studio opens it)
    property string lastMade: ""

    function made(name: string): void {
        root.lastMade = "";
        root.lastMade = name;
    }

    function fromIdea(idea: var): string {
        const name = root.freeName(idea.id);
        root.save(name, idea.code);
        root.made(name);
        return name;
    }

    function blank(): string {
        const name = root.freeName("my-widget");
        root.save(name, root.starter);
        root.made(name);
        return name;
    }

    // gone from the folder and from the desktop
    function remove(name: string): void {
        const list = Scenes.editing ?? [];
        for (let i = list.length - 1; i >= 0; i--)
            if (list[i]?.widget === `code:${name}`)
                Scenes.removeAt(i);
        remover.command = ["rm", "-f", "--", root.fileOf(name)];
        remover.running = false;
        remover.running = true;
    }

    Process {
        id: remover

        onExited: root.refresh()
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
                root.made(name);
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
            root.made(name);
            return root.place(name, true) ? `${name} is on the desktop` : `no widget called ${name}`;
        }
        function api(): string {
            return root.api;
        }
    }
}
