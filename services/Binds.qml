//  VELVET  ·  services/Binds.qml
//  The global keybinds you can change from the key menu (the Fn+1 window).
//  A change is applied LIVE through hyprctl the moment you press the new
//  combo, and written to a small managed file — velvet-binds.lua / .conf —
//  that the generated velvet config sources last, so it also survives
//  reboot. Conflicts with binds that are not the shell's own are refused.
//
//  Deliberately imports neither qs.config nor qs.services: config/Shortcuts.qml
//  imports this module, so this file must not pull the config module in —
//  that would be a cycle.
pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") ?? ""
    readonly property string hyprDir: `${Quickshell.env("XDG_CONFIG_HOME") || (root.homeDir + "/.config")}/hypr`
    readonly property string storePath: `${root.homeDir}/.config/velvet/binds.json`
    readonly property string recordScript: `${Qt.resolvedUrl("../hypr/scripts/velvet-record.sh")}`.replace(/^file:\/\//, "")

    property var overrides: ({})   // id → { mods: ["SUPER","SHIFT"], key: "K" }
    property bool ready: false

    // Own dialect probe — this service is referenced from the config
    // module (Shortcuts.qml), so it must not touch qs.config or the other
    // services: that would be a circular import.
    property bool lua: true

    Process {
        running: true
        command: ["bash", "-c", 'test -f "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua" && echo lua || echo conf']

        stdout: StdioCollector {
            onStreamFinished: root.lua = text.trim() === "lua"
        }
    }

    // The twelve ANYWHERE binds. `ipc` is the command every dialect can
    // run; `globalName` is the quickshell:name the hyprlang dialect binds
    // through the global dispatcher (empty = a plain exec bind).
    readonly property var defs: [
        { id: "settings",      label: "Settings",              def: ["SUPER", "Tab"],            ipc: "qs -c velvet ipc call panels settings",      globalName: "settings" },
        { id: "launcher",      label: "Launcher",              def: ["SUPER", "Space"],          ipc: "qs -c velvet ipc call panels launcher",     globalName: "launcher" },
        { id: "notifications", label: "Notifications",         def: ["SUPER", "N"],              ipc: "qs -c velvet ipc call panels notifications", globalName: "notifications" },
        { id: "session",       label: "Power menu",            def: ["SUPER", "Escape"],         ipc: "qs -c velvet ipc call panels session",      globalName: "session" },
        { id: "lock",          label: "Lock the screen",       def: ["SUPER", "L"],              ipc: "qs -c velvet ipc call lock lock",           globalName: "" },
        { id: "record",        label: "Record · stop",         def: ["SUPER", "Return"],         ipc: `bash "${root.recordScript}"`,                globalName: "" },
        { id: "focus",         label: "Focus mode",            def: ["SUPER", "SHIFT", "F"],     ipc: "qs -c velvet ipc call focus toggle",        globalName: "focus" },
        { id: "wheel",         label: "Wallpaper wheel",       def: ["SUPER", "W"],              ipc: "qs -c velvet ipc call wheel toggle",        globalName: "wheel" },
        { id: "windowMap",     label: "The mini desktop",      def: ["SUPER", "M"],              ipc: "qs -c velvet ipc call map toggle",          globalName: "windowMap" },
        { id: "scene",         label: "Desktop you arranged",  def: ["SUPER", "SHIFT", "S"],     ipc: "qs -c velvet ipc call scene start",         globalName: "scene" },
        { id: "lyrics",        label: "Lyrics",                def: ["SUPER", "SHIFT", "L"],     ipc: "qs -c velvet ipc call lyrics toggle",       globalName: "lyrics" },
        { id: "keys",          label: "This list",             def: ["SUPER", "SHIFT", "K"],     ipc: "qs -c velvet ipc call keys toggle",         globalName: "keys" },
        { id: "velly",         label: "Velly · talk",          def: ["SUPER", "A"],              ipc: "qs -c velvet ipc call velly summon",        globalName: "" }
    ]

    // Binds added after an install: the Hyprland files in ~/.config/hypr only
    // learn them at the next UPDATE & REPAIR, so until then the shell adds
    // them itself (and again after every config reload, which forgets them).
    // Only when nothing is bound to the combo yet — never over the user's own.
    readonly property var lateDefs: ["velly"]

    function ensureLate(): void {
        let script = "";
        for (let i = 0; i < root.lateDefs.length; i++) {
            const d = root.defById(root.lateDefs[i]);
            if (!d)
                continue;
            const c = root.comboFor(d.id);
            const mask = root.comboMask(c);
            const key = c[c.length - 1];
            const add = root.lua
                ? `hyprctl eval '${`hl.bind("${root.luaTokens(c)}", hl.dsp.exec_cmd("${root.luaStr(d.ipc)}"), { description = "velvet" })`}'`
                : `hyprctl keyword bind "${root.hyprTokens(c)}, exec, ${d.ipc}"`;
            // bound already (by the user's files, by us, or to something else): leave it
            script += `hyprctl binds -j | python3 -c 'import json,sys; b=json.load(sys.stdin); sys.exit(0 if any(x.get("modmask")==${mask} and str(x.get("key","")).lower()=="${key.toLowerCase()}" for x in b) else 1)' || ${add}\n`;
        }
        if (script === "")
            return;
        lateRunner.command = ["bash", "-c", script];
        lateRunner.running = false;
        lateRunner.running = true;
    }

    Process {
        id: lateRunner

        command: ["true"]
    }

    Timer {
        running: true
        interval: 3500
        onTriggered: root.ensureLate()
    }

    Timer {
        id: lateAgain

        interval: 1200
        onTriggered: root.ensureLate()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded")
                lateAgain.restart();
        }
    }

    function defById(id: string): var {
        for (let i = 0; i < root.defs.length; i++)
            if (root.defs[i].id === id)
                return root.defs[i];
        return null;
    }

    function comboFor(id: string): var {
        const d = root.defById(id);
        if (!d)
            return ["SUPER", "Tab"];
        const o = root.overrides[id];
        return o ? o.mods.concat([o.key]) : d.def;
    }

    function display(id: string): string {
        const c = root.comboFor(id);
        const names = { SUPER: "Super", SHIFT: "Shift", CTRL: "Ctrl", ALT: "Alt" };
        const parts = [];
        for (let i = 0; i < c.length; i++)
            parts.push(i < c.length - 1 ? (names[c[i]] ?? c[i]) : c[i]);
        return parts.join(" + ");
    }

    // "SUPER SHIFT, K" — the hyprctl/hyprlang spelling.
    function hyprTokens(c: var): string {
        const mods = c.slice(0, -1).join(" ");
        const key = c[c.length - 1];
        return mods === "" ? key : `${mods}, ${key}`;
    }

    // "SUPER SHIFT + K" — the Lua spelling.
    function luaTokens(c: var): string {
        const mods = c.slice(0, -1).join(" + ");
        const key = c[c.length - 1];
        const pretty = key.length > 0 ? key.charAt(0).toUpperCase() + key.slice(1) : key;
        return mods === "" ? pretty : `${mods} + ${pretty}`;
    }

    // A string quoted for a Lua double-quoted literal — the record bind's
    // command carries quotes of its own, and an unescaped one is exactly
    // the "unexpected symbol near '.'" that breaks velvet.lua.
    function luaStr(s: string): string {
        return `${s}`.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
    }

    readonly property var modMasks: ({ SUPER: 64, SHIFT: 1, CTRL: 4, ALT: 8 })

    // ------------------------------------------------------- managed blocks
    //  Just the statements — HyprConf splices them into the generated
    //  velvet.lua / velvet.conf, so there is no separate file a boot
    //  could load before the shell has had a chance to create it.
    readonly property string confBinds: {
        let out = "";
        for (let i = 0; i < root.defs.length; i++) {
            const d = root.defs[i];
            const o = root.overrides[d.id];
            if (!o)
                continue;
            out += `unbind = ${root.hyprTokens(d.def)}\n`;
            if (d.globalName !== "")
                out += `bind = ${root.hyprTokens(o.mods.concat([o.key]))}, global, quickshell:${d.globalName}\n\n`;
            else
                out += `bind = ${root.hyprTokens(o.mods.concat([o.key]))}, exec, ${d.ipc}\n\n`;
        }
        return out;
    }

    readonly property string luaBinds: {
        let out = "";
        for (let i = 0; i < root.defs.length; i++) {
            const d = root.defs[i];
            const o = root.overrides[d.id];
            if (!o)
                continue;
            out += `hl.unbind("${root.luaTokens(d.def)}")\n`;
            out += `hl.bind("${root.luaTokens(o.mods.concat([o.key]))}", hl.dsp.exec_cmd("${root.luaStr(d.ipc)}"), { description = "velvet" })\n\n`;
        }
        return out;
    }

    function persist(): void {
        storeFile.setText(JSON.stringify(root.overrides, null, 2));
    }

    // ------------------------------------------------------------- changing
    property var pending: null    // { id, mods, key }

    // A combo that already belongs to another row of the shell itself is
    // refused up front — no probe needed, the answer is known.
    function takenByUs(mods: var, key: string): string {
        for (let i = 0; i < root.defs.length; i++) {
            const c = root.comboFor(root.defs[i].id);
            // Same key AND the exact same modifier set — a superset must
            // not match (Super+Shift+L is not Lock's Super+L).
            if (c.length - 1 !== mods.length)
                continue;
            if (c[c.length - 1].toUpperCase() !== key.toUpperCase())
                continue;
            let same = true;
            for (let m = 0; m < c.length - 1; m++) {
                if (mods.indexOf(c[m]) === -1) {
                    same = false;
                    break;
                }
            }
            if (same)
                return root.defs[i].label;
        }
        return "";
    }

    // A live bind whose combo is one of the shell's own — either a def's
    // default or its current override — is ours even when it was loaded
    // from the user's config and carries no description.
    function comboMask(c: var): int {
        let m = 0;
        for (let i = 0; i < c.length - 1; i++)
            m += root.modMasks[c[i]] ?? 0;
        return m;
    }

    function isShellCombo(key: string, mask: int): bool {
        for (let i = 0; i < root.defs.length; i++) {
            const d = root.defs[i];
            const cur = root.comboFor(d.id);
            if (cur[cur.length - 1].toUpperCase() === key.toUpperCase() && root.comboMask(cur) === mask)
                return true;
            if (d.def[d.def.length - 1].toUpperCase() === key.toUpperCase() && root.comboMask(d.def) === mask)
                return true;
        }
        return false;
    }

    function set(id: string, mods: var, key: string): void {
        const d = root.defById(id);
        if (!d || key === "")
            return;
        const owner = root.takenByUs(mods, key);
        if (owner !== "" && owner !== d.label) {
            Toast.show(`${root.display(id)} IS ${owner.toUpperCase()} — REBIND THAT ONE FIRST`, "warn", 4200);
            Sfx.play("back");
            return;
        }
        root.pending = { id: id, mods: mods.slice(), key: key };
        probe.running = false;
        probe.running = true;
    }

    function reset(id: string): void {
        const d = root.defById(id);
        if (!d)
            return;
        root.set(id, d.def.slice(0, -1), d.def[d.def.length - 1]);
    }

    function resetAll(): void {
        const old = root.overrides;
        root.overrides = ({});
        root.persist();
        for (let i = 0; i < root.defs.length; i++) {
            const d = root.defs[i];
            const o = old[d.id];
            if (o)
                applyLive(d, o.mods.concat([o.key]), d.def);
        }
        Toast.show("EVERY GLOBAL KEY IS BACK TO ITS DEFAULT", "info", 3200);
        Sfx.play("back");
    }

    // The conflict probe: hyprctl lists every live bind; a combo that
    // belongs to anything but the shell itself is refused rather than
    // silently stolen.
    Process {
        id: probe

        command: ["bash", "-c", "hyprctl binds -j 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                const p = root.pending;
                root.pending = null;
                if (!p)
                    return;
                const d = root.defById(p.id);
                if (!d)
                    return;
                const mask = p.mods.reduce((a, m) => a + (root.modMasks[m] ?? 0), 0);
                let taken = "";
                try {
                    const binds = JSON.parse(text);
                    for (let i = 0; i < binds.length; i++) {
                        const b = binds[i];
                        const arg = `${b.arg ?? ""}`;
                        // The shell's own binds are fair game: global
                        // quickshell: names, and anything the bind service
                        // planted (marked with the velvet description).
                        if (b.dispatcher === "global" && arg.startsWith("quickshell:"))
                            continue;
                        if (b.has_description && `${b.description ?? ""}` === "velvet")
                            continue;
                        if (root.isShellCombo(`${b.key ?? ""}`, b.modmask ?? -1))
                            continue;
                        if (mask === 0)
                            continue;
                        if (String(b.key ?? "").toUpperCase() === p.key.toUpperCase() && (b.modmask ?? -1) === mask) {
                            taken = `${b.dispatcher}`;
                            break;
                        }
                    }
                } catch (e) {
                    // Unparseable probe output: apply anyway — a bind that
                    // fails to land is louder than a probe that failed.
                }

                if (taken !== "") {
                    Toast.show(`${root.display(p.id)} IS ALREADY TAKEN BY ANOTHER BIND`, "warn", 4200);
                    Sfx.play("back");
                    return;
                }

                const oldCombo = root.comboFor(p.id);
                const next = Object.assign({}, root.overrides);
                next[p.id] = { mods: p.mods, key: p.key };
                root.overrides = next;
                root.persist();
                root.applyLive(d, oldCombo, p.mods.concat([p.key]));
                Toast.show(`${d.label.toUpperCase()} → ${root.display(p.id)}   ·   LIVE AND SAVED`, "ok", 3400);
                Sfx.play("select");
            }
        }
    }

    // The live half: unbind the combo that was there, bind the new one.
    // Lua configs speak through the compositor's own interpreter (eval) —
    // the same spellings velvet-shell.lua uses — and every bind the shell
    // plants carries the velvet description so the probe recognises it.
    function applyLive(d: var, oldCombo: var, newCombo: var): void {
        const oldLua = root.luaTokens(oldCombo);
        const newLua = root.luaTokens(newCombo);
        if (oldLua === newLua)
            return;
        if (root.lua) {
            const unbindS = `hl.unbind("${oldLua}")`;
            const bindS = `hl.bind("${newLua}", hl.dsp.exec_cmd("${root.luaStr(d.ipc)}"), { description = "velvet" })`;
            runner.command = ["bash", "-c", `hyprctl eval '${unbindS}'; hyprctl eval '${bindS}'`];
        } else {
            const oldT = root.hyprTokens(oldCombo);
            const newT = root.hyprTokens(newCombo);
            let cmd = `hyprctl keyword unbind "${oldT}"; hyprctl keyword bind "${newT}`;
            if (d.globalName !== "")
                cmd += `, global, quickshell:${d.globalName}"`;
            else
                cmd += `, exec, ${d.ipc}"`;
            runner.command = ["bash", "-c", cmd];
        }
        runner.running = false;
        runner.running = true;
    }

    Process {
        id: runner
        command: ["true"]
    }

    // ------------------------------------------------------------- storage
    FileView {
        id: storeFile

        path: root.storePath
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text()) ?? {};
                root.overrides = typeof parsed === "object" && !Array.isArray(parsed) ? parsed : ({});
            } catch (e) {
                root.overrides = ({});
            }
        }
        onLoadFailed: root.overrides = ({})
    }

    // One beat after the rest of the shell has done its startup dance:
    // load the overrides. The generated velvet config carries the bind
    // block inline, so there is nothing to materialise here.
    Timer {
        running: true
        interval: 1800
        onTriggered: {
            root.ready = true;
            root.persist();
        }
    }
}
