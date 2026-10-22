//  VELVET  ·  services/DrawTerm.qml
//  Draw a terminal: hold the right mouse button on the bare desktop and pull
//  a frame — the terminal opens in it, at exactly that place and size.
//
//  Hyprland is told where the NEXT window of the terminal's class goes before
//  the terminal starts (a one-shot named rule under a Lua config, the classic
//  `[float;noanim;size;move]` prefix under hyprland.conf), so the window maps in
//  place instead of appearing somewhere and jumping. `no_anim` keeps Hyprland's
//  opening animation off it: the terminal IS the frame at once. The frame stays
//  where it is until `settled` — the window is in it, or it never came — so the
//  frame never shrinks away in the gap before the terminal shows.
//
//  Once the window is there the rule is switched off again, and a second look
//  corrects anything a theme or a border put off by a few pixels. A terminal
//  that starts slowly (a cold start, a busy machine) is still placed: the rule
//  goes after 15 s, the claim on the window only after 30 s.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // the terminal and the window class it maps with
    readonly property string term: Term.chosen !== "" ? Term.chosen : "kitty"
    readonly property string cls: ({
            "kitty": "kitty",
            "foot": "foot",
            "ghostty": "com.mitchellh.ghostty",
            "wezterm": "org.wezfurlong.wezterm",
            "alacritty": "Alacritty",
            "konsole": "org.kde.konsole",
            "xfce4-terminal": "xfce4-terminal",
            "xterm": "XTerm"
        })[root.term] ?? root.term

    // what is on its way: {x, y, w, h, at} in layout pixels, or null
    property var pending: null

    // the frame may leave: the terminal is in its place (placed), or it never came (not placed)
    signal settled(bool placed)

    function open(x: real, y: real, w: real, h: real): void {
        const b = Config.hypr.manage ? Math.max(0, Config.hypr.borderSize) : 2;
        // the frame you drew is the window's outside edge, border included
        const g = {
            x: Math.round(x + b),
            y: Math.round(y + b),
            w: Math.max(120, Math.round(w - 2 * b)),
            h: Math.max(80, Math.round(h - 2 * b)),
            at: Date.now()
        };
        root.pending = g;
        if (Hypr.usingLua) {
            rule.command = ["hyprctl", "eval", root.ruleLua(g, true)];
            rule.running = false;
            rule.running = true;
            startSoon.restart();
        } else {
            Hypr.execWith(["float", "noanim", `size ${g.w} ${g.h}`, `move ${g.x} ${g.y}`], root.term);
        }
        ruleExpire.restart();
        pendingExpire.restart();
    }

    function ruleLua(g: var, on: bool): string {
        const m = `match = { class = "^(${root.cls.replace(/[.]/g, "%.")})$" }`;
        if (!on)
            return `hl.window_rule({ name = "velvet-drawn", enabled = false, ${m} })`;
        return `hl.window_rule({ name = "velvet-drawn", enabled = true, ${m}, float = true, no_anim = true, size = { ${g.w}, ${g.h} }, move = { ${g.x}, ${g.y} } })`;
    }

    // the rule is in before the terminal starts
    Process {
        id: rule
    }

    Timer {
        id: startSoon

        interval: 60
        onTriggered: Hypr.exec(root.term)
    }

    // the rule goes: the window is in, or it is not coming — never leave it armed for somebody else's window
    function disarm(): void {
        if (!Hypr.usingLua)
            return;
        ruleOff.command = ["hyprctl", "eval", root.ruleLua(null, false)];
        ruleOff.running = false;
        ruleOff.running = true;
    }

    Process {
        id: ruleOff
    }

    // nothing opened in 15 s: the rule goes and the frame lets go; a terminal
    // that comes later is still placed (pendingExpire)
    Timer {
        id: ruleExpire

        interval: 15000
        onTriggered: {
            root.disarm();
            root.settled(false);
        }
    }

    Timer {
        id: pendingExpire

        interval: 30000
        onTriggered: root.pending = null
    }

    // the window is there: the rule goes, the frame may go, then the second look
    property string addr: ""
    property var want: null

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name !== "openwindow" || !root.pending)
                return;
            const parts = String(event.data ?? "").split(",");
            if (parts.length < 3 || parts[2] !== root.cls)
                return;
            root.want = root.pending;
            root.addr = "0x" + parts[0].replace(/^0x/, "");
            root.pending = null;
            ruleExpire.stop();
            pendingExpire.stop();
            root.disarm();
            root.settled(true);
            check.restart();
            recheck.restart();
        }
    }

    // and once more when the opening animation is over
    Timer {
        id: recheck

        interval: 1300
        onTriggered: check.triggered()
    }

    Timer {
        id: check

        interval: 450
        onTriggered: {
            const g = root.want;
            const t = (Hyprland.toplevels?.values ?? []).find(x => ("0x" + String(x?.address ?? x?.lastIpcObject?.address ?? "").replace(/^0x/, "")) === root.addr);
            const o = t?.lastIpcObject ?? null;
            if (!g || !o)
                return;
            const at = o.at ?? [g.x, g.y];
            const size = o.size ?? [g.w, g.h];
            // a rule (or the terminal itself) that maximises new windows
            // would win over the frame you drew: you drew it, so it goes
            if ((o.fullscreen ?? 0) > 0)
                Hypr.setFullscreenState(root.addr, 0);
            if (!o.floating)
                Hypr.setFloating(root.addr);
            if (Math.abs(size[0] - g.w) > 6 || Math.abs(size[1] - g.h) > 6)
                Hypr.resizeExact(root.addr, g.w, g.h);
            if (Math.abs(at[0] - g.x) > 4 || Math.abs(at[1] - g.y) > 4)
                Hypr.moveExact(root.addr, g.x, g.y);
        }
    }
}
