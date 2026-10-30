//  VELVET  ·  modules/scratch/ScratchBoard.qml
//  The SCRATCHPAD's sheet: endless in every direction, on pages. Ink and a
//  marker, an eraser, text, sticky notes, lines, arrows, boxes and circles,
//  pictures pasted in; select, move, duplicate, delete; undo everything.
//  Wheel pans, Ctrl+wheel zooms at the pointer, a middle or right drag (or
//  the hand tool) moves the sheet. F1 or ? shows every key.
//
//  It sits in the Dynamic Island (modules/island/IslandScratch.qml), which
//  hands it the keyboard: `handleKey` gets every key while nothing is being
//  typed; while a text or a note is being written its own field has the keys,
//  and `doneTyping` gives them back. The page itself lives in
//  services/Scratch.qml.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Shapes

Item {
    id: board

    property bool live: true
    property bool keys: false
    property color ground: Colours.surface

    // a hand on the sheet or a word half written: the island waits
    readonly property bool busy: hand.pressed || board.editId >= 0

    signal poked
    signal doneTyping

    // ── the paper
    readonly property color paperCol: Config.scratch.tone === "paper" ? Qt.rgba(0.965, 0.95, 0.925, 1) : (Config.scratch.tone === "ink" ? Qt.rgba(0.075, 0.072, 0.08, 1) : board.ground)
    readonly property color inkCol: Colours.on(Qt.rgba(board.paperCol.r, board.paperCol.g, board.paperCol.b, 1))
    readonly property color lineCol: Colours.alpha(board.inkCol, 0.13)

    // ── the pens: "ink" and "accent" follow the paper and the look, the rest stay as drawn
    readonly property var swatches: ["ink", "accent", "#ff5a6e", "#ffb02e", "#37d67a", "#3fa7ff", "#b07cff"]
    property int swatch: 0
    readonly property string colourKey: board.swatches[board.swatch]
    readonly property var noteColours: ["#ffe58a", "#ffc2d1", "#b9f0c9", "#bfe3ff", "#e1d2ff", "#ffd8b0"]

    function colourOf(c: string): color {
        if (c === "ink" || c === undefined || c === "")
            return board.inkCol;
        if (c === "accent")
            return Colours.accent;
        return c;
    }

    // ── the tools
    property string tool: "pen"
    property string lastShape: "arrow"
    readonly property var shapeTools: ["line", "arrow", "rect", "ellipse"]
    readonly property bool shapeTool: board.shapeTools.indexOf(board.tool) >= 0
    readonly property var toolInfo: ({
            select: { icon: "arrow_selector_tool", label: "SELECT", hint: "CLICK TO PICK · DRAG TO MOVE · DRAG THE SHEET FOR A FRAME · DEL REMOVES · CTRL+D DOUBLES" },
            hand: { icon: "pan_tool", label: "MOVE", hint: "DRAG THE SHEET · CTRL+WHEEL ZOOMS · CTRL+0 BACK TO 100 %" },
            pen: { icon: "edit", label: "PEN", hint: "DRAW · [ ] THINNER, THICKER · 1–7 COLOURS" },
            marker: { icon: "ink_highlighter", label: "MARKER", hint: "A BROAD SEE-THROUGH STROKE OVER ANYTHING" },
            eraser: { icon: "ink_eraser", label: "ERASER", hint: "SWEEP OVER WHAT SHOULD GO · CTRL+Z BRINGS IT BACK" },
            text: { icon: "text_fields", label: "TEXT", hint: "CLICK AND TYPE · ESC OR A CLICK OUTSIDE ENDS IT" },
            note: { icon: "sticky_note_2", label: "NOTE", hint: "CLICK FOR A STICKY NOTE · DOUBLE-CLICK ONE TO WRITE ON IT" },
            line: { icon: "horizontal_rule", label: "LINE", hint: "DRAG A LINE · SHIFT KEEPS IT STRAIGHT" },
            arrow: { icon: "arrow_right_alt", label: "ARROW", hint: "DRAG AN ARROW · SHIFT KEEPS IT STRAIGHT" },
            rect: { icon: "crop_square", label: "BOX", hint: "DRAG A BOX · SHIFT MAKES IT SQUARE" },
            ellipse: { icon: "circle", label: "CIRCLE", hint: "DRAG A CIRCLE · SHIFT MAKES IT ROUND" }
        })
    property real penSize: Config.scratch.pen

    function useTool(t: string): void {
        if (board.toolInfo[t] === undefined)
            return;
        board.finishEdit();
        if (board.shapeTools.indexOf(t) >= 0)
            board.lastShape = t;
        if (t !== board.tool)
            Sfx.tick(0.6);
        board.tool = t;
        if (t !== "select")
            board.selection = ({});
        board.poked();
    }

    function pickSwatch(i: int): void {
        if (i < 0 || i >= board.swatches.length)
            return;
        board.swatch = i;
        Sfx.pop();
        // a picked colour recolours what is selected
        const ids = board.selectedIds();
        if (ids.length > 0) {
            const patch = {};
            for (const id of ids) {
                const it = board.itemById(id);
                if (it && (it.kind === "ink" || it.kind === "shape" || it.kind === "text"))
                    patch[id] = {
                        c: board.colourKey
                    };
                else if (it && it.kind === "note")
                    patch[id] = {
                        c: board.noteColours[i % board.noteColours.length]
                    };
            }
            Scratch.updateMany(patch);
        }
    }

    function nudgeSize(d: int): void {
        const sizes = [1, 2, 3, 4, 6, 8, 12, 16, 24];
        let i = 0;
        while (i < sizes.length - 1 && sizes[i] < board.penSize)
            i++;
        i = Math.max(0, Math.min(sizes.length - 1, i + d));
        board.penSize = sizes[i];
        Sfx.tick(0.3 + i * 0.07);
    }

    // ── the view: screen = world × z + o
    property real ox: 0
    property real oy: 0
    property real vz: 1
    property bool viewReady: false

    function loadView(): void {
        const v = Scratch.current.view ?? {
            x: 0,
            y: 0,
            z: 1
        };
        board.ox = v.x ?? 0;
        board.oy = v.y ?? 0;
        board.vz = Math.max(0.15, Math.min(6, v.z ?? 1));
        board.viewReady = true;
        paper.requestPaint();
    }

    Connections {
        target: Scratch

        function onPageChanged(): void {
            board.finishEdit();
            board.selection = ({});
            board.loadView();
        }
        function onLoadedChanged(): void {
            board.loadView();
        }
    }
    Component.onCompleted: board.loadView()

    onOxChanged: viewSave.restart()
    onOyChanged: viewSave.restart()
    onVzChanged: viewSave.restart()

    Timer {
        id: viewSave

        interval: 500
        onTriggered: {
            if (board.viewReady)
                Scratch.setView(board.ox, board.oy, board.vz);
        }
    }

    function toWorld(sx: real, sy: real): var {
        return {
            x: (sx - board.ox) / board.vz,
            y: (sy - board.oy) / board.vz
        };
    }

    function zoomAt(sx: real, sy: real, factor: real): void {
        const z = Math.max(0.15, Math.min(6, board.vz * factor));
        if (Math.abs(z - board.vz) < 1e-4) {
            Sfx.tick(0.9);
            return;
        }
        board.ox = sx - (sx - board.ox) * z / board.vz;
        board.oy = sy - (sy - board.oy) * z / board.vz;
        board.vz = z;
    }

    function resetView(): void {
        board.ox = area.width / 2;
        board.oy = area.height / 2;
        board.vz = 1;
        Sfx.whoosh();
    }

    // everything on the page in view, with a margin
    function fitAll(): void {
        const its = Scratch.items;
        if (its.length === 0) {
            board.resetView();
            return;
        }
        let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
        for (const it of its) {
            const b = board.boxOf(it);
            x0 = Math.min(x0, b.x);
            y0 = Math.min(y0, b.y);
            x1 = Math.max(x1, b.x + b.w);
            y1 = Math.max(y1, b.y + b.h);
        }
        const w = Math.max(40, x1 - x0), h = Math.max(40, y1 - y0);
        const z = Math.max(0.15, Math.min(3, Math.min((area.width - 60) / w, (area.height - 60) / h)));
        board.vz = z;
        board.ox = area.width / 2 - (x0 + w / 2) * z;
        board.oy = area.height / 2 - (y0 + h / 2) * z;
        Sfx.whoosh();
    }

    // ── what is on the page, for drawing: an item keeps its drawing until it
    // changes (its key is id.v), and what the eraser has swept is hidden at once
    property var erasing: ({})
    readonly property var shown: {
        Scratch.revision;
        const out = [];
        for (const it of Scratch.items) {
            if (board.erasing[it.id])
                continue;
            out.push(Object.assign({
                key: `${it.id}.${it.v ?? 0}`
            }, it));
        }
        return out;
    }

    function itemById(id: int): var {
        for (const it of Scratch.items)
            if (it.id === id)
                return it;
        return null;
    }

    // measured sizes of texts (reported by their delegates)
    property var measured: ({})

    function boxOf(it: var): var {
        switch (it.kind) {
        case "ink":
            {
                let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
                const p = it.pts ?? [];
                for (let i = 0; i + 1 < p.length; i += 2) {
                    x0 = Math.min(x0, p[i]);
                    x1 = Math.max(x1, p[i]);
                    y0 = Math.min(y0, p[i + 1]);
                    y1 = Math.max(y1, p[i + 1]);
                }
                const r = (it.w ?? 2) / 2;
                return {
                    x: x0 - r,
                    y: y0 - r,
                    w: x1 - x0 + 2 * r,
                    h: y1 - y0 + 2 * r
                };
            }
        case "shape":
            {
                const r = (it.w ?? 2) / 2 + 2;
                return {
                    x: Math.min(it.x1, it.x2) - r,
                    y: Math.min(it.y1, it.y2) - r,
                    w: Math.abs(it.x2 - it.x1) + 2 * r,
                    h: Math.abs(it.y2 - it.y1) + 2 * r
                };
            }
        case "text":
            {
                const m = board.measured[it.id];
                return {
                    x: it.x,
                    y: it.y,
                    w: m ? m.w : Math.max(20, `${it.text}`.length * (it.size ?? 22) * 0.55),
                    h: m ? m.h : (it.size ?? 22) * 1.35
                };
            }
        default:
            return {
                x: it.x,
                y: it.y,
                w: it.w ?? 200,
                h: it.h ?? 160
            };
        }
    }

    function segDist(px: real, py: real, ax: real, ay: real, bx: real, by: real): real {
        const dx = bx - ax, dy = by - ay;
        const l2 = dx * dx + dy * dy;
        let t = l2 > 0 ? ((px - ax) * dx + (py - ay) * dy) / l2 : 0;
        t = Math.max(0, Math.min(1, t));
        const cx = ax + t * dx - px, cy = ay + t * dy - py;
        return Math.sqrt(cx * cx + cy * cy);
    }

    // the item under a world point, topmost first (r: extra reach, world units)
    function hitAt(x: real, y: real, r: real): var {
        const its = Scratch.items;
        for (let k = its.length - 1; k >= 0; k--) {
            const it = its[k];
            if (board.erasing[it.id])
                continue;
            if (it.kind === "ink") {
                const p = it.pts ?? [];
                const reach = (it.w ?? 2) / 2 + r;
                const b = board.boxOf(it);
                if (x < b.x - r || x > b.x + b.w + r || y < b.y - r || y > b.y + b.h + r)
                    continue;
                if (p.length <= 2) {
                    if (Math.hypot(x - p[0], y - p[1]) <= reach)
                        return it;
                    continue;
                }
                for (let i = 0; i + 3 < p.length; i += 2)
                    if (board.segDist(x, y, p[i], p[i + 1], p[i + 2], p[i + 3]) <= reach)
                        return it;
            } else if (it.kind === "shape" && (it.type === "line" || it.type === "arrow")) {
                if (board.segDist(x, y, it.x1, it.y1, it.x2, it.y2) <= (it.w ?? 2) / 2 + r)
                    return it;
            } else {
                const b = board.boxOf(it);
                if (x >= b.x - r && x <= b.x + b.w + r && y >= b.y - r && y <= b.y + b.h + r)
                    return it;
            }
        }
        return null;
    }

    // ── the selection: { id: true }
    property var selection: ({})
    readonly property int selectedCount: Object.keys(board.selection).length

    function selectedIds(): var {
        return Object.keys(board.selection).map(k => parseInt(k));
    }

    function isSel(id: int): bool {
        return board.selection[id] === true;
    }

    function selectAll(): void {
        const s = {};
        for (const it of Scratch.items)
            s[it.id] = true;
        board.selection = s;
        board.tool = "select";
    }

    // moving the selection: the hand's offset, written once it lets go
    property real dragDX: 0
    property real dragDY: 0

    function moved(it: var, dx: real, dy: real): var {
        if (it.kind === "ink") {
            const p = (it.pts ?? []).slice();
            for (let i = 0; i + 1 < p.length; i += 2) {
                p[i] = Math.round((p[i] + dx) * 10) / 10;
                p[i + 1] = Math.round((p[i + 1] + dy) * 10) / 10;
            }
            return {
                pts: p
            };
        }
        if (it.kind === "shape")
            return {
                x1: it.x1 + dx,
                y1: it.y1 + dy,
                x2: it.x2 + dx,
                y2: it.y2 + dy
            };
        return {
            x: it.x + dx,
            y: it.y + dy
        };
    }

    function moveSelection(dx: real, dy: real): void {
        const patch = {};
        for (const id of board.selectedIds()) {
            const it = board.itemById(id);
            if (it)
                patch[id] = board.moved(it, dx, dy);
        }
        Scratch.updateMany(patch);
    }

    function deleteSelection(): void {
        const ids = board.selectedIds();
        if (ids.length === 0)
            return;
        Scratch.remove(ids);
        board.selection = ({});
        Sfx.whoosh();
    }

    function duplicateSelection(): void {
        const ids = board.selectedIds();
        if (ids.length === 0)
            return;
        const add = [];
        const sel = {};
        for (const id of ids) {
            const it = board.itemById(id);
            if (!it)
                continue;
            const copy = Object.assign({}, it, board.moved(it, 24, 24), {
                id: Scratch.newId(),
                v: 0
            });
            add.push(copy);
            sel[copy.id] = true;
        }
        Scratch.commit(Scratch.items.concat(add), false);
        board.selection = sel;
        Sfx.pop();
    }

    // ── writing: one text or note at a time
    property int editId: -1
    readonly property var editing: board.editId >= 0 ? board.itemById(board.editId) : null

    function beginEdit(id: int): void {
        board.finishEdit();
        board.editId = id;
        board.selection = ({});
        Qt.callLater(() => editor.begin());
        board.poked();
    }

    function finishEdit(): void {
        if (board.editId < 0)
            return;
        const id = board.editId;
        const it = board.itemById(id);
        const text = editor.field ? editor.field.text : "";
        board.editId = -1;
        if (it) {
            if (text.trim() === "" && it.kind === "text")
                Scratch.remove([id]);
            else if (text !== it.text)
                Scratch.update(id, {
                    text: text
                });
        }
        board.doneTyping();
    }

    function addText(x: real, y: real): void {
        const it = Scratch.add({
            kind: "text",
            x: Math.round(x),
            y: Math.round(y - 14),
            text: "",
            size: Math.round(Math.max(14, 18 + board.penSize * 2)),
            c: board.colourKey
        });
        board.beginEdit(it.id);
    }

    function addNote(x: real, y: real, text: string): void {
        const it = Scratch.add({
            kind: "note",
            x: Math.round(x - 100),
            y: Math.round(y - 24),
            w: 200,
            h: 160,
            text: text ?? "",
            c: board.noteColours[(Scratch.items.length + board.swatch) % board.noteColours.length],
            tilt: Math.round((Math.random() * 4 - 2) * 10) / 10
        });
        board.dropped = it.id;
        Sfx.pop();
        if ((text ?? "") === "")
            board.beginEdit(it.id);
    }
    // the note that just landed (it drops in with a bounce)
    property int dropped: -1

    // ── the hand: a stroke, a shape, a frame, a move
    property var livePts: []        // the stroke being drawn, world, flat
    property var liveShape: null    // { type, x1, y1, x2, y2 }
    property var band: null         // the selection frame, world { x0, y0, x1, y1 }

    function smoothed(p: var): var {
        // drop points closer than a pixel apart, then soften the corners a hand makes
        const out = [];
        let lx = Infinity, ly = Infinity;
        const min = 0.9 / board.vz;
        for (let i = 0; i + 1 < p.length; i += 2) {
            if (Math.hypot(p[i] - lx, p[i + 1] - ly) < min && i + 2 < p.length)
                continue;
            out.push(p[i], p[i + 1]);
            lx = p[i];
            ly = p[i + 1];
        }
        const k = Math.max(0, Math.min(1, Config.scratch.smooth));
        if (k <= 0 || out.length < 8)
            return out.map(v => Math.round(v * 10) / 10);
        const s = out.slice();
        for (let pass = 0; pass < 2; pass++)
            for (let i = 2; i + 3 < s.length; i += 2) {
                s[i] = s[i] * (1 - k * 0.5) + (s[i - 2] + s[i + 2]) * k * 0.25;
                s[i + 1] = s[i + 1] * (1 - k * 0.5) + (s[i - 1] + s[i + 3]) * k * 0.25;
            }
        return s.map(v => Math.round(v * 10) / 10);
    }

    function pointsOf(p: var): var {
        const out = [];
        for (let i = 0; i + 1 < (p ?? []).length; i += 2)
            out.push(Qt.point(p[i], p[i + 1]));
        // a dot: a line of no length draws nothing
        if (out.length === 1)
            out.push(Qt.point(out[0].x + 0.05, out[0].y + 0.05));
        return out;
    }

    function shapePath(type: string, x1: real, y1: real, x2: real, y2: real, w: real): string {
        const f = n => n.toFixed(2);
        if (type === "rect")
            return `M ${f(x1)} ${f(y1)} L ${f(x2)} ${f(y1)} L ${f(x2)} ${f(y2)} L ${f(x1)} ${f(y2)} Z`;
        if (type === "ellipse") {
            const cx = (x1 + x2) / 2, cy = (y1 + y2) / 2, rx = Math.max(0.5, Math.abs(x2 - x1) / 2), ry = Math.max(0.5, Math.abs(y2 - y1) / 2);
            return `M ${f(cx - rx)} ${f(cy)} A ${f(rx)} ${f(ry)} 0 1 0 ${f(cx + rx)} ${f(cy)} A ${f(rx)} ${f(ry)} 0 1 0 ${f(cx - rx)} ${f(cy)} Z`;
        }
        let d = `M ${f(x1)} ${f(y1)} L ${f(x2)} ${f(y2)}`;
        if (type === "arrow") {
            const a = Math.atan2(y2 - y1, x2 - x1);
            const len = Math.max(10, w * 4.5);
            const s = 0.5;
            d += ` M ${f(x2 - len * Math.cos(a - s))} ${f(y2 - len * Math.sin(a - s))} L ${f(x2)} ${f(y2)} L ${f(x2 - len * Math.cos(a + s))} ${f(y2 - len * Math.sin(a + s))}`;
        }
        return d;
    }

    // ── keys, while nothing is being written (the island hands them over)
    property bool help: false

    function handleKey(event: var): bool {
        const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
        const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
        const k = event.key;
        board.poked();
        if (k === Qt.Key_F1 || (k === Qt.Key_Question) || (!ctrl && event.text === "?")) {
            board.help = !board.help;
            Sfx.open();
            return true;
        }
        if (board.help && (k === Qt.Key_Escape || k === Qt.Key_Return)) {
            board.help = false;
            return true;
        }
        if (ctrl) {
            switch (k) {
            case Qt.Key_Z:
                if (shift ? Scratch.redo() : Scratch.undo())
                    Sfx.tick(0.7);
                else
                    Sfx.nope();
                board.selection = ({});
                return true;
            case Qt.Key_Y:
                if (Scratch.redo())
                    Sfx.tick(0.7);
                else
                    Sfx.nope();
                return true;
            case Qt.Key_A:
                board.selectAll();
                Sfx.select();
                return true;
            case Qt.Key_D:
                board.duplicateSelection();
                return true;
            case Qt.Key_V:
                board.paste();
                return true;
            case Qt.Key_S:
                board.exportPng();
                return true;
            case Qt.Key_N:
                Scratch.addPage();
                Sfx.whoosh();
                return true;
            case Qt.Key_PageDown:
                Scratch.goPage((Scratch.page + 1) % Scratch.pages.length);
                Sfx.cursor();
                return true;
            case Qt.Key_PageUp:
                Scratch.goPage((Scratch.page - 1 + Scratch.pages.length) % Scratch.pages.length);
                Sfx.cursor();
                return true;
            case Qt.Key_0:
                board.resetView();
                return true;
            case Qt.Key_1:
                board.fitAll();
                return true;
            case Qt.Key_Plus:
            case Qt.Key_Equal:
                board.zoomAt(area.width / 2, area.height / 2, 1.25);
                return true;
            case Qt.Key_Minus:
                board.zoomAt(area.width / 2, area.height / 2, 0.8);
                return true;
            case Qt.Key_Backspace:
                if (shift) {
                    Scratch.clearPage();
                    Sfx.whoosh();
                    return true;
                }
                return false;
            }
            return false;
        }
        if (k === Qt.Key_Delete || k === Qt.Key_Backspace) {
            board.deleteSelection();
            return true;
        }
        if (board.selectedCount > 0 && (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down)) {
            const step = (shift ? 10 : 1) / board.vz;
            board.moveSelection(k === Qt.Key_Left ? -step : (k === Qt.Key_Right ? step : 0), k === Qt.Key_Up ? -step : (k === Qt.Key_Down ? step : 0));
            Sfx.tick(0.25);
            return true;
        }
        if (k === Qt.Key_BracketLeft) {
            board.nudgeSize(-1);
            return true;
        }
        if (k === Qt.Key_BracketRight) {
            board.nudgeSize(1);
            return true;
        }
        if (k >= Qt.Key_1 && k <= Qt.Key_7) {
            board.pickSwatch(k - Qt.Key_1);
            return true;
        }
        const map = {
            [Qt.Key_V]: "select",
            [Qt.Key_H]: "hand",
            [Qt.Key_P]: "pen",
            [Qt.Key_M]: "marker",
            [Qt.Key_E]: "eraser",
            [Qt.Key_T]: "text",
            [Qt.Key_N]: "note",
            [Qt.Key_L]: "line",
            [Qt.Key_A]: "arrow",
            [Qt.Key_R]: "rect",
            [Qt.Key_O]: "ellipse"
        };
        if (map[k] !== undefined) {
            board.useTool(map[k]);
            return true;
        }
        return false;
    }

    // ── the clipboard: a picture becomes a picture on the sheet, text a note
    // (bin/velvet-input speaks the compositor's clipboard itself — no
    // wl-clipboard needed)
    readonly property string inputTool: `${Qt.resolvedUrl("../../bin/velvet-input")}`.replace(/^file:\/\//, "")

    function paste(): void {
        clip.file = Scratch.picturePath("png");
        clip.command = ["python3", board.inputTool, "paste", "--image", clip.file];
        clip.running = false;
        clip.running = true;
    }

    Process {
        id: clip

        property string file: ""

        stdout: StdioCollector {
            onStreamFinished: {
                let r = null;
                try {
                    r = JSON.parse(text.trim().split("\n").pop() || "{}");
                } catch (e) {
                    r = null;
                }
                const c = board.toWorld(area.width / 2, area.height / 2);
                if (r && r.kind === "image") {
                    Scratch.add({
                        kind: "image",
                        x: Math.round(c.x - 160),
                        y: Math.round(c.y - 120),
                        w: 0,
                        h: 0,
                        src: clip.file
                    });
                    Sfx.pop();
                } else if (r && r.kind === "text" && `${r.text}`.trim() !== "") {
                    board.addNote(c.x, c.y, `${r.text}`.slice(0, 4000));
                } else {
                    Toast.show("NOTHING TO PASTE — COPY A PICTURE OR SOME TEXT FIRST", "info", 2600);
                    Sfx.nope();
                }
            }
        }
    }

    // ── export: what you see of the page, as a picture in ~/Pictures
    function exportPng(): void {
        const path = Scratch.exportPath();
        board.finishEdit();
        mkPictures.command = ["mkdir", "-p", path.slice(0, path.lastIndexOf("/"))];
        mkPictures.running = true;
        area.grabToImage(result => {
            if (result.saveToFile(path)) {
                Toast.ok(`SAVED · ${path.replace(Quickshell.env("HOME") ?? "", "~")}`);
                Sfx.quest();
            } else {
                Toast.show("THE PICTURE COULD NOT BE SAVED", "warn", 3000);
            }
        });
    }

    Process {
        id: mkPictures

        command: ["true"]
    }

    // ═══════════════════════════════════════════════════════════ the toolbar
    readonly property bool barTop: Config.scratch.toolbar !== "bottom"
    readonly property int barH: Config.scratch.labels ? 46 : 36

    Item {
        id: toolbar

        anchors.left: parent.left
        anchors.right: parent.right
        y: board.barTop ? 0 : parent.height - height
        height: board.barH

        Row {
            id: toolsRow

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: ["select", "hand", "|", "pen", "marker", "eraser", "|", "text", "note", "shape"]

                Item {
                    id: cell

                    required property string modelData
                    readonly property bool gap: cell.modelData === "|"
                    readonly property string tid: cell.modelData === "shape" ? board.lastShape : cell.modelData
                    readonly property bool on: !cell.gap && (cell.modelData === "shape" ? board.shapeTool : board.tool === cell.modelData)

                    width: cell.gap ? 9 : (Config.scratch.labels ? 46 : 30)
                    height: board.barH - 6

                    Rectangle {
                        visible: cell.gap
                        anchors.centerIn: parent
                        width: 1
                        height: parent.height * 0.6
                        color: Colours.alpha(Colours.ink, 0.16)
                    }

                    ToolButton {
                        visible: !cell.gap
                        anchors.fill: parent
                        icon: board.toolInfo[cell.tid]?.icon ?? ""
                        label: Config.scratch.labels ? (board.toolInfo[cell.tid]?.label ?? "") : ""
                        on: cell.on
                        tip: `${board.toolInfo[cell.tid]?.label ?? ""}`
                        onClicked: {
                            if (cell.modelData === "shape" && board.shapeTool) {
                                const i = board.shapeTools.indexOf(board.tool);
                                board.useTool(board.shapeTools[(i + 1) % board.shapeTools.length]);
                            } else {
                                board.useTool(cell.tid);
                            }
                        }
                    }
                }
            }

            Item {
                width: 9
                height: board.barH - 6
                Rectangle {
                    anchors.centerIn: parent
                    width: 1
                    height: parent.height * 0.6
                    color: Colours.alpha(Colours.ink, 0.16)
                }
            }

            // the colours
            Repeater {
                model: board.swatches.length

                Item {
                    id: sw

                    required property int index
                    readonly property bool on: board.swatch === sw.index

                    width: 20
                    height: board.barH - 6

                    Rectangle {
                        anchors.centerIn: parent
                        width: sw.on ? 16 : (swHover.hovered ? 14 : 12)
                        height: width
                        radius: width / 2
                        color: board.colourOf(board.swatches[sw.index])
                        border.width: sw.on ? 2 : 1
                        border.color: sw.on ? Colours.ink : Colours.alpha(Colours.ink, 0.25)

                        Behavior on width {
                            NumberAnimation {
                                duration: 220
                                easing.type: Easing.OutBack
                                easing.overshoot: 3
                            }
                        }
                    }

                    HoverHandler {
                        id: swHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: board.pickSwatch(sw.index)
                    }
                }
            }

            Item {
                width: 6
                height: 1
            }

            // the size: − dot +
            ToolButton {
                width: 22
                height: board.barH - 6
                icon: "remove"
                tip: "THINNER  ·  ["
                onClicked: board.nudgeSize(-1)
            }
            Item {
                width: 22
                height: board.barH - 6
                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(3, Math.min(20, board.penSize + 2))
                    height: width
                    radius: width / 2
                    color: board.colourOf(board.colourKey)

                    Behavior on width {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.5
                        }
                    }
                }
            }
            ToolButton {
                width: 22
                height: board.barH - 6
                icon: "add"
                tip: "THICKER  ·  ]"
                onClicked: board.nudgeSize(1)
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            ToolButton {
                width: 30
                height: board.barH - 6
                icon: "undo"
                tip: "UNDO  ·  CTRL+Z"
                enabled: Scratch.undoStack.length > 0
                onClicked: {
                    if (Scratch.undo())
                        Sfx.tick(0.7);
                    board.selection = ({});
                }
            }
            ToolButton {
                width: 30
                height: board.barH - 6
                icon: "redo"
                tip: "REDO  ·  CTRL+SHIFT+Z"
                enabled: Scratch.redoStack.length > 0
                onClicked: {
                    if (Scratch.redo())
                        Sfx.tick(0.7);
                }
            }
            ToolButton {
                width: 30
                height: board.barH - 6
                icon: "help"
                on: board.help
                tip: "EVERY KEY  ·  F1"
                onClicked: {
                    board.help = !board.help;
                    Sfx.open();
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════ the sheet
    Item {
        id: area

        anchors.left: parent.left
        anchors.right: parent.right
        y: board.barTop ? board.barH : 0
        height: parent.height - board.barH - foot.height
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: 10
            color: "transparent"
            border.width: 1
            border.color: Colours.alpha(board.inkCol, 0.12)
            z: 20
        }

        // the paper and its pattern, drawn for what is in view
        Canvas {
            id: paper

            anchors.fill: parent
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = board.paperCol;
                ctx.fillRect(0, 0, width, height);
                const kind = Config.scratch.paper;
                if (kind === "plain")
                    return;
                let step = 24 * board.vz;
                while (step < 12)
                    step *= 2;
                while (step > 48)
                    step /= 2;
                const x0 = ((board.ox % step) + step) % step;
                const y0 = ((board.oy % step) + step) % step;
                ctx.fillStyle = board.lineCol;
                if (kind === "dots") {
                    for (let x = x0; x < width; x += step)
                        for (let y = y0; y < height; y += step)
                            ctx.fillRect(Math.round(x) - 1, Math.round(y) - 1, 2, 2);
                } else if (kind === "grid") {
                    for (let x = x0; x < width; x += step)
                        ctx.fillRect(Math.round(x), 0, 1, height);
                    for (let y = y0; y < height; y += step)
                        ctx.fillRect(0, Math.round(y), width, 1);
                } else {
                    for (let y = y0; y < height; y += step)
                        ctx.fillRect(0, Math.round(y), width, 1);
                }
            }

            Connections {
                target: board

                function onOxChanged(): void {
                    paper.requestPaint();
                }
                function onOyChanged(): void {
                    paper.requestPaint();
                }
                function onVzChanged(): void {
                    paper.requestPaint();
                }
                function onPaperColChanged(): void {
                    paper.requestPaint();
                }
            }
            Connections {
                target: Config.scratch

                function onPaperChanged(): void {
                    paper.requestPaint();
                }
            }
            onWidthChanged: paper.requestPaint()
            onHeightChanged: paper.requestPaint()
        }

        // an empty page says what it is for
        Column {
            anchors.centerIn: parent
            spacing: 6
            visible: Scratch.items.length === 0 && board.livePts.length === 0 && board.editId < 0
            opacity: 0.55

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "edit_note"
                color: board.inkCol
                font.pixelSize: 38
            }
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "WRITE, DRAW, PASTE — IT STAYS"
                color: board.inkCol
                font.pixelSize: Appearance.font.size.small
                tracking: 1.5
            }
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "T TEXT · N NOTE · P PEN · CTRL+V A PICTURE · F1 EVERY KEY"
                color: Colours.alpha(board.inkCol, 0.75)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }
        }

        // the page's world: everything on it, moved and scaled by the view
        Item {
            id: world

            x: board.ox
            y: board.oy
            scale: board.vz
            transformOrigin: Item.TopLeft

            Repeater {
                model: ScriptModel {
                    values: board.shown
                    objectProp: "key"
                }

                Loader {
                    id: slot

                    required property var modelData
                    readonly property bool picked: board.isSel(slot.modelData.id)

                    x: slot.picked ? board.dragDX : 0
                    y: slot.picked ? board.dragDY : 0
                    sourceComponent: ({
                            ink: inkC,
                            shape: shapeC,
                            text: textC,
                            note: noteC,
                            image: imageC
                        })[slot.modelData.kind] ?? null
                }
            }

            // the stroke being drawn
            Shape {
                visible: board.livePts.length > 0
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: board.tool === "marker" ? Colours.alpha(board.colourOf(board.colourKey), 0.38) : board.colourOf(board.colourKey)
                    strokeWidth: board.tool === "marker" ? board.penSize * 4 / board.vz : board.penSize / board.vz
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        path: board.pointsOf(board.livePts)
                    }
                }
            }

            // the shape being dragged out
            Shape {
                visible: board.liveShape !== null
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: board.colourOf(board.colourKey)
                    strokeWidth: board.penSize / board.vz
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathSvg {
                        path: board.liveShape ? board.shapePath(board.liveShape.type, board.liveShape.x1, board.liveShape.y1, board.liveShape.x2, board.liveShape.y2, board.penSize / board.vz) : ""
                    }
                }
            }

            // the selection: a dashed frame round each picked item
            Repeater {
                model: board.selectedIds()

                Rectangle {
                    required property var modelData
                    readonly property var it: board.itemById(modelData)
                    readonly property var b: it ? board.boxOf(it) : ({
                            x: 0,
                            y: 0,
                            w: 0,
                            h: 0
                        })

                    x: b.x - 6 / board.vz + board.dragDX
                    y: b.y - 6 / board.vz + board.dragDY
                    width: b.w + 12 / board.vz
                    height: b.h + 12 / board.vz
                    radius: 6 / board.vz
                    color: Colours.alpha(Colours.accent, 0.06)
                    border.width: 1.5 / board.vz
                    border.color: Colours.alpha(Colours.accent, 0.85)
                }
            }

            // the frame being pulled
            Rectangle {
                visible: board.band !== null
                x: board.band ? Math.min(board.band.x0, board.band.x1) : 0
                y: board.band ? Math.min(board.band.y0, board.band.y1) : 0
                width: board.band ? Math.abs(board.band.x1 - board.band.x0) : 0
                height: board.band ? Math.abs(board.band.y1 - board.band.y0) : 0
                color: Colours.alpha(Colours.accent, 0.08)
                border.width: 1 / board.vz
                border.color: Colours.alpha(Colours.accent, 0.7)
            }
        }

        // ── the hand on the sheet
        MouseArea {
            id: hand

            property string mode: ""        // draw · erase · shape · move · band · pan
            property real lastX: 0
            property real lastY: 0
            property var start: null
            property bool shift: false

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            hoverEnabled: true
            preventStealing: true
            cursorShape: {
                if (hand.mode === "pan" || (hand.pressed && board.tool === "hand"))
                    return Qt.ClosedHandCursor;
                switch (board.tool) {
                case "hand":
                    return Qt.OpenHandCursor;
                case "select":
                    return Qt.ArrowCursor;
                case "text":
                    return Qt.IBeamCursor;
                case "note":
                    return Qt.PointingHandCursor;
                default:
                    return Qt.CrossCursor;
                }
            }

            onPressed: mouse => {
                board.poked();
                hand.lastX = mouse.x;
                hand.lastY = mouse.y;
                hand.shift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                const w = board.toWorld(mouse.x, mouse.y);
                hand.start = w;
                if (board.editId >= 0)
                    board.finishEdit();
                if (mouse.button !== Qt.LeftButton || board.tool === "hand") {
                    hand.mode = "pan";
                    return;
                }
                switch (board.tool) {
                case "pen":
                case "marker":
                    hand.mode = "draw";
                    board.livePts = [w.x, w.y];
                    break;
                case "eraser":
                    hand.mode = "erase";
                    board.eraseAt(w.x, w.y);
                    break;
                case "text":
                    {
                        hand.mode = "";
                        const hit = board.hitAt(w.x, w.y, 4 / board.vz);
                        if (hit && (hit.kind === "text" || hit.kind === "note"))
                            board.beginEdit(hit.id);
                        else
                            board.addText(w.x, w.y);
                        break;
                    }
                case "note":
                    {
                        hand.mode = "";
                        const hit = board.hitAt(w.x, w.y, 2 / board.vz);
                        if (hit && hit.kind === "note")
                            board.beginEdit(hit.id);
                        else
                            board.addNote(w.x, w.y, "");
                        break;
                    }
                case "select":
                    {
                        const hit = board.hitAt(w.x, w.y, 6 / board.vz);
                        if (hit) {
                            if (!board.isSel(hit.id)) {
                                const s = hand.shift ? Object.assign({}, board.selection) : {};
                                s[hit.id] = true;
                                board.selection = s;
                                Sfx.tick(0.5);
                            }
                            hand.mode = "move";
                        } else {
                            if (!hand.shift)
                                board.selection = ({});
                            hand.mode = "band";
                            board.band = {
                                x0: w.x,
                                y0: w.y,
                                x1: w.x,
                                y1: w.y
                            };
                        }
                        break;
                    }
                default:
                    hand.mode = "shape";
                    board.liveShape = {
                        type: board.tool,
                        x1: w.x,
                        y1: w.y,
                        x2: w.x,
                        y2: w.y
                    };
                }
            }

            onPositionChanged: mouse => {
                if (!hand.pressed)
                    return;
                const w = board.toWorld(mouse.x, mouse.y);
                const shift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                switch (hand.mode) {
                case "pan":
                    board.ox += mouse.x - hand.lastX;
                    board.oy += mouse.y - hand.lastY;
                    break;
                case "draw":
                    {
                        const p = board.livePts;
                        const lx = p[p.length - 2], ly = p[p.length - 1];
                        if (Math.hypot(w.x - lx, w.y - ly) * board.vz >= 1.2)
                            board.livePts = p.concat([w.x, w.y]);
                        break;
                    }
                case "erase":
                    board.eraseAt(w.x, w.y);
                    break;
                case "shape":
                    {
                        let x2 = w.x, y2 = w.y;
                        const s = board.liveShape;
                        if (shift) {
                            const dx = x2 - s.x1, dy = y2 - s.y1;
                            if (s.type === "rect" || s.type === "ellipse") {
                                const m = Math.max(Math.abs(dx), Math.abs(dy));
                                x2 = s.x1 + Math.sign(dx || 1) * m;
                                y2 = s.y1 + Math.sign(dy || 1) * m;
                            } else {
                                // snap to the nearest 45°
                                const a = Math.round(Math.atan2(dy, dx) / (Math.PI / 4)) * (Math.PI / 4);
                                const l = Math.hypot(dx, dy);
                                x2 = s.x1 + Math.cos(a) * l;
                                y2 = s.y1 + Math.sin(a) * l;
                            }
                        }
                        board.liveShape = Object.assign({}, s, {
                            x2: x2,
                            y2: y2
                        });
                        break;
                    }
                case "move":
                    board.dragDX = w.x - hand.start.x;
                    board.dragDY = w.y - hand.start.y;
                    break;
                case "band":
                    board.band = Object.assign({}, board.band, {
                        x1: w.x,
                        y1: w.y
                    });
                    break;
                }
                hand.lastX = mouse.x;
                hand.lastY = mouse.y;
            }

            onReleased: mouse => {
                const mode = hand.mode;
                hand.mode = "";
                if (mode === "draw") {
                    const pts = board.smoothed(board.livePts);
                    board.livePts = [];
                    if (pts.length >= 2) {
                        const marker = board.tool === "marker";
                        Scratch.add({
                            kind: "ink",
                            pts: pts,
                            w: Math.round((marker ? board.penSize * 4 : board.penSize) / board.vz * 100) / 100,
                            c: board.colourKey,
                            a: marker ? 0.38 : 1
                        });
                    }
                } else if (mode === "erase") {
                    const ids = Object.keys(board.erasing).map(k => parseInt(k));
                    if (ids.length > 0)
                        Scratch.remove(ids);
                    board.erasing = ({});
                } else if (mode === "shape") {
                    const s = board.liveShape;
                    board.liveShape = null;
                    if (s && Math.hypot(s.x2 - s.x1, s.y2 - s.y1) * board.vz > 4) {
                        Scratch.add({
                            kind: "shape",
                            type: s.type,
                            x1: Math.round(s.x1 * 10) / 10,
                            y1: Math.round(s.y1 * 10) / 10,
                            x2: Math.round(s.x2 * 10) / 10,
                            y2: Math.round(s.y2 * 10) / 10,
                            w: Math.round(board.penSize / board.vz * 100) / 100,
                            c: board.colourKey
                        });
                        Sfx.tick(0.6);
                    }
                } else if (mode === "move") {
                    const dx = board.dragDX, dy = board.dragDY;
                    board.dragDX = 0;
                    board.dragDY = 0;
                    if (Math.hypot(dx, dy) * board.vz > 1)
                        board.moveSelection(dx, dy);
                } else if (mode === "band") {
                    const b = board.band;
                    board.band = null;
                    if (b) {
                        const x0 = Math.min(b.x0, b.x1), x1 = Math.max(b.x0, b.x1), y0 = Math.min(b.y0, b.y1), y1 = Math.max(b.y0, b.y1);
                        const s = Object.assign({}, board.selection);
                        let n = 0;
                        for (const it of Scratch.items) {
                            const q = board.boxOf(it);
                            if (q.x < x1 && q.x + q.w > x0 && q.y < y1 && q.y + q.h > y0) {
                                s[it.id] = true;
                                n++;
                            }
                        }
                        board.selection = s;
                        if (n > 0)
                            Sfx.tick(0.6);
                    }
                }
            }

            onDoubleClicked: mouse => {
                const w = board.toWorld(mouse.x, mouse.y);
                const hit = board.hitAt(w.x, w.y, 4 / board.vz);
                if (hit && (hit.kind === "text" || hit.kind === "note"))
                    board.beginEdit(hit.id);
                else if (!hit && board.tool === "select")
                    board.addText(w.x, w.y);
            }

            onWheel: wheel => {
                board.poked();
                if (wheel.modifiers & Qt.ControlModifier) {
                    const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y * 4;
                    board.zoomAt(wheel.x, wheel.y, Math.pow(1.0015, d));
                    return;
                }
                let dx = wheel.pixelDelta.x !== 0 ? wheel.pixelDelta.x : wheel.angleDelta.x / 2;
                let dy = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 2;
                if (wheel.modifiers & Qt.ShiftModifier) {
                    dx = dy;
                    dy = 0;
                }
                board.ox += dx;
                board.oy += dy;
            }
        }

        // a touchpad pinch zooms at its middle
        PinchHandler {
            target: null
            onScaleChanged: delta => board.zoomAt(centroid.position.x, centroid.position.y, delta)
        }

        // ── writing: the field over the text or note being written
        Item {
            id: editLayer

            x: board.ox
            y: board.oy
            scale: board.vz
            transformOrigin: Item.TopLeft
            z: 10

            Item {
                id: editor

                readonly property var it: board.editing
                readonly property bool note: editor.it !== null && editor.it.kind === "note"
                property var field: null

                visible: editor.it !== null
                x: editor.it ? editor.it.x : 0
                y: editor.it ? editor.it.y : 0
                width: editor.note ? editor.it.w : Math.max(60, input.contentWidth + 24)
                height: editor.note ? editor.it.h : input.contentHeight + 6
                rotation: editor.note ? (editor.it.tilt ?? 0) : 0

                function begin(): void {
                    if (!editor.it)
                        return;
                    input.text = editor.it.text ?? "";
                    input.cursorPosition = input.text.length;
                    editor.field = input;
                    input.forceActiveFocus();
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: editor.note ? 0 : -4
                    radius: editor.note ? 6 : 4
                    color: editor.note ? (editor.it?.c ?? "#ffe58a") : "transparent"
                    border.width: editor.note ? 0 : 1 / board.vz
                    border.color: Colours.alpha(Colours.accent, 0.8)
                }

                TextEdit {
                    id: input

                    x: editor.note ? 14 : 0
                    y: editor.note ? 14 : 0
                    width: editor.note ? editor.width - 28 : Math.max(40, input.implicitWidth)
                    height: editor.note ? editor.height - 28 : implicitHeight
                    wrapMode: editor.note ? TextEdit.Wrap : TextEdit.NoWrap
                    color: editor.note ? "#2a2520" : board.colourOf(editor.it?.c ?? "ink")
                    selectionColor: Colours.alpha(Colours.accent, 0.5)
                    font.family: Appearance.fontFamily.body
                    font.pixelSize: editor.note ? 18 : (editor.it?.size ?? 22)
                    selectByMouse: true
                    persistentSelection: true

                    Keys.onEscapePressed: event => {
                        board.finishEdit();
                        event.accepted = true;
                    }
                    Keys.onPressed: event => {
                        board.poked();
                        // Ctrl+Enter (and Enter in a one-line text) ends the writing
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && ((event.modifiers & Qt.ControlModifier) || !editor.note)) {
                            board.finishEdit();
                            event.accepted = true;
                        }
                    }
                    onActiveFocusChanged: {
                        if (!activeFocus && board.editId >= 0 && editor.field === input)
                            Qt.callLater(() => {
                                if (!input.activeFocus)
                                    board.finishEdit();
                            });
                    }
                }
            }
        }

        // ── every key (F1 · ?)
        Rectangle {
            id: helpSheet

            anchors.fill: parent
            anchors.margins: 10
            visible: opacity > 0.01
            opacity: board.help ? 1 : 0
            radius: 12
            color: Colours.alpha(Colours.ink0, 0.92)
            border.width: 1
            border.color: Colours.alpha(Colours.accent, 0.4)
            z: 30

            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: board.help = false
                onWheel: wheel => wheel.accepted = true
            }

            readonly property var rows: {
                const s = Shortcuts.sections.find(x => x.name === "SCRATCHPAD");
                return s ? s.keys : [];
            }
            // one column when the list fits the pad's height, two when it does not
            readonly property bool twoCols: helpSheet.rows.length * 17 > helpSheet.height - 64
            readonly property real colW: helpSheet.twoCols ? (helpSheet.width - 48) / 2 : helpSheet.width - 36

            P5Text {
                x: 18
                y: 14
                display: true
                text: "SCRATCHPAD · EVERY KEY"
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.normal
                tracking: 1.6
            }

            Flow {
                x: 18
                y: 44
                width: parent.width - 36
                height: parent.height - 60
                spacing: 4
                flow: Flow.TopToBottom

                Repeater {
                    model: helpSheet.rows

                    Row {
                        required property var modelData

                        width: helpSheet.colW
                        spacing: 8

                        P5Text {
                            width: 170
                            text: modelData.k
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.tiny
                            font.family: Appearance.fontFamily.mono
                            elide: Text.ElideRight
                        }
                        P5Text {
                            width: parent.width - 178
                            text: modelData.v
                            color: Colours.inkDim
                            font.pixelSize: Appearance.font.size.tiny
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // the eraser: what it touches is hidden at once and removed when the hand lets go
    function eraseAt(x: real, y: real): void {
        const hit = board.hitAt(x, y, 8 / board.vz);
        if (!hit || board.erasing[hit.id])
            return;
        const e = Object.assign({}, board.erasing);
        e[hit.id] = true;
        board.erasing = e;
        Sfx.tick(0.55);
    }

    // a page being renamed (double-click its chip) or about to go (right-click twice)
    property int renaming: -1
    property string renameText: ""
    property int armedPage: -1
    // the click that armed a page reaches its chip as well: that one never deletes
    property double armedAt: 0

    Timer {
        id: disarmPage

        interval: 2600
        onTriggered: board.armedPage = -1
    }

    function renameDone(apply: bool): void {
        if (board.renaming < 0)
            return;
        if (apply && board.renameText.trim() !== "") {
            Scratch.goPage(board.renaming);
            Scratch.renamePage(board.renameText);
            Sfx.select();
        }
        board.renaming = -1;
        board.doneTyping();
    }

    // ═══════════════════════════════════════════════════════════ the foot
    Item {
        id: foot

        anchors.left: parent.left
        anchors.right: parent.right
        y: board.barTop ? parent.height - height : board.barH
        height: 28

        // the pages
        Row {
            id: pageRow

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Repeater {
                model: Scratch.pages.length

                Rectangle {
                    id: pg

                    required property int index
                    readonly property bool on: Scratch.page === pg.index
                    readonly property bool armed: board.armedPage === pg.index
                    // the × shows on the page you are on, and on any you point at
                    readonly property bool cross: (pg.on || pgHover.hovered || xHover.hovered) && !pg.armed && board.renaming !== pg.index

                    width: board.renaming === pg.index ? 120 : Math.min(128, pgLabel.implicitWidth + 18 + (pg.cross ? 16 : 0))
                    height: 22
                    radius: 11
                    color: pg.armed ? Colours.danger : (pg.on || board.renaming === pg.index ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.ink, pgHover.hovered ? 0.14 : 0.07))
                    scale: pgTap.pressed ? 0.92 : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutBack
                            easing.overshoot: 3
                        }
                    }

                    P5Text {
                        id: pgLabel

                        anchors.verticalCenter: parent.verticalCenter
                        x: 9
                        width: Math.min(implicitWidth, 92)
                        visible: board.renaming !== pg.index
                        text: pg.armed ? "DELETE?" : (Scratch.pages[pg.index]?.name ?? "")
                        color: pg.armed ? Colours.on(Colours.danger) : (pg.on ? Colours.on(Colours.accent) : Colours.inkDim)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.2
                        elide: Text.ElideRight
                    }
                    // the name being written, in place of the label
                    TextInput {
                        anchors.fill: parent
                        anchors.leftMargin: 9
                        anchors.rightMargin: 9
                        visible: board.renaming === pg.index
                        verticalAlignment: TextInput.AlignVCenter
                        color: Colours.on(Colours.accent)
                        selectionColor: Colours.alpha(Colours.ink0, 0.35)
                        selectedTextColor: Colours.on(Colours.accent)
                        font.family: Appearance.fontFamily.display
                        font.pixelSize: Appearance.font.size.tiny
                        font.capitalization: Font.AllUppercase
                        maximumLength: 24
                        clip: true
                        onVisibleChanged: {
                            if (!visible)
                                return;
                            text = Scratch.pages[pg.index]?.name ?? "";
                            board.renameText = text;
                            selectAll();
                            forceActiveFocus();
                        }
                        onTextChanged: {
                            if (visible)
                                board.renameText = text;
                        }
                        Keys.onReturnPressed: board.renameDone(true)
                        Keys.onEnterPressed: board.renameDone(true)
                        Keys.onEscapePressed: board.renameDone(false)
                        onActiveFocusChanged: {
                            if (!activeFocus && board.renaming === pg.index)
                                board.renameDone(true);
                        }
                    }
                    HoverHandler {
                        id: pgHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    // click: go there · double-click: rename · right-click twice: delete
                    TapHandler {
                        id: pgTap

                        acceptedButtons: Qt.LeftButton
                        onTapped: {
                            if (pg.armed && Date.now() - board.armedAt < 400)
                                return;
                            if (pg.armed) {
                                board.armedPage = -1;
                                Scratch.goPage(pg.index);
                                Scratch.removePage();
                                Sfx.whoosh();
                                return;
                            }
                            Scratch.goPage(pg.index);
                            Sfx.cursor();
                        }
                        onDoubleTapped: board.renaming = pg.index
                    }
                    // the ×: on hover, at the chip's end — a click arms it
                    // (DELETE?), a click on the armed chip takes the page away
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        radius: 8
                        visible: pg.cross
                        color: Colours.alpha(xHover.hovered ? Colours.danger : Colours.ink0, xHover.hovered ? 0.9 : 0.35)
                        scale: xTap.pressed ? 0.8 : (xHover.hovered ? 1.15 : 1)

                        Behavior on scale {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutBack
                                easing.overshoot: 3
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: "close"
                            color: xHover.hovered ? Colours.on(Colours.danger) : Colours.ink
                            font.pixelSize: 11
                        }
                        HoverHandler {
                            id: xHover

                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            id: xTap

                            onTapped: {
                                board.armedPage = pg.index;
                                board.armedAt = Date.now();
                                disarmPage.restart();
                                Sfx.nope();
                            }
                        }
                    }
                }
            }

            ToolButton {
                width: 24
                height: 22
                icon: "add"
                tip: "A NEW PAGE  ·  CTRL+N"
                onClicked: {
                    Scratch.addPage();
                    Sfx.whoosh();
                }
            }
        }

        // what the tool does
        P5Text {
            anchors.left: pageRow.right
            anchors.leftMargin: 12
            anchors.right: viewRow.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: board.toolInfo[board.tool]?.hint ?? ""
            color: Colours.alpha(Colours.inkDim, 0.8)
            font.pixelSize: Appearance.font.size.tiny - 1
            tracking: 1
            elide: Text.ElideRight
        }

        Row {
            id: viewRow

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            ToolButton {
                width: 50
                height: 22
                label: `${Math.round(board.vz * 100)} %`
                tip: "BACK TO 100 %  ·  CTRL+0"
                onClicked: board.resetView()
            }
            ToolButton {
                width: 26
                height: 22
                icon: "fit_screen"
                tip: "EVERYTHING IN VIEW  ·  CTRL+1"
                onClicked: board.fitAll()
            }
            ToolButton {
                width: 26
                height: 22
                icon: "download"
                tip: "SAVE AS A PICTURE  ·  CTRL+S"
                onClicked: board.exportPng()
            }
            ToolButton {
                width: 26
                height: 22
                icon: "delete_sweep"
                tip: "CLEAR THIS PAGE  ·  CTRL+SHIFT+BACKSPACE (CTRL+Z BRINGS IT BACK)"
                onClicked: {
                    Scratch.clearPage();
                    Sfx.whoosh();
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════ the pieces
    Component {
        id: inkC

        Shape {
            readonly property var it: parent ? parent.modelData : null

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: it ? (it.a < 1 ? Colours.alpha(board.colourOf(it.c), it.a) : board.colourOf(it.c)) : "transparent"
                strokeWidth: it ? it.w : 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: board.pointsOf(it ? it.pts : [])
                }
            }
        }
    }

    Component {
        id: shapeC

        Shape {
            readonly property var it: parent ? parent.modelData : null

            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: it ? board.colourOf(it.c) : "transparent"
                strokeWidth: it ? it.w : 1
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: it ? board.shapePath(it.type, it.x1, it.y1, it.x2, it.y2, it.w) : ""
                }
            }
        }
    }

    Component {
        id: textC

        Text {
            readonly property var it: parent ? parent.modelData : null

            x: it ? it.x : 0
            y: it ? it.y : 0
            visible: it !== null && board.editId !== it.id
            text: it ? it.text : ""
            color: it ? board.colourOf(it.c) : "transparent"
            font.family: Appearance.fontFamily.body
            font.pixelSize: it ? (it.size ?? 22) : 22
            textFormat: Text.PlainText

            function report(): void {
                if (!it)
                    return;
                const m = board.measured;
                m[it.id] = {
                    w: implicitWidth,
                    h: implicitHeight
                };
            }
            onImplicitWidthChanged: report()
            onImplicitHeightChanged: report()
            Component.onCompleted: report()
        }
    }

    Component {
        id: noteC

        Item {
            id: note

            readonly property var it: parent ? parent.modelData : null
            readonly property bool fresh: it !== null && board.dropped === it.id

            x: it ? it.x : 0
            y: it ? it.y : 0
            width: it ? it.w : 200
            height: it ? it.h : 160
            rotation: it ? (it.tilt ?? 0) : 0
            visible: it !== null && board.editId !== it.id
            // a fresh note drops onto the sheet
            scale: 1
            Component.onCompleted: {
                if (note.fresh) {
                    note.scale = 0.55;
                    landing.start();
                    board.dropped = -1;
                }
            }

            NumberAnimation {
                id: landing

                target: note
                property: "scale"
                to: 1
                duration: 420
                easing.type: Easing.OutBack
                easing.overshoot: 2.6
            }

            // a soft shadow under the paper
            Rectangle {
                x: 3
                y: 5
                width: parent.width
                height: parent.height
                radius: 6
                color: Qt.rgba(0, 0, 0, 0.22)
            }
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: note.it ? note.it.c : "#ffe58a"
            }
            // the folded corner
            Shape {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 18
                height: 18
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: Qt.rgba(0, 0, 0, 0.12)
                    strokeColor: "transparent"
                    startX: 18
                    startY: 0
                    PathLine {
                        x: 0
                        y: 18
                    }
                    PathLine {
                        x: 0
                        y: 0
                    }
                }
            }
            Text {
                x: 14
                y: 14
                width: parent.width - 28
                height: parent.height - 28
                text: note.it ? note.it.text : ""
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                color: "#2a2520"
                font.family: Appearance.fontFamily.body
                font.pixelSize: 18
                textFormat: Text.PlainText
            }
        }
    }

    Component {
        id: imageC

        Image {
            id: pic

            readonly property var it: parent ? parent.modelData : null

            x: it ? it.x : 0
            y: it ? it.y : 0
            width: it && it.w > 0 ? it.w : 0
            height: it && it.h > 0 ? it.h : 0
            source: it ? `file://${it.src}` : ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true

            // a pasted picture takes its own shape, no wider than 420 at first
            onStatusChanged: {
                if (pic.status === Image.Ready && it && !(it.w > 0)) {
                    const iw = pic.implicitWidth, ih = pic.implicitHeight;
                    const k = Math.min(1, 420 / Math.max(1, iw));
                    Scratch.updateQuiet(it.id, {
                        w: Math.round(iw * k),
                        h: Math.round(ih * k)
                    });
                    Scratch.saveSoon();
                }
            }
        }
    }

    // a button of the toolbar: an icon (and a label), lit when its tool is on
    component ToolButton: Item {
        id: tb

        property string icon: ""
        property string label: ""
        property string tip: ""
        property bool on: false

        signal clicked

        opacity: tb.enabled ? 1 : 0.35

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: 7
            color: tb.on ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.ink, tbHover.hovered && tb.enabled ? 0.12 : 0)
            scale: tbTap.pressed ? 0.88 : (tbHover.hovered && tb.enabled ? 1.06 : 1)

            Behavior on scale {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutBack
                    easing.overshoot: 3
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 120
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: tb.icon !== ""
                name: tb.icon
                color: tb.on ? Colours.on(Colours.accent) : Colours.ink
                font.pixelSize: 17
            }
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: tb.label !== ""
                text: tb.label
                color: tb.on ? Colours.on(Colours.accent) : Colours.inkDim
                font.pixelSize: tb.icon !== "" ? 8 : Appearance.font.size.tiny
                tracking: 0.6
            }
        }

        HoverHandler {
            id: tbHover

            enabled: tb.enabled
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: tbTap

            enabled: tb.enabled
            onTapped: tb.clicked()
        }
    }
}
