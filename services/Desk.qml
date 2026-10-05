//  VELVET  ·  services/Desk.qml
//  What is on your desktop, and everything the map does to it.
//
//  Named Desk, not Canvas: `Canvas` is a QtQuick type, and a singleton by that
//  name is shadowed by it in every file that imports QtQuick — which is every
//  file. The symptom is not an error but a TypeError per binding, and anything
//  derived from it silently becoming NaN.
//
//  There is no camera and no infinite plane any more. The model is the one
//  Hyprland actually has: monitors, each carrying a row of workspaces, each
//  holding windows at real coordinates. The map lays those out side by side
//  and lets you zoom between "the desktop I am on" and "all of them".
//
//  One poll, one process: clients, monitors, workspaces and the focused window
//  come back in a single JSON object, so the four can never disagree with each
//  other mid-frame.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    // ══════════════════════════════════════════════════════════════ the state
    //  windows:  [{ address, x, y, w, h, title, cls, floating, ws, monName }]
    //  monitors: [{ name, id, x, y, w, h, focused, activeWs }]   logical pixels
    //  wsMon:    { wsId: monitorName }
    property var windows: []
    property var monitors: []
    property var wsMon: ({})
    property string activeAddress: ""
    property int pollFailures: 0
    property int polls: 0
    property int pollStarted: 0

    readonly property bool ready: root.monitors.length > 0

    readonly property string status: {
        if (root.pollFailures > 2)
            return "HYPRCTL IS NOT ANSWERING";
        const n = root.windows.length;
        const c = root.cells.length;
        return `${n} WINDOW${n === 1 ? "" : "S"}  ·  ${c} WORKSPACE${c === 1 ? "" : "S"}  ·  ${Hypr.dialectName}`;
    }

    function byAddress(address: string): var {
        for (let i = 0; i < root.windows.length; i++)
            if (root.windows[i].address === address)
                return root.windows[i];
        return null;
    }

    function monitorNamed(name: string): var {
        for (let i = 0; i < root.monitors.length; i++)
            if (root.monitors[i].name === name)
                return root.monitors[i];
        return null;
    }

    readonly property var focusedMonitor: {
        for (let i = 0; i < root.monitors.length; i++)
            if (root.monitors[i].focused)
                return root.monitors[i];
        return root.monitors.length > 0 ? root.monitors[0] : null;
    }

    // ═══════════════════════════════════════════════════════════════ the world
    //  Every workspace gets a cell the size of its monitor. Cells sit in a row
    //  per monitor, in id order, with a gap between them — so the map reads as
    //  "these are your desktops" rather than as one soup of windows.
    readonly property real gapX: 0.07
    readonly property real gapY: 0.14

    readonly property var cells: {
        const mons = root.monitors;
        if (mons.length === 0)
            return [];

        const byMon = ({});
        for (let i = 0; i < mons.length; i++)
            byMon[mons[i].name] = [];

        const taken = ({});

        // 1. every workspace Hyprland told us about
        const wm = root.wsMon;
        for (const key in wm) {
            const id = parseInt(key, 10);
            if (!(id > 0))
                continue;
            const name = wm[key];
            const home = (name in byMon) ? name : mons[0].name;
            byMon[home].push(id);
            taken[id] = true;
        }

        // 2. anything a window knows about that the workspace list missed
        for (let i = 0; i < root.windows.length; i++) {
            const w = root.windows[i];
            if (taken[w.ws] || !(w.ws > 0))
                continue;
            const home = (w.monName in byMon) ? w.monName : mons[0].name;
            byMon[home].push(w.ws);
            taken[w.ws] = true;
        }

        // 3. each monitor's own current workspace, even when it is empty
        for (let i = 0; i < mons.length; i++) {
            const a = mons[i].activeWs;
            if (a > 0 && !taken[a]) {
                byMon[mons[i].name].push(a);
                taken[a] = true;
            }
        }

        // 4. room to grow. Empty slots are the point: zooming out has to show
        //    you somewhere to put a window, not a dead end.
        //
        //    The focus monitor is worked out HERE, from the same `mons`
        //    snapshot `byMon` was built from, not read from `focusedMonitor`.
        //    That binding carries its own cached answer and could name a
        //    monitor that is no longer in this snapshot (a screen unplugged
        //    between two evaluations) — its name then misses `byMon` entirely
        //    and the map crashed on an undefined list.
        let focus = mons[0];
        for (let i = 0; i < mons.length; i++)
            if (mons[i].focused) {
                focus = mons[i];
                break;
            }
        const focusName = focus ? focus.name : "";
        if (byMon[focusName] === undefined)
            byMon[focusName] = [];
        const want = Math.max(1, Math.min(24, Config.map.desktops));
        let id = 1;
        while (byMon[focusName].length < want && id <= 99) {
            if (!taken[id]) {
                byMon[focusName].push(id);
                taken[id] = true;
            }
            id++;
        }

        // 5. lay them out
        const out = [];
        let rowY = 0;
        for (let i = 0; i < mons.length; i++) {
            const m = mons[i];
            const ids = byMon[m.name].slice().sort((a, b) => a - b);
            let colX = 0;
            for (let j = 0; j < ids.length; j++) {
                out.push({
                    ws: ids[j],
                    mon: m.name,
                    monX: m.x,
                    monY: m.y,
                    x: colX,
                    y: rowY,
                    w: m.w,
                    h: m.h,
                    active: ids[j] === m.activeWs
                });
                colX += m.w * (1 + root.gapX);
            }
            rowY += m.h * (1 + root.gapY);
        }
        return out;
    }

    readonly property var world: {
        const cs = root.cells;
        if (cs.length === 0)
            return {
                x: 0,
                y: 0,
                w: 1920,
                h: 1080
            };
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (let i = 0; i < cs.length; i++) {
            x0 = Math.min(x0, cs[i].x);
            y0 = Math.min(y0, cs[i].y);
            x1 = Math.max(x1, cs[i].x + cs[i].w);
            y1 = Math.max(y1, cs[i].y + cs[i].h);
        }
        return {
            x: x0,
            y: y0,
            w: Math.max(1, x1 - x0),
            h: Math.max(1, y1 - y0)
        };
    }

    function cellFor(ws: int): var {
        const cs = root.cells;
        for (let i = 0; i < cs.length; i++)
            if (cs[i].ws === ws)
                return cs[i];
        return null;
    }

    // The cell you are looking at right now — where the map opens.
    //
    // Hyprland's own event socket is asked first, because Quickshell keeps it
    // current to the millisecond while this file's poll can be five seconds
    // old when nothing is watching. The map used to open centred on whichever
    // workspace the last poll happened to catch, and then jump.
    readonly property var homeCell: {
        const live = root.cellFor(Hypr.activeWsId);
        if (live)
            return live;
        const m = root.focusedMonitor;
        return root.cellFor(m ? m.activeWs : -1) ?? (root.cells.length > 0 ? root.cells[0] : null);
    }

    // A window's place in map space. Its own coordinates are global layout
    // pixels, so the monitor origin comes off first.
    function worldX(win: var): real {
        const c = root.cellFor(win?.ws ?? 0);
        return c ? c.x + ((win?.x ?? 0) - c.monX) : 0;
    }

    function worldY(win: var): real {
        const c = root.cellFor(win?.ws ?? 0);
        return c ? c.y + ((win?.y ?? 0) - c.monY) : 0;
    }

    // …and back again: which cell a point in map space falls in.
    function cellAt(wx: real, wy: real): var {
        const cs = root.cells;
        for (let i = 0; i < cs.length; i++) {
            const c = cs[i];
            if (wx >= c.x && wx <= c.x + c.w && wy >= c.y && wy <= c.y + c.h)
                return c;
        }
        return null;
    }

    // ═══════════════════════════════════════════════════ doing things to them
    //  Every one of these goes through Hypr.act(), which reads Hyprland's
    //  answer back and retries in the other dialect if it was not "ok". That
    //  is the difference between a button that works and one that looks like
    //  it should.
    function focusWindow(address: string): void {
        if (!address)
            return;
        const w = root.byAddress(address);
        // Ask for the workspace first when it is not the one you are on.
        // focuswindow alone usually carries you there, but "usually" is not a
        // thing to build a click on.
        if (w && w.ws > 0 && w.ws !== Hypr.activeWsId)
            Hypr.focusWorkspace(w.ws);
        Hypr.focusWindow(address);
        settleTimer.restart();
    }

    // ── the infinite-canvas jump ──────────────────────────────────────────
    //  Hyprland cannot pan a workspace, so a "pan" is the windows themselves
    //  shifting together: every floating window on the target's desktop moves
    //  by the same delta until the target sits centred on its monitor. The
    //  world moves; the window keeps its place in it. The same idea as
    //  Super+H / Super+K (~/scripts/navigate_windows.py pan_to_window).
    function panTo(address: string): void {
        const w = root.byAddress(address);
        if (!w)
            return;
        // Ask for the workspace first when it is not the one you are on.
        if (w.ws > 0 && w.ws !== Hypr.activeWsId)
            Hypr.focusWorkspace(w.ws);
        if (w.floating !== true) {
            // A tiled window needs no pan: the layout already puts it in view.
            Hypr.focusWindow(address);
            return;
        }
        const m = root.monitorNamed(w.monName) ?? root.focusedMonitor;
        if (!m) {
            Hypr.focusWindow(address);
            return;
        }
        // The middle of what is visible, not of the panel: with the bar on
        // the left every jump landed half a bar too far left.
        const cx = m.x + (m.resL ?? 0) + (m.w - (m.resL ?? 0) - (m.resR ?? 0)) / 2;
        const cy = m.y + (m.resT ?? 0) + (m.h - (m.resT ?? 0) - (m.resB ?? 0)) / 2;
        const dx = Math.round(cx - (w.x + w.w / 2));
        const dy = Math.round(cy - (w.y + w.h / 2));
        if (dx === 0 && dy === 0) {
            Hypr.focusWindow(address);
            return;
        }
        // Every floater of that desktop, target included — one shared shift
        // is what makes it a pan rather than a move.
        const wins = root.windows;
        for (let i = 0; i < wins.length; i++) {
            const f = wins[i];
            if (f.ws === w.ws && f.floating && !Scenes.isFixedClass(String(f.cls ?? "")))
                Hypr.moveExact(f.address, Math.round(f.x + dx), Math.round(f.y + dy));
        }
        Hypr.focusWindow(address);
        settleTimer.restart();
    }

    function goToWorkspace(ws: int): void {
        if (!(ws > 0))
            return;
        Hypr.focusWorkspace(ws);
        settleTimer.restart();
    }

    function closeWindow(address: string): void {
        if (!address)
            return;
        // Velvet's little terminal programs run as `kitty … -e python3 …`.
        // A polite close request makes kitty ask "python3 is still running,
        // really quit?" instead of quitting — a dialog on a desktop that was
        // supposed to be cleared. Those windows are ended outright instead.
        const w = root.byAddress(address);
        if (w && String(w.cls ?? "").indexOf("dev.velvet.") === 0) {
            root.killTree(address);
            return;
        }
        Hypr.closeWindow(address);
        root.forget(address);
        settleTimer.restart();
    }

    //  End the window's process tree: the child (the actual program) gets
    //  SIGTERM first, which lets the terminal close itself with no dialog;
    //  whatever survives the beat is told, then killed. `pid` is the window's
    //  own process — kitty's — and its python3 child is found through it.
    function killTree(address: string): void {
        const w = root.byAddress(address);
        const pid = w ? (w.pid ?? 0) : 0;
        root.forget(address);
        settleTimer.restart();
        if (!(pid > 0)) {
            Hypr.closeWindow(address);
            return;
        }
        // One detached script per window: closeDesktopFor() calls this in a
        // loop, and a single shared Process only ever ran the LAST command —
        // every earlier window was forgotten but never signalled.
        Quickshell.execDetached(["bash", "-c",
            // Only a process that is still alive AND still ours gets a signal:
            // a pid recycled by the kernel between the poll and now must not
            // be able to make this shell kill an innocent bystander.
            `if ! kill -0 ${pid} 2>/dev/null; then exit 0; fi; ` +
            `if [ "$(ps -o uid= -p ${pid} 2>/dev/null | tr -d ' ')" != "$(id -u)" ]; then exit 0; fi; ` +
            `pkill -TERM -P ${pid} 2>/dev/null; sleep 1.2; ` +
            `if kill -0 ${pid} 2>/dev/null; then kill -TERM ${pid} 2>/dev/null; sleep 0.8; ` +
            `if kill -0 ${pid} 2>/dev/null; then pkill -KILL -P ${pid} 2>/dev/null; kill -KILL ${pid} 2>/dev/null; fi; fi`]);
    }

    function toggleFloat(address: string): void {
        if (!address)
            return;
        Hypr.toggleFloat(address);
        settleTimer.restart();
    }

    // Said once per session, not once per drag: a hint that repeats is noise.
    property bool floatHintShown: false

    function hintFloat(): void {
        if (root.floatHintShown)
            return;
        root.floatHintShown = true;
        Toast.show("FLOATED SO IT CAN BE MOVED  ·  F PUTS IT BACK", "info", 3200);
    }

    function setFloating(address: string): void {
        const w = root.byAddress(address);
        if (!w || w.floating)
            return;
        Hypr.setFloating(address);
        root.patch(address, {
            floating: true
        });
        settleTimer.restart();
    }

    // For the moment a drag starts: same float, but straight down the
    // socket so it lands before the first slide (the queued version can
    // trail the slides by a hundred milliseconds, and every slide that
    // arrives first is silently dropped by Hyprland).
    function floatFast(address: string): void {
        if (!address)
            return;
        Hypr.setFloatingFast(address);
        root.patch(address, {
            floating: true
        });
        settleTimer.restart();
    }

    function sendToWorkspace(address: string, ws: int): void {
        if (!address || !(ws > 0))
            return;
        Hypr.sendToWorkspace(address, ws);
        root.patch(address, {
            ws: ws
        });
        settleTimer.restart();
    }

    // Pull a window onto the workspace you are looking at, in the middle.
    function bringHere(address: string): void {
        const w = root.byAddress(address);
        if (!w)
            return;
        const here = root.homeCell;
        if (!here)
            return;
        if (w.ws !== here.ws)
            root.sendToWorkspace(address, here.ws);
        root.setFloating(address);
        root.placeAt(address, Math.round(here.monX + (here.w - w.w) / 2), Math.round(here.monY + (here.h - w.h) / 2));
        Hypr.focusWindow(address);
        settleTimer.restart();
    }

    // ───────────────────────────────────────────────────────────── moving one
    //  Absolute, never relative: a drag that accumulates deltas drifts, and a
    //  dropped frame becomes a permanent offset. `exact` cannot drift.
    function placeAt(address: string, x: int, y: int): void {
        if (!address)
            return;
        Hypr.moveExact(address, Math.round(x), Math.round(y));
    }

    // The same move at drag speed: straight down the socket, sixty times a
    // second. Deliberately does NOT update the local copy — the card being
    // dragged draws from the pointer, not from here, and rewriting the window
    // list every frame would rebuild the whole map underneath the drag.
    function slideTo(address: string, x: int, y: int): void {
        if (!address)
            return;
        Hypr.slide(address, Math.round(x), Math.round(y));
    }

    function resizeTo(address: string, w: int, h: int): void {
        if (!address || !(w > 0) || !(h > 0))
            return;
        Hypr.resizeExact(address, Math.round(w), Math.round(h));
        settleTimer.restart();
    }

    // ─────────────────────────────────────────────────────── local bookkeeping
    //  Optimistic edits so the map answers instantly. The next poll is the
    //  truth and quietly overwrites all of it.
    function patch(address: string, fields: var): void {
        root.windows = root.windows.map(w => w.address === address ? Object.assign({}, w, fields) : w);
    }

    function forget(address: string): void {
        root.windows = root.windows.filter(w => w.address !== address);
    }

    // ═════════════════════════════════════════════════════════════════ polling
    //  Somebody is looking. `Panels.windowMap` only covers the map you opened
    //  on purpose — reaching for the top edge opens it without touching that
    //  flag, and a map that polls only when pinned shows you a photograph of
    //  your desktop from whenever you last pinned it.
    //
    //  A HEARTBEAT rather than a count: anything that wants fresh data calls
    //  watch() every second or so while it is open, and interest lapses on its
    //  own a couple of seconds after the calls stop. A counter would have been
    //  simpler and would have leaked the first time a monitor was unplugged
    //  while the map was up — nothing decrements on destruction, and this
    //  shell's window types are not Items, so they have no onDestruction.
    property bool eager: false

    function watch(): void {
        root.eager = true;
        calm.restart();
        root.refresh();
    }

    Timer {
        id: calm

        interval: 2400
        onTriggered: root.eager = false
    }

    function refresh(): void {
        if (poller.running)
            return;
        // A poll is STARTING. Consumers that need data from after some
        // moment record this counter at that moment and compare: only a
        // poll started afterwards can see the world they changed.
        root.pollStarted = root.pollStarted + 1;
        poller.running = true;
    }

    Timer {
        id: settleTimer

        interval: 220
        onTriggered: root.refresh()
    }

    // One process for all four queries, so they describe the same instant.
    // A failed hyprctl leaves `null` rather than nothing at all, which keeps
    // the JSON parseable and turns an outage into a counter instead of an
    // exception.
    readonly property string query: "c=$(hyprctl -j clients 2>/dev/null); m=$(hyprctl -j monitors 2>/dev/null); w=$(hyprctl -j workspaces 2>/dev/null); a=$(hyprctl -j activewindow 2>/dev/null); printf '{\"c\":%s,\"m\":%s,\"w\":%s,\"a\":%s}' \"${c:-null}\" \"${m:-null}\" \"${w:-null}\" \"${a:-null}\""

    Process {
        id: poller

        command: ["bash", "-c", root.query]

        stdout: StdioCollector {
            onStreamFinished: root.ingest(text)
        }
    }

    function ingest(raw: string): void {
        let data;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            root.pollFailures = root.pollFailures + 1;
            return;
        }
        if (!data || !Array.isArray(data.m)) {
            root.pollFailures = root.pollFailures + 1;
            return;
        }
        root.pollFailures = 0;

        // ── monitors, in logical pixels and in reading order
        const mons = [];
        for (let i = 0; i < data.m.length; i++) {
            const m = data.m[i];
            if (!m || !m.name)
                continue;
            // Test the value itself, not a defaulted copy of it: writing
            // `(m.scale ?? 1) > 0 ? m.scale : 1` passes the guard on an absent
            // scale and then divides by `undefined`, and a NaN monitor size
            // makes every cell, the world bounds and the zoom NaN — a blank
            // plate with no error printed anywhere.
            const scale = m.scale > 0 ? m.scale : 1;
            // A 90° or 270° transform swaps what width and height mean.
            const turned = (m.transform ?? 0) % 2 === 1;
            const pw = Math.round((m.width > 0 ? m.width : 1920) / scale);
            const ph = Math.round((m.height > 0 ? m.height : 1080) / scale);
            // What the bar (and anything else exclusive) keeps for itself:
            // [left, top, right, bottom] — a pan centres on what is left.
            const res = Array.isArray(m.reserved) ? m.reserved : [0, 0, 0, 0];
            mons.push({
                name: m.name,
                id: m.id ?? i,
                x: m.x ?? 0,
                y: m.y ?? 0,
                w: turned ? ph : pw,
                h: turned ? pw : ph,
                resL: Number(res[0]) || 0,
                resT: Number(res[1]) || 0,
                resR: Number(res[2]) || 0,
                resB: Number(res[3]) || 0,
                focused: m.focused === true,
                activeWs: m.activeWorkspace?.id ?? 1
            });
        }
        mons.sort((a, b) => a.y === b.y ? a.x - b.x : a.y - b.y);

        // ── which monitor each workspace lives on
        const wm = ({});
        if (Array.isArray(data.w))
            for (let i = 0; i < data.w.length; i++) {
                const w = data.w[i];
                if (w && (w.id ?? 0) > 0)
                    wm[w.id] = w.monitor ?? "";
            }

        // ── the windows
        const byId = ({});
        for (let i = 0; i < mons.length; i++)
            byId[mons[i].id] = mons[i].name;

        const out = [];
        if (Array.isArray(data.c))
            for (let i = 0; i < data.c.length; i++) {
                const c = data.c[i];
                if (!c || !c.address || c.hidden === true || c.mapped === false)
                    continue;
                const ws = c.workspace?.id ?? -999;
                // Special workspaces are not part of the desktop you can see.
                if (!(ws > 0))
                    continue;
                if (!Array.isArray(c.at) || !Array.isArray(c.size))
                    continue;
                if (!(c.size[0] > 0) || !(c.size[1] > 0))
                    continue;
                out.push({
                    address: c.address,
                    pid: c.pid ?? 0,
                    x: c.at[0],
                    y: c.at[1],
                    w: c.size[0],
                    h: c.size[1],
                    title: c.title ?? "",
                    cls: c.class ?? "",
                    floating: c.floating === true,
                    pinned: c.pinned === true,
                    ws: ws,
                    wsName: c.workspace?.name ?? `${ws}`,
                    monName: byId[c.monitor] ?? (mons.length > 0 ? mons[0].name : "")
                });
            }

        root.monitors = mons;
        root.wsMon = wm;
        root.windows = out;
        root.activeAddress = data.a?.address ?? "";
        // How many times this has answered. Anything that acts on a window and
        // then wants to measure the result can wait for this to move rather
        // than guessing how long hyprctl takes.
        root.polls = root.polls + 1;
    }

    // Brisk while something is looking, slow otherwise — but never off. The
    // monitor list is what the desktop designer measures against and what the
    // scene turns fractions into pixels with, so "we have not polled yet" is
    // the difference between a window placed correctly and one placed nowhere.
    Timer {
        readonly property bool watched: root.eager || Panels.windowMap

        running: true
        interval: watched ? 500 : 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (!root.eager && !Panels.windowMap)
                return;
            const n = event.name;
            if (n === "openwindow" || n === "closewindow" || n === "movewindow" || n === "workspace" || n === "activewindowv2" || n === "changefloatingmode" || n === "monitoradded" || n === "monitorremoved")
                settleTimer.restart();
        }
    }

    // ══════════════════════════════════════════════════════════════════ ipc
    //   qs -c velvet ipc call desk map
    IpcHandler {
        target: "desk"

        function map(): void {
            Panels.toggleWindowMap();
        }
        function refresh(): void {
            root.refresh();
        }
        function dialect(): string {
            return Hypr.dialectName;
        }
        //   qs -c velvet ipc call desk pan 0x55…
        //  The infinite-canvas jump from outside: same as a card click in the
        //  map, same as Super+H / Super+K.
        function pan(address: string): void {
            root.panTo(address);
        }
        //   qs -c velvet ipc call desk ffloat 0x55…
        //  Exercises the exact floatFast path the map's drag-start uses —
        //  useful for verifying dispatches on a scratch window.
        function ffloat(address: string): void {
            root.floatFast(address);
        }
        function mslide(address: string, x: string, y: string): void {
            root.slideTo(address, parseInt(x, 10), parseInt(y, 10));
        }
        function state(): string {
            return JSON.stringify(root.windows.map(w => ({ a: w.address.slice(-6), x: w.x, y: w.y, f: w.floating, ws: w.ws })));
        }
    }

    GlobalShortcut {
        name: "windowMap"
        description: "Open the Velvet window map"
        onPressed: Panels.toggleWindowMap()
    }
}
