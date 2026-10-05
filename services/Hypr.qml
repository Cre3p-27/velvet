//  VELVET  ·  services/Hypr.qml
//  A thin, defensive wrapper over Quickshell's Hyprland and Wayland APIs.
//
//  Deliberately plain. Everything that talks to Hyprland and checks the answer
//  lives in Dispatch.qml; this file only names the actions and reads state.
//  The split is not tidiness — a QML file that fails to load does not say so
//  where you are looking. It registers its name and then answers every call
//  with "not a function", forty times a second, from a hollow object. Keeping
//  the newest machinery out of the file the whole bar depends on means a
//  mistake there costs dispatch, not the desktop.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Singleton {
    id: root

    // A window just opened somewhere. Deliberately no payload — listeners
    // read the refreshed toplevel list themselves, which is the part that
    // is actually reliable across event formats.
    signal windowOpened()

    // ───────────────────────────────────────────────────── which dialect
    readonly property bool usingLua: Dispatch.usingLua
    readonly property string dialectName: Dispatch.dialectName
    readonly property string status: Dispatch.status

    function act(classic: string, lua: string): void {
        Dispatch.act(classic, lua);
    }

    //  A drag pushes a new position many times a second. Those go straight
    //  down the socket — a process per frame would be visible as lag — and
    //  they are safe unverified because the click that began the drag went
    //  through act() and settled the dialect first.
    function fast(classic: string, lua: string): void {
        Hyprland.dispatch(Dispatch.usingLua ? lua : classic);
    }

    function dispatch(request: string): void {
        Hyprland.dispatch(request);
    }

    function luaStr(s: string): string {
        return Dispatch.luaStr(s);
    }

    // ══════════════════════════════════════════════════ the actions themselves
    //  Both dialects, written out once, so no call site has to know there are
    //  two. Every one of these was checked against Hyprland's own Lua example
    //  config and dispatcher reference rather than guessed from the classic
    //  name — `hl.dsp.focuswindow` and `silent = true`, which this shell used
    //  to send, are not part of that API at all.
    // When the shell itself last took you somewhere — so a guard that undoes
    // Hyprland's own jumps (Panels) can tell those from the ones you asked for.
    property real lastJumpAt: 0

    function focusWorkspace(id: int): void {
        root.lastJumpAt = Date.now();
        root.act(`workspace ${id}`, `hl.dsp.focus({ workspace = ${id} })`);
    }

    function cycleWorkspace(delta: int): void {
        root.lastJumpAt = Date.now();
        const target = delta > 0 ? "r+1" : "r-1";
        root.act(`workspace ${target}`, `hl.dsp.focus({ workspace = "${target}" })`);
    }

    function focusWindow(address: string): void {
        if (!address)
            return;
        root.lastJumpAt = Date.now();
        root.act(`focuswindow address:${address}`, `hl.dsp.focus({ window = "address:${address}" })`);
    }

    function closeWindow(address: string): void {
        if (!address)
            return;
        root.act(`closewindow address:${address}`, `hl.dsp.window.close({ window = "address:${address}" })`);
    }

    function toggleFloat(address: string): void {
        if (!address)
            return;
        root.act(`togglefloating address:${address}`, `hl.dsp.window.float({ action = "toggle", window = "address:${address}" })`);
    }

    function setFloating(address: string): void {
        if (!address)
            return;
        // `action = "set"` TOGGLES in this build (verified live: a floating
        // window sent it becomes tiled) — "enable" is the idempotent float.
        root.act(`setfloating address:${address}`, `hl.dsp.window.float({ action = "enable", window = "address:${address}" })`);
    }

    // On every desktop (Hyprland's pin: the window follows you to every
    // workspace). Only a floating window can be pinned.
    function setPinned(address: string, on: bool): void {
        if (!address)
            return;
        root.act(`pin address:${address}`, `hl.dsp.window.pin({ action = "${on ? "enable" : "disable"}", window = "address:${address}" })`);
    }

    // The same float, straight down the socket, for the moment a drag
    // starts: it has to land BEFORE the first slide, or the slide hits a
    // tiled window and is silently dropped.
    function setFloatingFast(address: string): void {
        if (!address)
            return;
        Hyprland.dispatch(`hl.dsp.window.float({ action = "enable", window = "address:${address}" })`);
    }

    function moveExact(address: string, x: int, y: int): void {
        if (!address)
            return;
        root.act(`movewindowpixel exact ${x} ${y},address:${address}`, `hl.dsp.window.move({ window = "address:${address}", x = ${x}, y = ${y}, relative = false })`);
    }

    // The same move, down the socket, for the middle of a drag.
    function slide(address: string, x: int, y: int): void {
        if (!address)
            return;
        root.fast(`movewindowpixel exact ${x} ${y},address:${address}`, `hl.dsp.window.move({ window = "address:${address}", x = ${x}, y = ${y}, relative = false })`);
    }

    function resizeExact(address: string, w: int, h: int): void {
        if (!address)
            return;
        root.act(`resizewindowpixel exact ${w} ${h},address:${address}`, `hl.dsp.window.resize({ window = "address:${address}", x = ${w}, y = ${h}, relative = false })`);
    }

    function resizeBy(address: string, dw: int, dh: int): void {
        if (!address || (dw === 0 && dh === 0))
            return;
        root.act(`resizewindowpixel ${dw} ${dh},address:${address}`, `hl.dsp.window.resize({ window = "address:${address}", x = ${dw}, y = ${dh}, relative = true })`);
    }

    // Move a window to a workspace WITHOUT following it. `follow = false` is
    // the Lua spelling of what the classic dialect calls "silent".
    function sendToWorkspace(address: string, ws: int): void {
        if (!address || ws === 0)
            return;
        root.act(`movetoworkspacesilent ${ws},address:${address}`, `hl.dsp.window.move({ window = "address:${address}", workspace = ${ws}, follow = false })`);
    }

    function focusMonitor(name: string): void {
        if (!name)
            return;
        root.act(`focusmonitor ${name}`, `hl.dsp.focus({ monitor = ${root.luaStr(name)} })`);
    }

    function exec(command: string): void {
        if (!command)
            return;
        const run = Pad.active ? Pad.launchPrefix + command : command;
        root.act(`exec ${run}`, `hl.dsp.exec_cmd(${root.luaStr(run)})`);
    }

    // Start something with window rules. The classic dialect takes them as a
    // `[rule;rule] cmd` prefix. The Lua dialect does NOT: exec_cmd hands the
    // whole string to sh, which then tries to run "[float;size…" and nothing
    // opens — while Hyprland still answers "ok". Its table form is not
    // reliable either (upstream discussion #15032: "ok", but nothing runs), so
    // in Lua the program starts plain and the caller places the window once
    // it exists (Scenes.place does exactly that).
    function execWith(rules: var, command: string): void {
        if (!command)
            return;
        const pre = rules && rules.length > 0 ? `[${rules.join(";")}] ` : "";
        const run = Pad.active ? Pad.launchPrefix + command : command;
        root.act(`exec ${pre}${run}`, `hl.dsp.exec_cmd(${root.luaStr(run)})`);
    }

    function exitSession(): void {
        root.act("exit", "hl.dsp.exit()");
    }

    function nextKeyboardLayout(): void {
        root.act("switchxkblayout current next", 'hl.dsp.switch_keyboard_layout({ device = "current", cmd = "next" })');
    }

    // ═══════════════════════════════════════════════════════════ what is there
    readonly property var workspaces: Hyprland.workspaces?.values ?? []
    readonly property var monitors: Hyprland.monitors?.values ?? []
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int activeWsId: focusedWorkspace?.id ?? 1

    // The ShellScreen the user is actually looking at — overlays follow this.
    readonly property ShellScreen focusedScreen: {
        const want = Hyprland.focusedMonitor?.name ?? "";
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === want)
                return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }

    readonly property Toplevel activeToplevel: ToplevelManager.activeToplevel
    readonly property string activeTitle: activeToplevel?.title ?? ""
    readonly property string activeAppId: activeToplevel?.appId ?? ""

    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitorFor(screen);
    }

    function workspaceOccupied(id: int): bool {
        for (let i = 0; i < workspaces.length; i++) {
            const ws = workspaces[i];
            if (ws.id === id)
                return (ws.lastIpcObject?.windows ?? 0) > 0;
        }
        return false;
    }

    function workspaceFor(id: int): var {
        for (let i = 0; i < workspaces.length; i++)
            if (workspaces[i].id === id)
                return workspaces[i];
        return null;
    }

    // Toplevels sitting on a given workspace — used for the little window pips.
    function windowsOn(id: int): int {
        const ws = workspaceFor(id);
        return ws ? (ws.lastIpcObject?.windows ?? 0) : 0;
    }

    // A window by its title, from Hyprland's live list ("" if none). The
    // settings window finds itself this way to go fullscreen.
    function addressOfTitle(title: string): string {
        const tops = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            if ((t?.title ?? "") === title) {
                const a = String(t.address ?? t.lastIpcObject?.address ?? "").replace(/^0x/, "");
                return a ? "0x" + a : "";
            }
        }
        return "";
    }

    // 0 = a normal window, 1 = maximised (the bar stays), 2 = fullscreen.
    function setFullscreenState(address: string, mode: int): void {
        if (!address)
            return;
        root.act(`fullscreenstate ${mode} 0`, `hl.dsp.window.fullscreen_state({ window = "address:${address}", internal = ${mode}, client = 0 })`);
    }

    // What is actually on that workspace, for the hover preview.
    function windowList(id: int): var {
        const out = [];
        const tops = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < tops.length; i++) {
            const raw = tops[i].lastIpcObject;
            if (!raw)
                continue;
            if ((raw.workspace?.id ?? -999) !== id)
                continue;
            out.push({
                title: raw.title ?? "",
                appId: raw.class ?? "",
                floating: raw.floating ?? false,
                address: raw.address ?? ""
            });
        }
        return out;
    }

    // The Wayland toplevel behind an address, which is what a live preview has
    // to be pointed at. `wayland` can be null while a window is still mapping,
    // and the map falls back to an icon card when it is.
    function toplevelFor(address: string): var {
        if (!address)
            return null;
        const bare = address.replace(/^0x/, "");
        const tops = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            if (!t)
                continue;
            const a = (t.address ?? t.lastIpcObject?.address ?? "").replace(/^0x/, "");
            if (a && a === bare)
                return t.wayland ?? null;
        }
        return null;
    }

    // ───────────────────────────────────────────────────────── keyboard layout
    property string keyboardLayout: ""

    function refreshKeyboard(): void {
        keyboards.running = false;
        keyboards.running = true;
    }

    Process {
        id: keyboards

        running: true
        command: ["bash", "-c", "hyprctl devices -j 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const kbs = data.keyboards ?? [];
                    for (let i = 0; i < kbs.length; i++) {
                        if (kbs[i].main) {
                            const km = kbs[i].active_keymap ?? "";
                            // "English (US)" → "US"; keep it short enough for a bar.
                            const m = km.match(/\(([^)]+)\)/);
                            root.keyboardLayout = (m ? m[1] : km).slice(0, 6).toUpperCase();
                            return;
                        }
                    }
                } catch (e) {
                    root.keyboardLayout = "";
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;
            if (n.includes("workspace") || n.includes("monitor") || n === "configreloaded")
                Hyprland.refreshWorkspaces();
            if (n.includes("window") || n.includes("mon") || n === "openwindow" || n === "closewindow")
                Hyprland.refreshToplevels();
            if (n === "openwindow")
                root.windowOpened();
            if (n === "activelayout")
                root.refreshKeyboard();
        }
    }
}
