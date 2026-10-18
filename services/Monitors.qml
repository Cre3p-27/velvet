//  VELVET  ·  services/Monitors.qml
//  Every screen at its best, from the first moment: its own (native)
//  resolution, the fastest refresh at it, a scale that suits its size
//  (bin/velvet-monitors reads all that from the screen itself). Set live at
//  start, when a screen is plugged in, and again after every Hyprland config
//  reload (the reload puts the hand-written monitor lines back), and written
//  into velvet.lua (HyprConf) so the next login starts right.
//  DISPLAY → AUTO SCREEN SETUP turns it off; RESOLUTION and SCALE override it.
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

    // What a screen should run: AUTO (the screen's own best), or what the
    // menu says — a resolution only where that screen offers it.
    function target(s: var): var {
        const mode = Config.display.mode !== "auto" && (s.modes ?? []).indexOf(Config.display.mode) >= 0 ? Config.display.mode : s.best.mode;
        const want = Number(Config.display.scale);
        const scale = Config.display.scale !== "auto" && want >= 0.5 && want <= 4 ? want : s.best.scale;
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

    function luaStr(s: string): string {
        return `"${String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
    }

    // The rules for velvet.lua / velvet.conf (HyprConf writes them last, so
    // they win over the monitor lines of hyprland.lua at the next login).
    readonly property string luaRules: {
        if (!root.manage)
            return "";
        let out = "";
        for (let i = 0; i < root.screens.length; i++) {
            const s = root.screens[i];
            if (s.disabled)
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
            if (s.disabled)
                continue;
            const t = root.target(s);
            out += `monitor = ${s.name}, ${t.mode}, ${s.current.x}x${s.current.y}, ${t.scale}\n`;
        }
        return out;
    }

    // The choices the menu offers for RESOLUTION: the first screen's modes
    // (Config.monitorModes, so Schema needs no service).
    function publish(): void {
        const s = root.screens.length > 0 ? root.screens[0] : null;
        const out = [
            {
                value: "auto",
                label: s ? `AUTO · ${s.best.w}×${s.best.h} @ ${Math.round(s.best.rr)} HZ` : "AUTO"
            }
        ];
        if (s) {
            for (let i = 0; i < s.modes.length; i++) {
                const p = root.parse(s.modes[i]);
                if (p)
                    out.push({
                        value: s.modes[i],
                        label: `${p.w}×${p.h} @ ${Math.round(p.rr * 100) / 100} HZ${s.modes[i] === s.best.mode ? " · THE SCREEN'S OWN" : ""}`
                    });
            }
        }
        Config.monitorModes = out;
        if (s) {
            const t = root.target(s);
            root.status = `${s.name} · ${s.current.w}×${s.current.h} @ ${Math.round(s.current.rr)} HZ · SCALE ${s.current.scale} — BEST ${s.best.w}×${s.best.h} @ ${Math.round(s.best.rr)} HZ · ${s.best.scale}`;
        }
    }

    // Puts a screen on its target when it is not there already. Twice per
    // screen per ten seconds at most: a mode that does not take must never
    // turn into a loop of mode changes.
    property var lastApply: ({})

    function settle(): void {
        if (!root.manage || !Config.loaded)
            return;
        const cmds = [];
        const now = Date.now();
        const stamps = Object.assign({}, root.lastApply);
        for (let i = 0; i < root.screens.length; i++) {
            const s = root.screens[i];
            if (s.disabled)
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
            if (seen.length >= 2)
                continue;
            stamps[s.name] = seen.concat([now]);
            if (HyprConf.lua)
                cmds.push(`hyprctl eval '${`hl.monitor({ output = ${root.luaStr(s.name)}, mode = ${root.luaStr(t.mode)}, position = "${c.x}x${c.y}", scale = "${t.scale}" })`.replace(/'/g, "")}'`);
            else
                cmds.push(`hyprctl keyword monitor '${s.name},${t.mode},${c.x}x${c.y},${t.scale}'`);
            console.log(`Velvet: screen ${s.name} ${c.w}x${c.h}@${c.rr} ×${c.scale} → ${t.mode} ×${t.scale}`);
        }
        root.lastApply = stamps;
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
                root.publish();
                root.settle();
            }
        }
    }

    function refresh(): void {
        probe.running = false;
        probe.running = true;
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
        onTriggered: root.refresh()
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
            root.settle();
        }
        function onScaleChanged(): void {
            root.publish();
            root.settle();
        }
        function onManageChanged(): void {
            root.refresh();
        }
    }
}
