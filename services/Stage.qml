//  VELVET  ·  services/Stage.qml
//  STAGE desktops (SUPER+TAB → DESKTOP → WINDOWS: STAGE): one window stands
//  in the middle of the screen — on stage — and every other window of that
//  desktop waits in the wings, as a tilted card in a strip at the screen's
//  edge (modules/stage/StageStrip.qml). Click a card: that window steps on
//  stage, the one that was there joins the wings. A new window takes the
//  stage; close the one on stage and the last one before it comes back.
//  CTRL+SUPER+↑/↓ walks the wings.
//
//  The wings are a hidden special workspace (scripts/stage.py moves the
//  windows). Who waits for which desktop is kept in the runtime folder, so a
//  restarted shell still knows — and a window found waiting that nobody
//  remembers is brought back to the desktop you are on, never lost.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    readonly property string script: `${Qt.resolvedUrl("../scripts/stage.py")}`.replace(/^file:\/\//, "")
    readonly property string bookPath: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/velvet-stage.json`
    readonly property int share: Math.max(40, Math.min(94, Config.stage.size))

    // "<desktop>": the address on stage · "<desktop>": [addresses in the wings, the latest first]
    property var onStage: ({})
    property var wings: ({})
    property bool loaded: false

    function isStage(ws: int): bool {
        return WorkspaceModes.modeOf(ws) === "stage";
    }

    function wingsOf(ws: int): var {
        return root.wings[String(ws)] ?? [];
    }

    function run(args: var): void {
        Quickshell.execDetached(["python3", root.script].concat(args));
    }

    function store(stageMap: var, wingMap: var): void {
        root.onStage = stageMap;
        root.wings = wingMap;
        book.setText(JSON.stringify({
            stage: stageMap,
            wings: wingMap
        }));
    }

    function without(list: var, addr: string): var {
        return (list ?? []).filter(a => a !== addr);
    }

    // a window comes onto a stage desktop (new, or carried there): it takes
    // the stage, the one there before joins the wings
    function arrive(addr: string, ws: int): void {
        const k = String(ws);
        const before = root.onStage[k] ?? "";
        const st = Object.assign({}, root.onStage, {
            [k]: addr
        });
        const wg = Object.assign({}, root.wings);
        let list = root.without(wg[k], addr);
        if (before && before !== addr && Hypr.windowList(ws).some(w => w.address === before)) {
            list = [before].concat(root.without(list, before));
            root.run(["park", before]);
        }
        wg[k] = list;
        root.store(st, wg);
        root.run(["place", addr, String(root.share)]);
    }

    // a card was clicked: that window steps on stage
    function pick(addr: string, ws: int): void {
        const k = String(ws);
        const before = root.onStage[k] ?? "";
        if (before === addr)
            return;
        const wg = Object.assign({}, root.wings);
        let list = root.without(wg[k], addr);
        if (before)
            list = [before].concat(root.without(list, before));
        wg[k] = list;
        root.store(Object.assign({}, root.onStage, {
            [k]: addr
        }), wg);
        root.run(["swap", String(ws), addr, before || "-", String(root.share)]);
    }

    // CTRL+SUPER+↑/↓ on a stage desktop: the next card in (or back out)
    function step(dir: int): void {
        const ws = Hyprland.focusedWorkspace?.id ?? 0;
        const list = root.wingsOf(ws);
        if (!root.isStage(ws) || list.length === 0)
            return;
        // down brings the latest card in; up brings the oldest one
        root.pick(dir > 0 ? list[0] : list[list.length - 1], ws);
    }

    // the window on stage closed: the last one before it comes back
    function closed(addr: string): void {
        const st = Object.assign({}, root.onStage);
        const wg = Object.assign({}, root.wings);
        let changed = false;
        let back = null;
        for (const k in st) {
            if (st[k] !== addr)
                continue;
            delete st[k];
            changed = true;
            const list = wg[k] ?? [];
            if (list.length > 0 && root.isStage(Number(k)))
                back = [k, list[0]];
        }
        for (const k in wg) {
            if ((wg[k] ?? []).indexOf(addr) >= 0) {
                wg[k] = root.without(wg[k], addr);
                changed = true;
            }
        }
        if (!changed)
            return;
        root.store(st, wg);
        if (back)
            root.pick(back[1], Number(back[0]));
    }

    // a desktop becomes a stage: the focused window stays, the rest wait
    function enter(ws: int): void {
        const wins = Hypr.windowList(ws).filter(w => !WorkspaceModes.fixedClass(w.appId));
        if (wins.length === 0)
            return;
        const act = Hyprland.activeToplevel?.lastIpcObject?.address ?? "";
        const star = wins.some(w => w.address === act) ? act : wins[wins.length - 1].address;
        const rest = wins.map(w => w.address).filter(a => a !== star);
        const k = String(ws);
        root.store(Object.assign({}, root.onStage, {
            [k]: star
        }), Object.assign({}, root.wings, {
            [k]: rest.concat(root.without(root.wings[k], star).filter(a => rest.indexOf(a) < 0))
        }));
        if (rest.length > 0)
            root.run(["park"].concat(rest));
        root.run(["place", star, String(root.share)]);
    }

    // …and stops being one: everybody comes back out
    function leave(ws: int): void {
        const k = String(ws);
        const list = root.wings[k] ?? [];
        const st = Object.assign({}, root.onStage);
        const wg = Object.assign({}, root.wings);
        delete st[k];
        delete wg[k];
        root.store(st, wg);
        if (list.length > 0)
            root.run(["unpark", k].concat(list));
    }

    // the modes changed (here, a look, the file): enter or leave
    property var wasStage: ({})

    function followModes(): void {
        if (!root.loaded)
            return;
        const now = {};
        for (const k in WorkspaceModes.modes)
            if (WorkspaceModes.modes[k] === "stage")
                now[k] = true;
        for (const k in now)
            if (!root.wasStage[k])
                root.enter(Number(k));
        for (const k in root.wasStage)
            if (!now[k])
                root.leave(Number(k));
        root.wasStage = now;
    }

    Connections {
        target: WorkspaceModes

        function onModesChanged(): void {
            root.followModes();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n === "closewindow") {
                root.closed(`0x${String(event.data ?? "").split(",")[0]}`);
            } else if (n === "movewindowv2") {
                // carried to another desktop by hand: it leaves this one's book
                const parts = String(event.data ?? "").split(",");
                const addr = `0x${parts[0]}`;
                const to = parts[2] ?? "";
                if (to.startsWith("special:vstage"))
                    return;
                const st = Object.assign({}, root.onStage);
                const wg = Object.assign({}, root.wings);
                let changed = false;
                for (const k in st)
                    if (st[k] === addr && k !== String(parts[1] ?? "")) {
                        delete st[k];
                        changed = true;
                    }
                for (const k in wg)
                    if ((wg[k] ?? []).indexOf(addr) >= 0 && k !== String(parts[1] ?? "")) {
                        wg[k] = root.without(wg[k], addr);
                        changed = true;
                    }
                if (changed)
                    root.store(st, wg);
            }
        }
    }

    FileView {
        id: book

        path: root.bookPath
        printErrors: false
        blockLoading: true

        onLoaded: {
            try {
                const d = JSON.parse(book.text());
                root.onStage = d.stage ?? ({});
                root.wings = d.wings ?? ({});
            } catch (e) {}
            rescue.restart();
        }
        onLoadFailed: rescue.restart()
    }

    // Start: windows waiting in the wings that no stage remembers come back
    // to the desktop you are on — then the modes are followed from here on.
    Timer {
        id: rescue

        interval: 1800
        onTriggered: {
            const known = {};
            for (const k in root.wings)
                for (const a of root.wings[k])
                    known[a] = true;
            const lost = [];
            const tops = Hyprland.toplevels?.values ?? [];
            for (let i = 0; i < tops.length; i++) {
                const raw = tops[i].lastIpcObject;
                if (raw && `${raw.workspace?.name ?? ""}`.startsWith("special:vstage") && !known[raw.address])
                    lost.push(raw.address);
            }
            const ws = Hyprland.focusedWorkspace?.id ?? 1;
            if (lost.length > 0)
                root.run(["unpark", String(ws)].concat(lost));
            for (const k in WorkspaceModes.modes)
                if (WorkspaceModes.modes[k] === "stage")
                    root.wasStage[k] = true;
            root.loaded = true;
        }
    }

    // qs -c velvet ipc call stage pick <address> · step 1|-1 · list
    IpcHandler {
        target: "stage"

        function pick(addr: string): void {
            root.pick(addr, Hyprland.focusedWorkspace?.id ?? 0);
        }
        function step(dir: int): void {
            root.step(dir);
        }
        function list(): string {
            return JSON.stringify({
                stage: root.onStage,
                wings: root.wings
            });
        }
    }
}
