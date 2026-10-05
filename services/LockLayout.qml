//  VELVET  ·  services/LockLayout.qml
//  Which lock modules show, and where — the fluid lock's tiling: three columns
//  inside the card (left, centre, right) plus the two bottom pills beside
//  the password island. You decide which module goes on which tile, and in
//  which order. Arrange it in Super+Tab → LOCK SCREEN → ARRANGE MODULES.
//
//  layout.tiles.left / center / right     [ids…]  — the card's three columns
//  layout.islandLeft / islandRight        [ids…]  — the bottom pills
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string path: `${Quickshell.env("HOME")}/.config/velvet/locklayout.json`

    // The tile a module lands on when toggled from the tray — the column it
    // reads best in. The centre is the fluid lock's fixed stage (clock, profile,
    // password), so everything parks in a side column.
    function defaultZone(id: string): string {
        switch (id) {
        case "clock":
        case "avatar":
        case "greeting":
        case "weather":
        case "media":
        case "notifs":
        case "session":
            return "left";
        }
        return "right";
    }

    property var layout: root.defaults()

    function defaults(): var {
        return {
            tiles: {
                // The fluid lock's own column content, nothing more: weather,
                // fetch, media on the left; resources and the
                // notification dock on the right.
                left: ["weather", "session", "media"],
                center: [],
                right: ["resources", "notifs"]
            },
            islandLeft: [],
            islandRight: []
        };
    }

    function list(zone: string): var {
        if (zone === "left" || zone === "center" || zone === "right")
            return Array.isArray(root.layout.tiles[zone]) ? root.layout.tiles[zone] : [];
        const l = root.layout[zone];
        return Array.isArray(l) ? l : [];
    }

    function has(id: string): bool {
        return root.get(id) !== null;
    }

    // Every placed module returns { id, zone } — the tile or pill it sits in.
    function get(id: string): var {
        for (const zone of ["left", "center", "right", "islandLeft", "islandRight"]) {
            if (root.list(zone).indexOf(id) !== -1)
                return {
                    id: id,
                    zone: zone
                };
        }
        return null;
    }

    function zoneOf(id: string): string {
        const it = root.get(id);
        return it ? (it.zone ?? "center") : "";
    }

    // Park a module in one of the three card tiles. Cheap and frequent —
    // commit() writes the file once the drag ends.
    function placeTile(id: string, zone: string, index: int): void {
        if (zone !== "left" && zone !== "center" && zone !== "right")
            return;
        const next = root.stripped();
        // A moved module must leave its old zone first — placing is a move,
        // never a duplicate.
        root.removeId(id, next);
        const list = next.tiles[zone];
        const at = Number.isFinite(index) ? Math.max(0, Math.min(list.length, index)) : list.length;
        list.splice(at, 0, id);
        root.layout = next;
    }

    // Park a module in one of the two island pills.
    function placeIsland(id: string, zone: string, index: int): void {
        if (zone !== "islandLeft" && zone !== "islandRight")
            return;
        const next = root.stripped();
        root.removeId(id, next);
        const list = next[zone];
        const at = Number.isFinite(index) ? Math.max(0, Math.min(list.length, index)) : list.length;
        list.splice(at, 0, id);
        root.layout = next;
    }

    // The same shape of copy every placement makes: the current layout,
    // with the module gone from wherever it was.
    function stripped(): var {
        const next = {
            tiles: {
                left: root.list("left").slice(),
                center: root.list("center").slice(),
                right: root.list("right").slice()
            },
            islandLeft: root.list("islandLeft").slice(),
            islandRight: root.list("islandRight").slice()
        };
        return next;
    }

    function removeId(id: string, next: var): void {
        next.tiles.left = next.tiles.left.filter(m => m !== id);
        next.tiles.center = next.tiles.center.filter(m => m !== id);
        next.tiles.right = next.tiles.right.filter(m => m !== id);
        next.islandLeft = next.islandLeft.filter(m => m !== id);
        next.islandRight = next.islandRight.filter(m => m !== id);
    }

    function place(id: string, zone: string, index: int): void {
        if (zone === "islandLeft" || zone === "islandRight") {
            root.placeIsland(id, zone, index);
            return;
        }
        root.placeTile(id, zone, index);
    }

    // Fine control for a card-tile module: up/down steps one position,
    // left/right moves it to the neighbouring column. Saves immediately.
    function nudge(id: string, dirX: int, dirY: int): void {
        const it = root.get(id);
        if (!it || it.zone === "islandLeft" || it.zone === "islandRight")
            return;
        // Only the two columns the lock actually draws.
        const zones = ["left", "right"];
        let zi = Math.max(0, zones.indexOf(it.zone));
        if (dirX !== 0) {
            zi = Math.max(0, Math.min(1, zi + dirX));
        } else if (dirY !== 0) {
            const list = root.list(it.zone);
            const at = list.indexOf(id);
            const to = Math.max(0, Math.min(list.length - 1, at - dirY));
            if (to === at)
                return;
            const next = root.stripped();
            root.removeId(id, next);
            next.tiles[it.zone].splice(to, 0, id);
            root.layout = next;
            root.commit();
            Sfx.cursor();
            return;
        }
        if (zones[zi] === it.zone) {
            Sfx.cursor();
            return;
        }
        const next = root.stripped();
        root.removeId(id, next);
        next.tiles[zones[zi]].push(id);
        root.layout = next;
        root.commit();
        Sfx.cursor();
    }

    function remove(id: string): void {
        const next = root.stripped();
        root.removeId(id, next);
        root.layout = next;
        root.commit();
    }

    // From a catalogue chip: add to its natural tile, or drop it again.
    function toggle(id: string): void {
        if (root.has(id)) {
            root.remove(id);
            Sfx.back();
        } else {
            root.placeTile(id, root.defaultZone(id));
            root.commit();
        }
    }

    function commit(): void {
        root.persist();
        Sfx.select();
    }

    function persist(): void {
        file.setText(JSON.stringify(root.layout, null, 1));
    }

    // ═══════════════════════════════════════════════════════════ migrations
    // The free-point format (x, y in the card) lands in the columns by
    // where each module was dragged: left third → left, right third →
    // right, middle → centre, each column ordered top to bottom. The
    // islands stay. A module must never show up twice.
    // The centre is the fluid lock's fixed stage now (clock, profile, password)
    // and the bottom pills are gone: modules that lived in either move to
    // the left column — except the clock and the avatar, which the centre
    // itself now provides. A module never shows up twice.
    function normalize(out: var): var {
        const center = out.tiles.center.filter(m => m !== "clock" && m !== "avatar" && out.tiles.left.indexOf(m) === -1);
        const island = out.islandLeft.concat(out.islandRight).filter(m => out.tiles.left.indexOf(m) === -1 && center.indexOf(m) === -1);
        out.tiles.left = center.concat(out.tiles.left, island);
        out.tiles.center = [];
        out.islandLeft = [];
        out.islandRight = [];
        return out;
    }

    function tilesFromPoints(pts: var, left: var, right: var): var {
        const out = root.stripped();
        out.islandLeft = (Array.isArray(left) ? left : root.defaults().islandLeft).filter(m => LockModules.find(m));
        out.islandRight = (Array.isArray(right) ? right : root.defaults().islandRight).filter(m => LockModules.find(m));
        const buckets = { left: [], center: [], right: [] };
        for (let i = 0; i < pts.length; i++) {
            const p = pts[i];
            if (!p || typeof p.id !== "string" || !LockModules.find(p.id))
                continue;
            if (out.islandLeft.indexOf(p.id) !== -1 || out.islandRight.indexOf(p.id) !== -1)
                continue;
            const x = Number.isFinite(p.x) ? p.x : 0.5;
            const y = Number.isFinite(p.y) ? p.y : 0.5;
            buckets[x < 0.4 ? "left" : (x > 0.6 ? "right" : "center")].push({
                id: p.id,
                y: y
            });
        }
        for (const z of ["left", "center", "right"]) {
            buckets[z].sort((a, b) => a.y - b.y);
            out.tiles[z] = buckets[z].map(m => m.id);
        }
        if (out.tiles.left.length + out.tiles.center.length + out.tiles.right.length === 0)
            out.tiles = root.defaults().tiles;
        return root.normalize(out);
    }

    function sanitize(parsed: var): var {
        const out = root.stripped();
        // Current format: tiles + islands.
        if (parsed.tiles && typeof parsed.tiles === "object") {
            for (const z of ["left", "center", "right"]) {
                const l = parsed.tiles[z];
                if (Array.isArray(l))
                    out.tiles[z] = l.filter(m => typeof m === "string" && LockModules.find(m));
            }
        }
        for (const z of ["islandLeft", "islandRight"]) {
            if (Array.isArray(parsed[z]))
                out[z] = parsed[z].filter(m => typeof m === "string" && LockModules.find(m));
        }
        // Old free-point format: card entries fall into the columns.
        if (Array.isArray(parsed.card))
            return root.tilesFromPoints(parsed.card, out.islandLeft, out.islandRight);
        return root.normalize(out);
    }

    // The even older formats — a free array, or the left/center/right slots.
    function fromFreeArray(arr: var): var {
        return root.tilesFromPoints(arr, [], []);
    }

    function fromSlots(old: var): var {
        const out = root.stripped();
        const order = { left: [], center: [], right: [] };
        for (const z of ["left", "center", "right"]) {
            const l = Array.isArray(old[z]) ? old[z] : [];
            for (let i = 0; i < l.length; i++)
                if (LockModules.find(l[i]))
                    order[z].push(l[i]);
        }
        out.tiles.left = order.left.length > 0 ? order.left : root.defaults().tiles.left;
        out.tiles.center = order.center.length > 0 ? order.center : root.defaults().tiles.center;
        out.tiles.right = order.right.length > 0 ? order.right : root.defaults().tiles.right;
        out.islandLeft = Array.isArray(old.islandLeft) ? old.islandLeft.filter(m => LockModules.find(m)) : root.defaults().islandLeft;
        out.islandRight = Array.isArray(old.islandRight) ? old.islandRight.filter(m => LockModules.find(m)) : root.defaults().islandRight;
        return root.normalize(out);
    }

    FileView {
        id: file

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (Array.isArray(parsed)) {
                    root.layout = root.fromFreeArray(parsed);
                } else if (parsed && typeof parsed === "object") {
                    if (parsed.tiles || parsed.card || parsed.islandLeft || parsed.islandRight)
                        root.layout = root.sanitize(parsed);
                    else if (parsed.left || parsed.center || parsed.right)
                        root.layout = root.fromSlots(parsed);
                }
            } catch (e) {
                // A hand-edited locklayout.json must never stop the shell —
                // the defaults carry the lock.
            }
        }

        onLoadFailed: {
            // No file yet: the defaults already apply.
        }
    }
}
