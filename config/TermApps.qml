//  VELVET  ·  config/TermApps.qml
//  The module catalogue for the desktop.
//
//  Two families live here. The six Velvet modules are the stdlib-only
//  programs in bin/, each of which takes the shell's own palette and (for
//  all of them) a `--tint` override — the same module can be INK, PAPER or
//  the accent. The extra modules are classic terminal programs — peaclock,
//  cbonsai, lavat, cmatrix and friends, plus a plain TERMINAL. They run
//  inside a terminal window exactly like the Velvet ones, so they float,
//  size, pin and rule the same way.
//
//  `flags` are each module's own switches, shown as toggle chips in the
//  designer: pick any combination, they are appended to the command. Which
//  extra modules exist on THIS machine is detected live — a module that is
//  not installed stays in the tray, greyed out, so you can see what is one
//  install away instead of wondering why the tray is short.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Absolute, not "on your PATH": the scene has to start on boot whether or
    // not ~/.local/bin made it into the login shell's environment.
    readonly property string dir: Quickshell.shellPath("bin")

    // -------------------------------------------------------- velvet modules
    readonly property var all: [
        {
            id: "clock",
            options: [
                { key: "12h", label: "HOURS", bool: true, arg: "--12h", choices: [{ v: "", t: "24H" }, { v: "on", t: "12H" }] },
                { key: "seconds", label: "SECONDS", bool: true, arg: "--seconds", choices: [{ v: "", t: "HIDDEN" }, { v: "on", t: "SHOWN" }] },
                { key: "no-date", label: "DATE", bool: true, arg: "--no-date", choices: [{ v: "", t: "SHOWN" }, { v: "on", t: "HIDDEN" }] },
                { key: "no-bar", label: "SECONDS LINE", bool: true, arg: "--no-bar", choices: [{ v: "", t: "SHOWN" }, { v: "on", t: "HIDDEN" }] },
                { key: "still", label: "LIGHT", note: "THE BAND THAT TRAVELS THROUGH THE DIGITS", bool: true, arg: "--still", choices: [{ v: "", t: "MOVING" }, { v: "on", t: "STILL" }] }
            ],
            bin: "velvet-clock",
            name: "CLOCK",
            icon: "schedule",
            sub: "BIG SOFT DIGITS THAT BREATHE",
            w: 0.22,
            h: 0.17
        },
        {
            id: "vitals",
            bin: "velvet-vitals",
            name: "VITALS",
            icon: "monitor_heart",
            sub: "CPU · MEMORY · LOAD, DRAWN LIVE",
            w: 0.26,
            h: 0.3
        },
        {
            id: "pulse",
            options: [
                { key: "bars-only", label: "LAYOUT", bool: true, arg: "--bars-only", choices: [{ v: "", t: "BARS + TRACK" }, { v: "on", t: "BARS ONLY" }] },
                { key: "no-note", label: "FOOTNOTE", bool: true, arg: "--no-note", choices: [{ v: "", t: "SHOWN" }, { v: "on", t: "HIDDEN" }] }
            ],
            bin: "velvet-pulse",
            name: "PULSE",
            icon: "graphic_eq",
            sub: "WHAT IS PLAYING, AS BARS",
            w: 0.3,
            h: 0.16
        },
        {
            id: "traffic",
            bin: "velvet-traffic",
            name: "TRAFFIC",
            icon: "swap_vert",
            sub: "UP AND DOWN, EVERY SECOND",
            w: 0.26,
            h: 0.2
        },
        {
            id: "space",
            bin: "velvet-space",
            name: "SPACE",
            icon: "pie_chart",
            sub: "WHERE THE DISK WENT",
            w: 0.24,
            h: 0.26
        },
        {
            id: "drift",
            options: [
                { key: "density", label: "DENSITY", arg: "--density", choices: [{ v: "0.5", t: "SPARSE" }, { v: "", t: "NORMAL" }, { v: "1.8", t: "DENSE" }, { v: "3", t: "CROWDED" }] },
                { key: "trails", label: "TRAILS", arg: "--trails", choices: [{ v: "short", t: "SHORT" }, { v: "", t: "NORMAL" }, { v: "long", t: "LONG" }] }
            ],
            bin: "velvet-drift",
            name: "DRIFT",
            icon: "blur_on",
            sub: "A QUIET FIELD THAT NEVER REPEATS",
            w: 0.34,
            h: 0.32
        }
    ]

    // -------------------------------------------------------- extra modules
    // Terminal programs the desktop can host too. `run` is the command that
    // goes inside the terminal window; `flags` are the module's own switches
    // as toggle chips in the designer. Everything else — class, title, size,
    // floating — Velvet handles, so a peaclock behaves exactly like a
    // velvet-clock.
    readonly property var tui: [
        {
            id: "peaclock",
            run: "peaclock",
            name: "PEACLOCK",
            icon: "schedule",
            sub: "THE VINTAGE SEGMENT CLOCK",
            w: 0.26,
            h: 0.16,
            flags: []
        },
        {
            id: "lavat",
            run: "lavat",
            name: "LAVAT",
            icon: "whatshot",
            sub: "THE LAVA LAMP",
            w: 0.22,
            h: 0.3,
            flags: [
                {
                    label: "BORDER",
                    arg: "--border"
                }
            ]
        },
        {
            id: "cbonsai",
            run: "cbonsai",
            name: "CBONSAI",
            icon: "nature",
            sub: "A TREE, GROWING LIVE",
            w: 0.26,
            h: 0.32,
            hold: true,
            flags: [
                {
                    label: "LIVE",
                    arg: "-l"
                },
                {
                    label: "INFINITE",
                    arg: "-i"
                },
                {
                    label: "SCREENSAVER",
                    arg: "-s"
                }
            ]
        },
        {
            id: "sptlrx",
            run: "sptlrx",
            name: "SPTLRX",
            icon: "music_note",
            sub: "THE LYRICS VISUALISER",
            w: 0.42,
            h: 0.18,
            flags: []
        },
        {
            id: "cava",
            wrap: "velvet-cava",
            options: [
                { key: "style", label: "STYLE", note: "WAVE AND LINE ARE DRAWN BY VELVET · SMOOTH, ON THE EDGE", arg: "--style", choices: [{ v: "", t: "BARS" }, { v: "wave", t: "WAVE" }, { v: "line", t: "LINE" }] },
                { key: "detail", label: "WAVE DETAIL", note: "CALM = ROUND HILLS · FINE = EVERY BAND", arg: "--detail", choices: [{ v: "calm", t: "CALM" }, { v: "", t: "NORMAL" }, { v: "fine", t: "FINE" }] },
                { key: "orient", label: "DIRECTION", note: "WHICH EDGE IT STANDS ON · REOPENS THE WINDOW", relaunch: true, arg: "--orient", choices: [{ v: "", t: "UP" }, { v: "down", t: "DOWN" }, { v: "centre", t: "FROM THE MIDDLE" }, { v: "left", t: "LEFT" }, { v: "right", t: "RIGHT" }] },
                { key: "channels", label: "CHANNELS", arg: "--channels", choices: [{ v: "", t: "STEREO" }, { v: "mono", t: "MONO" }] },
                { key: "reverse", label: "ORDER", note: "LOWS AND HIGHS SWAPPED", bool: true, arg: "--reverse", choices: [{ v: "", t: "NORMAL" }, { v: "on", t: "REVERSED" }] },
                { key: "level", label: "LEVEL", note: "AUTO FINDS IT ITSELF · FIXED NEVER OVERSHOOTS", arg: "--level", choices: [{ v: "", t: "AUTO" }, { v: "low", t: "LOW" }, { v: "mid", t: "MEDIUM" }, { v: "high", t: "HIGH" }] },
                { key: "colour", label: "COLOUR", note: "FROM YOUR WALLPAPER · FOLLOWS IT LIVE", arg: "--colour", choices: [{ v: "", t: "VELVET" }, { v: "accent", t: "ACCENT" }, { v: "alt", t: "SECOND" }, { v: "ink", t: "INK" }, { v: "plain", t: "TERMINAL" }] },
                { key: "bar", label: "BAR WIDTH", note: "BARS ONLY", arg: "--bar", choices: [{ v: "1", t: "THIN" }, { v: "", t: "NORMAL" }, { v: "4", t: "WIDE" }, { v: "8", t: "HUGE" }] },
                { key: "gap", label: "GAP", note: "BARS ONLY", arg: "--gap", choices: [{ v: "0", t: "NONE" }, { v: "", t: "1" }, { v: "2", t: "2" }, { v: "3", t: "3" }] },
                { key: "height", label: "HEIGHT", arg: "--height", choices: [{ v: "", t: "FULL" }, { v: "75", t: "75%" }, { v: "50", t: "HALF" }] },
                { key: "smooth", label: "SMOOTHING", arg: "--smooth", choices: [{ v: "", t: "NONE" }, { v: "monstercat", t: "MONSTERCAT" }, { v: "waves", t: "WAVES" }] },
                { key: "wave", label: "SHOW", bool: true, arg: "--wave", choices: [{ v: "", t: "SPECTRUM" }, { v: "on", t: "WAVEFORM" }] },
                { key: "fps", label: "FRAME RATE", arg: "--fps", choices: [{ v: "30", t: "30" }, { v: "", t: "60" }, { v: "144", t: "144" }] }
            ],
            run: "cava",
            name: "CAVA",
            icon: "graphic_eq",
            sub: "RAW AUDIO BARS",
            w: 0.32,
            h: 0.18,
            flags: []
        },
        {
            id: "btop",
            run: "btop",
            name: "BTOP",
            icon: "developer_board",
            sub: "LIVE PROCESSES",
            w: 0.34,
            h: 0.34,
            flags: []
        },
        {
            id: "fastfetch",
            run: "fastfetch",
            name: "FASTFETCH",
            icon: "terminal",
            sub: "THE MACHINE, ON ONE CARD",
            w: 0.3,
            h: 0.3,
            hold: true,
            flags: []
        },
        {
            id: "htop",
            run: "htop",
            name: "HTOP",
            icon: "memory",
            sub: "PROCESSES, SCROLLABLE",
            w: 0.3,
            h: 0.3,
            flags: [
                {
                    label: "TREE",
                    arg: "-t"
                }
            ]
        },
        {
            id: "bmon",
            run: "bmon",
            name: "BMON",
            icon: "swap_vert",
            sub: "NETWORK THROUGHPUT",
            w: 0.3,
            h: 0.28,
            flags: []
        },
        {
            id: "cmatrix",
            options: [
                { key: "C", label: "COLOUR", arg: "-C", choices: [{ v: "", t: "GREEN" }, { v: "cyan", t: "CYAN" }, { v: "blue", t: "BLUE" }, { v: "magenta", t: "MAGENTA" }, { v: "red", t: "RED" }, { v: "yellow", t: "YELLOW" }, { v: "white", t: "WHITE" }] },
                { key: "u", label: "SPEED", arg: "-u", choices: [{ v: "8", t: "SLOW" }, { v: "", t: "NORMAL" }, { v: "2", t: "FAST" }, { v: "0", t: "FLAT OUT" }] }
            ],
            run: "cmatrix",
            name: "CMATRIX",
            icon: "grid_on",
            sub: "THE MATRIX RAIN",
            w: 0.3,
            h: 0.26,
            flags: [
                {
                    label: "BOLD",
                    arg: "-b"
                },
                {
                    label: "RAINBOW",
                    arg: "-r"
                },
                {
                    label: "SCREENSAVER",
                    arg: "-s"
                }
            ]
        },
        {
            id: "unimatrix",
            options: [
                { key: "c", label: "COLOUR", arg: "-c", choices: [{ v: "", t: "GREEN" }, { v: "cyan", t: "CYAN" }, { v: "blue", t: "BLUE" }, { v: "magenta", t: "MAGENTA" }, { v: "red", t: "RED" }, { v: "yellow", t: "YELLOW" }, { v: "white", t: "WHITE" }] },
                { key: "s", label: "SPEED", arg: "-s", choices: [{ v: "40", t: "SLOW" }, { v: "", t: "NORMAL" }, { v: "96", t: "FAST" }] }
            ],
            run: "unimatrix",
            name: "UNIMATRIX",
            icon: "blur_on",
            sub: "MATRIX RAIN, GLYPHS",
            w: 0.3,
            h: 0.26,
            flags: [
                {
                    label: "ASCII",
                    arg: "-a"
                }
            ]
        },
        {
            id: "ttyclock",
            options: [
                { key: "C", label: "COLOUR", arg: "-C", choices: [{ v: "", t: "GREEN" }, { v: "6", t: "CYAN" }, { v: "4", t: "BLUE" }, { v: "5", t: "MAGENTA" }, { v: "1", t: "RED" }, { v: "3", t: "YELLOW" }, { v: "7", t: "WHITE" }] }
            ],
            run: "tty-clock",
            name: "TTY CLOCK",
            icon: "timer",
            sub: "ANALOGUE, IN TEXT",
            w: 0.3,
            h: 0.3,
            flags: [
                {
                    label: "SECONDS",
                    arg: "-s"
                },
                {
                    label: "CENTRE",
                    arg: "-C"
                },
                {
                    label: "12H",
                    arg: "-b"
                }
            ]
        },
        {
            id: "pipes",
            options: [
                { key: "p", label: "PIPES", arg: "-p", choices: [{ v: "", t: "1" }, { v: "3", t: "3" }, { v: "6", t: "6" }, { v: "12", t: "12" }] }
            ],
            run: "pipes.sh",
            name: "PIPES",
            icon: "tune",
            sub: "THE SCREENSAVER PIPES",
            w: 0.3,
            h: 0.24,
            flags: [
                {
                    label: "PLAIN",
                    arg: "-R"
                }
            ]
        },
        {
            id: "sl",
            run: "sl",
            name: "SL",
            icon: "arrow_forward",
            sub: "THE STEAM LOCOMOTIVE",
            w: 0.34,
            h: 0.16,
            flags: [
                {
                    label: "LITTLE",
                    arg: "-l"
                },
                {
                    label: "FLY",
                    arg: "-F"
                }
            ]
        },
        {
            id: "asciiquarium",
            run: "asciiquarium",
            name: "AQUARIUM",
            icon: "star",
            sub: "FISH, SWIMMING PAST",
            w: 0.32,
            h: 0.3,
            flags: []
        },
        {
            id: "ranger",
            run: "ranger",
            name: "RANGER",
            icon: "folder",
            sub: "FILES, THREE COLUMNS",
            w: 0.34,
            h: 0.3,
            flags: []
        },
        {
            id: "neofetch",
            run: "neofetch",
            name: "NEOFETCH",
            icon: "terminal",
            sub: "THE CLASSIC FETCH",
            w: 0.3,
            h: 0.28,
            hold: true,
            flags: []
        },
        {
            id: "gotop",
            run: "gotop",
            name: "GOTOP",
            icon: "developer_board",
            sub: "RESOURCES, COLOURED",
            w: 0.3,
            h: 0.28,
            flags: []
        },
        {
            id: "nvtop",
            run: "nvtop",
            name: "NVTOP",
            icon: "monitor",
            sub: "GPU USAGE, LIVE",
            w: 0.3,
            h: 0.28,
            flags: []
        },
        {
            id: "termdown",
            run: "termdown",
            name: "TERMDOWN",
            icon: "timer",
            sub: "A COUNTDOWN CLOCK",
            w: 0.3,
            h: 0.22,
            hold: true,
            flags: []
        },
        {
            id: "hollywood",
            run: "hollywood",
            name: "HOLLYWOOD",
            icon: "star",
            sub: "THE HACKER SPLIT-SCREEN",
            w: 0.42,
            h: 0.32,
            flags: []
        },
        {
            id: "shell",
            run: "bash",
            name: "TERMINAL",
            icon: "terminal",
            sub: "A PLAIN SHELL, ON THE DESKTOP",
            w: 0.3,
            h: 0.28,
            flags: []
        }
    ]

    // Which extra modules this machine cannot run yet, detected live.
    // `local` is the rescue list: the program is not on the PATH but exists
    // in ~/.local/bin, so Velvet launches it by absolute path instead.
    property var missing: []
    property var local: []

    readonly property string localDir: `${Quickshell.env("HOME")}/.local/bin`

    Process {
        id: detector

        running: true
        command: ["bash", "-c", `for p in peaclock lavat cbonsai sptlrx cava btop fastfetch htop bmon cmatrix unimatrix tty-clock pipes.sh sl asciiquarium ranger neofetch gotop nvtop termdown hollywood bash; do if command -v "$p" >/dev/null 2>&1; then continue; elif [ -x "${Quickshell.env("HOME")}/.local/bin/$p" ]; then echo "LOCAL $p"; else echo "$p"; fi; done`]

        stdout: StdioCollector {
            onStreamFinished: {
                const miss = [];
                const loc = [];
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].trim().split(" ");
                    if (parts[0] === "LOCAL" && parts[1])
                        loc.push(parts[1]);
                    else if (parts[0])
                        miss.push(parts[0]);
                }
                // Only on a real change: a fresh array every 15 s rebuilt the
                // DESKTOP tray (and cancelled a drag in progress).
                if (JSON.stringify(loc) !== JSON.stringify(root.local))
                    root.local = loc;
                if (miss.join("\n") !== root.missing.join("\n"))
                    root.missing = miss;
            }
        }
    }

    // Install something in another terminal and the chip lights up on its
    // own a few seconds later — no shell restart needed.
    Timer {
        interval: 15000
        repeat: true
        running: true
        onTriggered: {
            detector.running = false;
            detector.running = true;
        }
    }

    // ---------------------------------------------------------------- lookups
    // -------------------------------------------------- every velvet module
    // Understood by all six (bin/_velvet.py applies them to the finished
    // frame), shown in the designer above each module's own switches.
    readonly property var shared: [
        { key: "flip", label: "UPSIDE DOWN", note: "GRAPHS HANG FROM THE TOP", bool: true, arg: "--flip", choices: [{ v: "", t: "OFF" }, { v: "on", t: "ON" }] },
        { key: "mirror", label: "MIRROR", note: "GRAPHS RUN RIGHT TO LEFT · TEXT STAYS READABLE", bool: true, arg: "--mirror", choices: [{ v: "", t: "OFF" }, { v: "on", t: "ON" }] },
        { key: "align", label: "SITS", arg: "--align", choices: [{ v: "", t: "AS DRAWN" }, { v: "top", t: "TOP" }, { v: "middle", t: "MIDDLE" }, { v: "bottom", t: "BOTTOM" }] },
        { key: "frame", label: "OUTLINE", bool: true, arg: "--frame", choices: [{ v: "", t: "NONE" }, { v: "on", t: "ROUNDED LINE" }] },
        { key: "speed", label: "TEMPO", arg: "--speed", choices: [{ v: "0.5", t: "CALM" }, { v: "", t: "NORMAL" }, { v: "1.6", t: "LIVELY" }, { v: "2.5", t: "RUSH" }] },
        { key: "fps", label: "FRAME RATE", note: "LOWER COSTS LESS", arg: "--fps", choices: [{ v: "8", t: "8" }, { v: "15", t: "15" }, { v: "", t: "AUTO" }, { v: "30", t: "30" }, { v: "60", t: "60" }] }
    ]

    function optionsOf(id: string): var {
        const t = root.byId(id);
        return Array.isArray(t?.options) ? t.options : [];
    }

    // The arguments a set of chosen values stands for. Unknown keys and
    // values that are not one of the choices are dropped — the command line
    // only ever carries what the designer offered.
    function argsFor(options: var, values: var): string {
        const out = [];
        const vals = values ?? ({});
        for (let i = 0; i < options.length; i++) {
            const o = options[i];
            const v = vals[o.key];
            if (v === undefined || v === null || v === "")
                continue;
            if (!o.choices.some(c => c.v === v))
                continue;
            out.push(o.bool ? o.arg : `${o.arg} ${v}`);
        }
        return out.join(" ");
    }

    function byId(id: string): var {
        if (!id)
            return null;
        for (let i = 0; i < root.all.length; i++)
            if (root.all[i].id === id)
                return root.all[i];
        for (let i = 0; i < root.tui.length; i++)
            if (root.tui[i].id === id)
                return root.tui[i];
        return null;
    }

    function isTui(id: string): bool {
        for (let i = 0; i < root.tui.length; i++)
            if (root.tui[i].id === id)
                return true;
        return false;
    }

    function runOf(id: string): string {
        const t = root.byId(id);
        return t?.run ?? "";
    }

    function flagsOf(id: string): var {
        const t = root.byId(id);
        return Array.isArray(t?.flags) ? t.flags : [];
    }

    // One-shot programs draw their card and exit; the terminal window must
    // stay open for them to be of any use as a desktop module.
    function holdOf(id: string): bool {
        return root.byId(id)?.hold === true;
    }

    function missingCommand(id: string): string {
        const t = root.byId(id);
        if (!t?.run)
            return "";
        return String(t.run).split(" ")[0];
    }

    function isMissing(id: string): bool {
        const cmd = root.missingCommand(id);
        return cmd !== "" && root.missing.indexOf(cmd) !== -1;
    }

    // The command as it should run: an absolute path when the program lives
    // in ~/.local/bin and nothing on the PATH provides it.
    function resolvedRun(id: string): string {
        // A module Velvet dresses (cava) runs through its own wrapper in
        // bin/, which still needs the real program to be installed.
        const wrap = root.byId(id)?.wrap ?? "";
        if (wrap)
            return `${root.dir}/${wrap}`;
        const raw = root.runOf(id);
        if (!raw)
            return "";
        const word = String(raw).split(" ")[0];
        if (word && root.local.indexOf(word) !== -1)
            return `${root.localDir}/${raw}`;
        return raw;
    }

    function pathOf(id: string): string {
        const a = root.byId(id);
        return a?.bin ? `${root.dir}/${a.bin}` : "";
    }

    function nameOf(id: string): string {
        return root.byId(id)?.name ?? id.toUpperCase();
    }

    function iconOf(id: string): string {
        return root.byId(id)?.icon ?? "terminal";
    }
}
