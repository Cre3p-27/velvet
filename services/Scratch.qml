//  VELVET  ·  services/Scratch.qml
//  The SCRATCHPAD: an endless sheet to keep things on — ink, text, sticky
//  notes, lines and arrows, pasted pictures — on pages of its own. It lives
//  in the Dynamic Island (MODULES → DYNAMIC ISLAND → SCRATCHPAD), opens with
//  SUPER+O or from the island at the screen's edge, and remembers everything
//  in ~/.config/velvet/scratch.json (pictures beside it, in scratch/).
//
//  The board (modules/scratch/ScratchBoard.qml) draws and edits; this keeps
//  the pages, the view of each page, the undo history and the file.
//
//  An item is one of
//    { id, kind: "ink",   pts: [x, y, x, y …], w, c, a }     pen and marker
//    { id, kind: "shape", type: line|arrow|rect|ellipse, x1, y1, x2, y2, w, c }
//    { id, kind: "text",  x, y, text, size, c }
//    { id, kind: "note",  x, y, w, h, text, c, tilt }
//    { id, kind: "image", x, y, w, h, src }
//  in the page's own (endless) coordinates.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.config/velvet`
    readonly property string path: `${root.dir}/scratch.json`
    readonly property string picDir: `${root.dir}/scratch`

    // ── the pages
    property var pages: [root.blankPage("NOTES")]
    property int page: 0
    property bool loaded: false
    readonly property var current: root.pages[Math.max(0, Math.min(root.pages.length - 1, root.page))] ?? root.blankPage("NOTES")
    readonly property var items: root.current.items ?? []
    // every change bumps it, so whatever draws the page can follow
    property int revision: 0

    // the island shows the pad (it says so while the module is open)
    property bool shown: false
    // asked for from outside (SUPER+O, the IPC): the island opens on it
    property bool wantIsland: false

    function blankPage(name: string): var {
        return {
            name: name,
            items: [],
            view: {
                x: 0,
                y: 0,
                z: 1
            }
        };
    }

    property int nextId: 1

    function newId(): int {
        return root.nextId++;
    }

    // ── SUPER+O: open the pad in the island on the screen you are on, or put
    // it away again
    function toggle(): void {
        if (root.shown && Panels.islandScreen !== "") {
            Panels.islandScreen = "";
            Sfx.close();
            return;
        }
        root.open();
    }

    function open(): void {
        if (Locker.locked)
            return;
        if (!Config.map.island || !Config.map.islandScratch) {
            Toast.show("THE SCRATCHPAD LIVES IN THE DYNAMIC ISLAND — SWITCH IT ON UNDER MODULES → DYNAMIC ISLAND", "warn", 4600);
            return;
        }
        root.wantIsland = true;
        const scr = Hypr.focusedScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
        if (scr)
            Panels.islandScreen = scr.name;
        // the island may already be up on that screen: say it once more
        root.wantIslandChanged();
    }

    function close(): void {
        if (root.shown)
            Panels.islandScreen = "";
    }

    // ── changing the page: every change is one undo step
    property var undoStack: []
    property var redoStack: []

    function commit(nextItems: var, keepRedo: bool): void {
        const ps = root.pages.slice();
        const p = Object.assign({}, root.current);
        const u = root.undoStack.slice();
        u.push({
            page: root.page,
            items: p.items
        });
        while (u.length > 80)
            u.shift();
        root.undoStack = u;
        if (!keepRedo)
            root.redoStack = [];
        p.items = nextItems;
        ps[root.page] = p;
        root.pages = ps;
        root.revision++;
        root.saveSoon();
    }

    function add(item: var): var {
        const it = Object.assign({
            id: root.newId()
        }, item);
        root.commit(root.items.concat([it]), false);
        return it;
    }

    // `v` counts an item's changes: the board keeps an item's drawing
    // until its id or its v says it changed
    function update(id: int, patch: var): void {
        const next = root.items.map(it => it.id === id ? Object.assign({}, it, patch, {
                    v: (it.v ?? 0) + 1
                }) : it);
        root.commit(next, false);
    }

    // several items at once, one undo step: { id: patch, … }
    function updateMany(patches: var): void {
        const next = root.items.map(it => patches[it.id] ? Object.assign({}, it, patches[it.id], {
                    v: (it.v ?? 0) + 1
                }) : it);
        root.commit(next, false);
    }

    // a move or a resize while the hand holds it: no undo step per frame —
    // the step is taken when the hand lets go (`commit` of the start state)
    function updateQuiet(id: int, patch: var): void {
        const ps = root.pages.slice();
        const p = Object.assign({}, root.current);
        p.items = root.items.map(it => it.id === id ? Object.assign({}, it, patch, {
                    v: (it.v ?? 0) + 1
                }) : it);
        ps[root.page] = p;
        root.pages = ps;
        root.revision++;
    }

    function remove(ids: var): void {
        const set = {};
        for (const i of ids)
            set[i] = true;
        root.commit(root.items.filter(it => !set[it.id]), false);
    }

    function clearPage(): void {
        if (root.items.length === 0)
            return;
        root.commit([], false);
        Toast.show("PAGE CLEARED · CTRL+Z BRINGS IT BACK", "info", 3200);
    }

    function undo(): bool {
        if (root.undoStack.length === 0)
            return false;
        const u = root.undoStack.slice();
        const step = u.pop();
        root.undoStack = u;
        const r = root.redoStack.slice();
        const ps = root.pages.slice();
        if (step.page >= ps.length)
            return false;
        r.push({
            page: step.page,
            items: ps[step.page].items
        });
        root.redoStack = r;
        const p = Object.assign({}, ps[step.page]);
        p.items = step.items;
        ps[step.page] = p;
        root.pages = ps;
        root.page = step.page;
        root.revision++;
        root.saveSoon();
        return true;
    }

    function redo(): bool {
        if (root.redoStack.length === 0)
            return false;
        const r = root.redoStack.slice();
        const step = r.pop();
        root.redoStack = r;
        const u = root.undoStack.slice();
        const ps = root.pages.slice();
        if (step.page >= ps.length)
            return false;
        u.push({
            page: step.page,
            items: ps[step.page].items
        });
        root.undoStack = u;
        const p = Object.assign({}, ps[step.page]);
        p.items = step.items;
        ps[step.page] = p;
        root.pages = ps;
        root.page = step.page;
        root.revision++;
        root.saveSoon();
        return true;
    }

    // ── the view of a page (where you looked, how close): kept with it
    function setView(x: real, y: real, z: real): void {
        const ps = root.pages.slice();
        const p = Object.assign({}, root.current);
        p.view = {
            x: Math.round(x * 10) / 10,
            y: Math.round(y * 10) / 10,
            z: Math.round(z * 1000) / 1000
        };
        ps[root.page] = p;
        root.pages = ps;
        root.saveSoon();
    }

    // ── pages
    function addPage(): void {
        const ps = root.pages.slice();
        ps.push(root.blankPage(`PAGE ${ps.length + 1}`));
        root.pages = ps;
        root.page = ps.length - 1;
        root.revision++;
        root.saveSoon();
    }

    function goPage(i: int): void {
        if (i < 0 || i >= root.pages.length || i === root.page)
            return;
        root.page = i;
        root.revision++;
        root.saveSoon();
    }

    function renamePage(name: string): void {
        const n = `${name ?? ""}`.trim().slice(0, 24);
        if (n === "")
            return;
        const ps = root.pages.slice();
        ps[root.page] = Object.assign({}, root.current, {
            name: n.toUpperCase()
        });
        root.pages = ps;
        root.saveSoon();
    }

    function removePage(): void {
        if (root.pages.length <= 1) {
            root.clearPage();
            return;
        }
        const ps = root.pages.slice();
        ps.splice(root.page, 1);
        root.pages = ps;
        root.page = Math.max(0, root.page - 1);
        root.undoStack = root.undoStack.filter(s => s.page < ps.length);
        root.redoStack = [];
        root.revision++;
        root.saveSoon();
    }

    // ── the file
    function saveSoon(): void {
        writeLater.restart();
    }

    Timer {
        id: writeLater

        interval: 600
        onTriggered: file.setText(JSON.stringify({
                version: 1,
                page: root.page,
                nextId: root.nextId,
                pages: root.pages
            }))
    }

    FileView {
        id: file

        path: root.path
        printErrors: false
        blockLoading: true

        onLoaded: {
            try {
                const d = JSON.parse(file.text());
                const ps = Array.isArray(d.pages) ? d.pages.filter(p => p && Array.isArray(p.items)) : [];
                if (ps.length > 0) {
                    root.pages = ps.map(p => ({
                                name: `${p.name ?? "PAGE"}`,
                                items: p.items,
                                view: p.view ?? {
                                    x: 0,
                                    y: 0,
                                    z: 1
                                }
                            }));
                    root.page = Math.max(0, Math.min(ps.length - 1, d.page ?? 0));
                    let top = d.nextId ?? 1;
                    for (const p of ps)
                        for (const it of p.items)
                            top = Math.max(top, (it.id ?? 0) + 1);
                    root.nextId = top;
                }
            } catch (e) {
                console.warn("Scratch: scratch.json could not be read — starting a fresh pad");
            }
            root.loaded = true;
            root.revision++;
        }
        onLoadFailed: {
            root.loaded = true;
            root.revision++;
        }
    }

    // ── pictures: pasted ones are copied next to the pad, so they stay
    function picturePath(ext: string): string {
        return `${root.picDir}/${Date.now().toString(36)}.${ext}`;
    }

    // ── export: the board renders itself and hands the file name back here
    function exportPath(): string {
        return `${Quickshell.env("HOME")}/Pictures/velvet-scratch-${Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss")}.png`;
    }

    // qs -c velvet ipc call scratch toggle | open | close | clear | page 2 | pages
    IpcHandler {
        target: "scratch"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function clear(): void {
            root.clearPage();
        }
        function page(n: int): void {
            root.goPage(n - 1);
            root.open();
        }
        function pages(): string {
            return root.pages.map((p, i) => `${i + 1}${i === root.page ? "*" : " "} ${p.name} (${p.items.length})`).join("\n");
        }
    }
}
