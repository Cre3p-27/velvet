//  VELVET  ·  modules/map/MapCanvas.qml
//  The infinite canvas — your desktop and everything around it — as a plain
//  Item, so it lives where you open it: in the Dynamic Island, as its
//  DESKTOP module, in the island's own ground and shape; or on the
//  standalone map plate (WindowMap.qml) when the island is switched off.
//
//    · the desktop strip   one chip per desktop with a live miniature of
//                          its windows; click to go there, drop a window on
//                          one to send it there, scroll over it to flip
//    · the canvas          the monitor (with the wallpaper on it) and every
//                          window of this desktop, on the monitor and far
//                          out on the canvas around it, on a dot grid that
//                          moves with the camera; windows out of view show
//                          as arrows on the edge — click one and the camera
//                          flies there
//    · the cards           click to go to the window (the desktop pans it
//                          centred), drag to move it anywhere on the canvas,
//                          middle-click or × to close it, the second button
//                          floats or tiles it
//    · the controls        FIT shows the whole canvas, − and + zoom, the
//                          percentage and HOME land back on the monitor;
//                          the wheel zooms at the pointer, Shift+wheel and a
//                          touchpad pan, a double-click on bare canvas fits
//    · the keyboard        arrows pick a window, Enter goes, Del closes,
//                          F floats, B brings it here, 1–9 send it, + − 0
//                          zoom/fit, Home, Tab / PageUp / PageDown desktops
//
//  The camera model, the drag and the drop bookkeeping are the proven ones
//  of the old map; only their home moved.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root

    objectName: "mapCanvas"

    // Up and being looked at: polls the desktop and guards the desktop zoom.
    property bool live: false
    // The keyboard is ours: the cursor ring shows and handleKey() is fed.
    property bool keys: false
    // The host's ground, for the ink that sits on it.
    property color ground: Colours.surface

    signal poked
    signal closeRequested

    // The host must not close while a hand is on the canvas.
    readonly property bool busy: root.dragging || root.pointerDown

    function poke(): void {
        root.poked();
    }

    function close(): void {
        root.closeRequested();
    }

    readonly property color ink: Colours.ink
    readonly property color dim: Colours.inkDim

    // ──────────────────────────────────────────────────────────── the layout
    readonly property int stripH: 34
    readonly property int barH: 34
    readonly property int gap: 8

    // While the desktop pans to a clicked window, the cards are a moment
    // behind the world — they step aside for that beat and come back with
    // the next poll.
    property bool cardsDimmed: false

    // ──────────────────────────────────────────────────── which desktop is up
    readonly property var homeCell: Desk.homeCell
    readonly property int homeWs: root.homeCell ? root.homeCell.ws : 1

    // One chip per desktop: at least the configured count, and every
    // workspace Hyprland actually has, whichever is more.
    readonly property int tabCount: {
        let n = Config.map.desktops;
        for (let i = 0; i < Desk.cells.length; i++)
            n = Math.max(n, Desk.cells[i].ws);
        return n;
    }

    function windowsOn(ws: int): var {
        return root.frame.filter(w => (w?.ws ?? -1) === ws && !w.hidden);
    }

    // ───────────────────────────────────────────────────────────── the camera
    //  `zoom` is field pixels per canvas pixel; `panX/panY` is the point of
    //  the CANVAS in the middle of the field, in monitor-relative
    //  coordinates: the monitor's top-left is (0,0) and the canvas runs on
    //  forever in every direction. At rest the camera fits the monitor.
    property bool touched: false
    property real zoomRaw: 1
    property real panXRaw: 0
    property real panYRaw: 0

    readonly property real zoom: root.touched ? root.zoomRaw : field.homeZoom
    readonly property real panX: root.touched ? root.panXRaw : field.homeX
    readonly property real panY: root.touched ? root.panYRaw : field.homeY

    // Panning and dragging track the hand exactly; `snapping` lands the
    // camera without a glide; `glide` is how long a flight takes — short
    // for the wheel, longer for FIT, HOME and the edge arrows.
    property bool grabbing: false
    property bool snapping: false
    property int glide: 140

    Behavior on zoomRaw {
        enabled: !root.grabbing && !root.snapping
        NumberAnimation {
            duration: root.glide
            easing.type: Easing.OutCubic
        }
    }
    Behavior on panXRaw {
        enabled: !root.grabbing && !root.dragging && !root.snapping
        NumberAnimation {
            duration: root.glide
            easing.type: Easing.OutCubic
        }
    }
    Behavior on panYRaw {
        enabled: !root.grabbing && !root.dragging && !root.snapping
        NumberAnimation {
            duration: root.glide
            easing.type: Easing.OutCubic
        }
    }

    // A flight sets its own pace, then the wheel's snap comes back.
    function fly(ms: int): void {
        root.glide = ms;
        glideBack.restart();
    }

    Timer {
        id: glideBack

        interval: 360
        onTriggered: root.glide = 140
    }

    function takeCamera(): void {
        if (root.touched || !root.homeCell)
            return;
        root.snapping = true;
        root.zoomRaw = field.homeZoom;
        root.panXRaw = field.homeX;
        root.panYRaw = field.homeY;
        root.snapping = false;
        root.touched = true;
    }

    // HOME: fly back onto the monitor, then follow it again.
    function goHome(): void {
        root.poke();
        if (!root.touched)
            return;
        root.fly(300);
        root.zoomRaw = field.homeZoom;
        root.panXRaw = field.homeX;
        root.panYRaw = field.homeY;
        homeSettle.restart();
        Sfx.cursor();
    }

    Timer {
        id: homeSettle

        interval: 320
        onTriggered: root.touched = false
    }

    // FIT: the whole canvas — the monitor and every window of this desktop,
    // however far out — in view at once.
    function fitAll(): void {
        root.poke();
        homeSettle.stop();
        root.takeCamera();
        root.fly(320);
        const z = Math.max(field.minZoom, Math.min(field.maxZoom, field.fitContent));
        root.zoomRaw = z;
        root.panXRaw = root.clampX(field.contentX, z);
        root.panYRaw = root.clampY(field.contentY, z);
        Sfx.cursor();
    }

    function zoomBy(k: real): void {
        root.poke();
        homeSettle.stop();
        root.fly(200);
        root.setZoom(root.zoom * k, field.width / 2, field.height / 2);
    }

    function setZoom(next: real, atX: real, atY: real): void {
        homeSettle.stop();
        root.takeCamera();
        const before = root.zoomRaw;
        const z = Math.max(field.minZoom, Math.min(field.maxZoom, next));
        if (Math.abs(z - before) < 0.00001)
            return;
        // Keep whatever is under the pointer under the pointer. Both pans are
        // worked out first and assigned ONCE: a Behavior intercepts the write,
        // so a property still reads its old value on the next line, and a
        // clamp applied afterwards would read the pre-zoom pan and cancel the
        // whole correction.
        const wx = root.panXRaw + (atX - field.width / 2) / before;
        const wy = root.panYRaw + (atY - field.height / 2) / before;
        root.zoomRaw = z;
        root.panXRaw = root.clampX(wx - (atX - field.width / 2) / z, z);
        root.panYRaw = root.clampY(wy - (atY - field.height / 2) / z, z);

        // The two anchors: leaving the monitor pulls the camera out over the
        // whole canvas; returning lands it back on the monitor.
        if (z < field.homeZoom * 0.95) {
            root.panXRaw = root.clampX(field.contentX, z);
            root.panYRaw = root.clampY(field.contentY, z);
        } else if (z > field.homeZoom * 1.05) {
            root.panXRaw = root.clampX(field.homeX, z);
            root.panYRaw = root.clampY(field.homeY, z);
        }
    }

    function panBy(dx: real, dy: real): void {
        root.poke();
        homeSettle.stop();
        root.takeCamera();
        root.panXRaw = root.clampX(root.panXRaw + dx / root.zoomRaw, root.zoomRaw);
        root.panYRaw = root.clampY(root.panYRaw + dy / root.zoomRaw, root.zoomRaw);
    }

    // The canvas runs on forever, but the camera never drifts fully away
    // from the desktop and its windows: the view always overlaps them.
    function clampX(x: real, z: real): real {
        const c = root.homeCell;
        if (!c)
            return x;
        const r = field.contentRect;
        const hw = field.width / (2 * Math.max(0.0001, z));
        return Math.max(r.x0 - hw + c.w * 0.25, Math.min(r.x1 + hw - c.w * 0.25, x));
    }

    function clampY(y: real, z: real): real {
        const c = root.homeCell;
        if (!c)
            return y;
        const r = field.contentRect;
        const hh = field.height / (2 * Math.max(0.0001, z));
        return Math.max(r.y0 - hh + c.h * 0.25, Math.min(r.y1 + hh - c.h * 0.25, y));
    }

    onHomeWsChanged: {
        // The desktop changed: the camera comes home with you.
        homeSettle.stop();
        root.touched = false;
        root.cursor = 0;
    }

    // ───────────────────────────────────────────────────────── what is drawn
    //  A held copy of Desk.windows rather than the live list: the Repeater
    //  must not be rebuilt while a delegate holds the mouse grab, or the
    //  press dies mid-drag.
    property var frame: []
    // After a drop the landed position is trusted; hold the frame until the
    // fresh poll, so stale data cannot yank the card back.
    property bool holdFrame: false
    // The drop's position is trusted until a poll that STARTED after the
    // drop reports back.
    property int dropPollStart: -1
    property string landedAddr: ""

    // Landed-card patches go through a timer, never through a direct frame
    // write: rebuilding the Repeater inside the very handler that is still
    // running on one of its delegates is the classic dead-scope crash.
    property var pendingPatches: []

    function patchFrame(addr: string, fields: var): void {
        root.pendingPatches = root.pendingPatches.concat([{
                a: addr,
                f: fields
            }]);
        landFrame.restart();
    }

    // Re-float bookkeeping: if the compositor reverts a float mid-drag, the
    // map asks again — gently, and never forever.
    property real floatSentAt: 0
    property int floatTries: 0

    function floatNow(addr: string): void {
        Desk.floatFast(addr);
        root.floatSentAt = Date.now();
    }

    // The frame is rebuilt through this timer, never inside the handler
    // that caused the change: rebuilding the Repeater destroys the delegate
    // that is still running that handler, and the lines after the rebuild
    // then run in a dead scope. Thirty milliseconds is imperceptible — and
    // long enough for any handler to finish.
    Timer {
        id: landFrame

        interval: 30
        onTriggered: {
            if (root.pendingPatches.length === 0)
                return;
            const patches = root.pendingPatches;
            root.pendingPatches = [];
            root.frame = root.frame.map(w2 => {
                for (let i = 0; i < patches.length; i++)
                    if (w2.address === patches[i].a)
                        return Object.assign({}, w2, patches[i].f);
                return w2;
            });
        }
    }

    Timer {
        id: frameRefresh

        interval: 60
        onTriggered: {
            if (!root.dragging && !root.pointerDown && !root.holdFrame)
                root.refreshFrame();
        }
    }

    function refreshFrame(): void {
        // Only a poll that STARTED after the last drop may move the cards.
        // Counting completions is not enough: a poll already in flight when
        // the drop happened still describes the world before it.
        const fresh = Desk.pollStarted > root.dropPollStart;
        const next = Desk.windows;
        const cur = root.frame;
        let same = Array.isArray(cur) && cur.length === next.length;
        if (same)
            for (let i = 0; i < next.length; i++)
                if (cur[i].address !== next[i].address) {
                    same = false;
                    break;
                }
        if (same) {
            let changed = false;
            for (let i = 0; i < next.length; i++) {
                if ((cur[i].ws ?? -1) === root.homeWs && cur[i].hidden) {
                    cur[i].hidden = false;
                    changed = true;
                }
                if (fresh && JSON.stringify(cur[i]) !== JSON.stringify(Object.assign({}, cur[i], next[i]))) {
                    Object.assign(cur[i], next[i]);
                    changed = true;
                }
            }
            // a fresh array, so every binding that reads the frame sees it
            if (changed)
                root.frame = cur.slice();
        } else if (fresh) {
            root.frame = next;
        }
        if (fresh) {
            root.dropPollStart = -1;
            root.landedAddr = "";
        }
        root.cardsDimmed = false;
        glideRestore.stop();
    }

    Connections {
        target: Desk

        function onWindowsChanged(): void {
            root.holdFrame = false;
            frameRefresh.restart();
        }
    }

    // If the poll is slow after a pan, the cards come back on their own —
    // without touching positions: only a fresh poll may move them.
    Timer {
        id: glideRestore

        interval: 1500
        onTriggered: {
            root.cardsDimmed = false;
            root.holdFrame = false;
        }
    }

    // ──────────────────────────────────────────────────────── dragging a window
    property string dragAddr: ""
    property bool pointerDown: false
    property real dragWX: 0   // the card's top-left, in canvas coordinates
    property real dragWY: 0
    property int tabDropWs: 0 // the chip the pointer is over while dragging
    property real sentX: -999999
    property real sentY: -999999
    property bool floated: false

    readonly property bool dragging: root.dragAddr !== ""
    readonly property int dropWs: root.dragging ? root.tabDropWs : 0

    onDraggingChanged: {
        if (!root.dragging)
            frameRefresh.restart();
    }

    // One dispatch per frame at most, thirty a second: glued to the hand,
    // gentle on the socket.
    Timer {
        interval: 33
        repeat: true
        running: root.dragging
        onTriggered: root.pushDrag()
    }

    function pushDrag(): void {
        if (!root.dragging)
            return;
        const w = Desk.byAddress(root.dragAddr);
        if (!w)
            return;
        // We floated it for this drag. If the compositor reverted that, ask
        // again — gently — and keep sliding.
        if (root.floated && w.floating === false) {
            if (Date.now() - root.floatSentAt > 400 && root.floatTries < 10) {
                root.floatNow(root.dragAddr);
                root.floatTries = root.floatTries + 1;
            }
        }
        if (!(w.floating || root.floated))
            return;
        const c = Desk.cellFor(w.ws);
        if (!c)
            return;
        const x = Math.round(c.monX + root.dragWX);
        const y = Math.round(c.monY + root.dragWY);
        if (x === root.sentX && y === root.sentY)
            return;
        root.sentX = x;
        root.sentY = y;
        Desk.slideTo(root.dragAddr, x, y);
    }

    function endDrag(): void {
        const addr = root.dragAddr;
        const tabWs = root.tabDropWs;
        root.dragAddr = "";
        root.sentX = -999999;
        root.sentY = -999999;
        root.tabDropWs = 0;

        if (!addr) {
            root.floated = false;
            return;
        }

        const w = Desk.byAddress(addr);
        const placeable = w ? (w.floating || root.floated) : false;

        if (w && tabWs > 0 && tabWs !== w.ws) {
            // Sending it somewhere else works whether or not it floats, and
            // it lands in the middle of the other desktop.
            Desk.sendToWorkspace(addr, tabWs);
            Toast.ok(`MOVED TO DESKTOP ${tabWs}`);
            root.patchFrame(addr, {
                ws: tabWs,
                hidden: true
            });
            const target = Desk.cellFor(tabWs);
            if (placeable && target) {
                landing.address = addr;
                landing.px = Math.round(target.monX + (target.w - (w.w || 200)) / 2);
                landing.py = Math.round(target.monY + (target.h - (w.h || 120)) / 2);
                landing.restart();
            }
        } else if (w && placeable) {
            const c = Desk.cellFor(w.ws);
            if (c) {
                // The drop lands EXACTLY where the pointer is — the canvas
                // runs past the monitor's edges, and a window may be parked
                // out there. No clamp: the infinite canvas is the point.
                const px = Math.round(c.monX + root.dragWX);
                const py = Math.round(c.monY + root.dragWY);
                Desk.placeAt(addr, px, py);
                root.patchFrame(addr, {
                    x: px,
                    y: py
                });
                root.landedAddr = addr;
                refreeze.addr = addr;
                refreeze.restart();
            }
        }

        // Hold the frame until the fresh poll: a rebuild right now would
        // restore the stale pre-drop positions this handler just fixed.
        root.dropPollStart = Desk.pollStarted;
        root.holdFrame = true;
        Desk.watch();

        root.floated = false;
        Sfx.select();
    }

    // The workspace move has to land before the position does.
    Timer {
        id: landing

        property string address: ""
        property int px: 0
        property int py: 0

        interval: 200
        onTriggered: {
            if (landing.address)
                Desk.placeAt(landing.address, landing.px, landing.py);
        }
    }

    // One late check after a drop: if the compositor re-tiled the window,
    // float it back — "enable" is idempotent.
    Timer {
        id: refreeze

        property string addr: ""

        interval: 900
        onTriggered: {
            const w = Desk.byAddress(refreeze.addr);
            if (w && w.floating === false)
                Desk.floatFast(refreeze.addr);
        }
    }

    // ───────────────────────────────────────────────────────────── the keyboard
    property int cursor: 0
    // The cards you can reach: the ones on the desktop the canvas shows.
    readonly property var homes: root.frame.filter(w => (w?.ws ?? -1) === root.homeWs && !w.hidden)
    readonly property var picked: root.homes[Math.max(0, Math.min(root.homes.length - 1, root.cursor))] ?? null

    function step(dx: int, dy: int): void {
        root.poke();
        const list = root.homes;
        if (list.length === 0)
            return;
        const from = root.picked;
        if (!from) {
            root.cursor = 0;
            return;
        }
        // Nearest window in the direction you asked for, by where it actually
        // is on the canvas.
        const fx = from.x + from.w / 2;
        const fy = from.y + from.h / 2;
        let best = -1;
        let bestScore = Infinity;
        for (let i = 0; i < list.length; i++) {
            if (list[i] === from)
                continue;
            const ox = list[i].x + list[i].w / 2 - fx;
            const oy = list[i].y + list[i].h / 2 - fy;
            const along = dx !== 0 ? ox * dx : oy * dy;
            const across = dx !== 0 ? Math.abs(oy) : Math.abs(ox);
            if (along <= 8)
                continue;
            const score = along + across * 2;
            if (score < bestScore) {
                bestScore = score;
                best = i;
            }
        }
        if (best >= 0) {
            root.cursor = best;
            Sfx.cursor();
            root.reveal(list[best], false);
        }
    }

    // The keyboard, fed by the host (the island or the map plate owns the
    // focus). Returns whether the key was the canvas's.
    function handleKey(event: var): bool {
        root.poke();
        const w = root.picked;
        const k = event.key;
        if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Up || k === Qt.Key_Down) {
            root.step(k === Qt.Key_Left ? -1 : (k === Qt.Key_Right ? 1 : 0), k === Qt.Key_Up ? -1 : (k === Qt.Key_Down ? 1 : 0));
            return true;
        }
        if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            if (w)
                root.goTo(w);
            return true;
        }
        if (k === Qt.Key_Delete || k === Qt.Key_Backspace) {
            if (w)
                root.closeWin(w);
            return true;
        }
        if (k === Qt.Key_F) {
            if (w)
                root.toggleFloat(w);
            return true;
        }
        if (k === Qt.Key_B) {
            if (w)
                Desk.bringHere(w.address);
            return true;
        }
        if (k === Qt.Key_Home) {
            root.goHome();
            return true;
        }
        if (k === Qt.Key_0) {
            root.fitAll();
            return true;
        }
        if (k >= Qt.Key_1 && k <= Qt.Key_9) {
            if (w) {
                Desk.sendToWorkspace(w.address, k - Qt.Key_0);
                Toast.ok(`SENT TO DESKTOP ${k - Qt.Key_0}`);
            }
            return true;
        }
        if (k === Qt.Key_Plus || k === Qt.Key_Equal) {
            root.zoomBy(1.25);
            return true;
        }
        if (k === Qt.Key_Minus) {
            root.zoomBy(1 / 1.25);
            return true;
        }
        if (k === Qt.Key_Tab || k === Qt.Key_Backtab || k === Qt.Key_PageDown || k === Qt.Key_PageUp) {
            const back = k === Qt.Key_Backtab || k === Qt.Key_PageUp || (event.modifiers & Qt.ShiftModifier);
            root.flipDesktop(back ? -1 : 1);
            return true;
        }
        return false;
    }

    function flipDesktop(dir: int): void {
        const n = Math.max(1, root.tabCount);
        const next = ((root.homeWs - 1 + dir) % n + n) % n + 1;
        Sfx.cursor();
        Desk.goToWorkspace(next);
        Desk.refresh();
    }

    // Which desktop chip the pointer is over, asked from the dragged card's
    // own move handler (window coordinates). No hover involved — hover can
    // be gated during a press grab, position cannot.
    function tabAt(x: real, y: real): int {
        const p = chips.mapFromItem(null, x, y);
        if (p.y < -16 || p.y > chips.height + 16)
            return 0;
        let best = 0;
        let bestD = Infinity;
        for (let i = 0; i < chipRep.count; i++) {
            const t = chipRep.itemAt(i);
            if (!t)
                continue;
            const d = Math.abs(p.x - (t.x + t.width / 2));
            if (d < bestD) {
                bestD = d;
                best = t.ws;
            }
        }
        return best;
    }

    // Bring a window into view; `fly` = take the camera there visibly (an
    // edge arrow), otherwise only when the cursor walked out of the field.
    function reveal(win: var, flyThere: bool): void {
        if (!win)
            return;
        const c = root.homeCell;
        if (!c)
            return;
        const wx = win.x - c.monX + win.w / 2;
        const wy = win.y - c.monY + win.h / 2;
        const z = Math.max(0.0001, root.zoom);
        const hw = field.width / (2 * z);
        const hh = field.height / (2 * z);
        if (!flyThere && wx > root.panX - hw && wx < root.panX + hw && wy > root.panY - hh && wy < root.panY + hh)
            return;
        homeSettle.stop();
        root.takeCamera();
        root.fly(flyThere ? 360 : 200);
        // far out: pull back enough that the window and the monitor both fit
        let zz = root.zoomRaw;
        if (flyThere) {
            const spanX = Math.max(Math.abs(wx - c.w / 2) * 2 + win.w, c.w);
            const spanY = Math.max(Math.abs(wy - c.h / 2) * 2 + win.h, c.h);
            const fit = Math.min(field.width / spanX, field.height / spanY) * 0.9;
            if (fit < zz)
                zz = Math.max(field.minZoom, fit);
            root.zoomRaw = zz;
        }
        root.panXRaw = root.clampX(wx, zz);
        root.panYRaw = root.clampY(wy, zz);
    }

    // The whole point of clicking a card: YOU go to the window. The desktop
    // pans — every floating window on it shifts together — until the window
    // sits centred on its monitor. The map stays open.
    function goTo(win: var): void {
        if (!win)
            return;
        Sfx.select();
        root.cardsDimmed = true;
        glideRestore.restart();
        Desk.panTo(win.address);
    }

    function closeWin(win: var): void {
        if (!win)
            return;
        Sfx.close();
        Desk.closeWindow(win.address);
        root.patchFrame(win.address, {
            hidden: true
        });
    }

    function toggleFloat(win: var): void {
        if (!win)
            return;
        Sfx.select();
        Desk.toggleFloat(win.address);
        Toast.ok(win.floating ? "TILED AGAIN" : "FLOATING — DRAG IT ANYWHERE ON THE CANVAS");
        Desk.watch();
    }

    // The card under the pointer: one hover handler for the whole field, hit
    // tested here in the cards' own stacking order — per-card hover would
    // light every card of a pile at once.
    property real hoverX: -1
    property real hoverY: -1
    readonly property string hotAddr: {
        if (root.dragging || root.hoverX < 0 || !fieldHover.hovered)
            return "";
        const cx = field.toX(root.hoverX) + (field.cell?.monX ?? 0);
        const cy = field.toY(root.hoverY) + (field.cell?.monY ?? 0);
        let best = "";
        let bestZ = -1;
        const list = root.homes;
        for (let i = 0; i < list.length; i++) {
            const w = list[i];
            // cards never draw smaller than 16 × 12 field pixels
            const ww = Math.max(w.w, 16 / Math.max(0.0001, root.zoom));
            const wh = Math.max(w.h, 12 / Math.max(0.0001, root.zoom));
            if (cx < w.x || cx > w.x + ww || cy < w.y || cy > w.y + wh)
                continue;
            const z = (w.address === Desk.activeAddress ? 5 : 1) * 1000 + i;
            if (z > bestZ) {
                bestZ = z;
                best = w.address;
            }
        }
        return best;
    }
    // windows of this desktop that live off the monitor, out on the canvas
    readonly property int outside: {
        const c = root.homeCell;
        if (!c)
            return 0;
        return root.homes.filter(w => w.x + w.w <= c.monX || w.x >= c.monX + c.w || w.y + w.h <= c.monY || w.y >= c.monY + c.h).length;
    }
    readonly property var hotWin: root.hotAddr !== "" ? (root.homes.find(w => w.address === root.hotAddr) ?? null) : null

    // ─────────────────────────────────────────────────────────── live upkeep
    Timer {
        interval: 250
        repeat: true
        running: root.live
        triggeredOnStart: true
        onTriggered: Desk.watch()
    }

    // The desktop zoom (scripts/desktop_zoom.py) keeps a canvas state with
    // every floating window's ORIGINAL geometry. Opening the map restores
    // any active canvas zoom, and a marker keeps the wheel from starting a
    // new one underneath it.
    Process {
        id: zoomGuardOpen

        command: ["bash", "-c", 'touch /tmp/velvet-map-open && python3 "$1" resetcanvas', "velvet", Quickshell.shellPath("scripts/desktop_zoom.py")]
    }

    Process {
        id: zoomGuardClose

        command: ["bash", "-c", "rm -f /tmp/velvet-map-open"]
    }

    // Opening: the windows settle onto the canvas one after another.
    property real intro: 1

    NumberAnimation {
        id: introRun

        target: root
        property: "intro"
        from: 0
        to: 1
        duration: Math.round(620 * Appearance.motionK)
        easing.type: Easing.OutCubic
    }

    onLiveChanged: {
        if (!root.live) {
            root.dragAddr = "";
            root.tabDropWs = 0;
            root.pointerDown = false;
            root.grabbing = false;
            zoomGuardClose.running = false;
            zoomGuardClose.running = true;
            return;
        }
        zoomGuardOpen.running = false;
        zoomGuardOpen.running = true;
        if (Appearance.motionK > 0)
            introRun.restart();
        Desk.watch();
        root.refreshFrame();
        homeSettle.stop();
        root.touched = false;
        root.cursor = Math.max(0, root.homes.findIndex(w => w.address === Desk.activeAddress));
    }

    Component.onCompleted: {
        root.frame = Desk.windows;
        if (root.live)
            root.liveChanged();
    }

    Component.onDestruction: {
        if (root.live) {
            zoomGuardClose.running = false;
            zoomGuardClose.running = true;
        }
    }

    // ═══════════════════════════════════════════════════════ the desktop strip
    //  One chip per desktop: its number, a live miniature of where its
    //  windows sit, a count. Click to go there; drop a dragged window on a
    //  chip to send it there; scroll over the strip to flip desktops.
    Item {
        id: strip

        x: 0
        y: 0
        width: root.width
        height: root.stripH

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property real lastAt: 0

            onWheel: event => {
                const t = Date.now();
                if (t - lastAt < 180)
                    return;
                lastAt = t;
                root.poke();
                root.flipDesktop(event.angleDelta.y < 0 ? 1 : -1);
            }
        }

        Row {
            id: chips

            anchors.centerIn: parent
            spacing: 6

            Repeater {
                id: chipRep

                model: root.tabCount

                Item {
                    id: chip

                    required property int index
                    readonly property int ws: chip.index + 1
                    readonly property bool active: chip.ws === root.homeWs
                    readonly property var wins: root.windowsOn(chip.ws)
                    readonly property bool target: root.dragging && root.dropWs === chip.ws && !chip.active
                    readonly property var cellOf: Desk.cellFor(chip.ws) ?? root.homeCell

                    width: 62
                    height: 28
                    scale: chip.target ? 1.1 : (chipHover.hovered ? 1.04 : 1)

                    Behavior on scale {
                        SpringAnimation {
                            spring: 3.4
                            damping: 0.6
                            epsilon: 0.01
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.r(9)
                        color: chip.target ? Colours.alpha(Colours.accent, 0.32) : (chip.active ? Colours.alpha(Colours.accent, 0.16) : (chipHover.hovered ? Colours.alpha(root.ink, 0.08) : Colours.alpha(root.ink, 0.035)))
                        border.width: 1
                        border.color: chip.target ? Colours.accent : (chip.active ? Colours.alpha(Colours.accent, 0.7) : Colours.alpha(root.ink, chipHover.hovered ? 0.24 : 0.1))
                        antialiasing: true

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    P5Text {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: `${chip.ws}`
                        color: chip.active || chip.target ? Colours.accent : root.dim
                        font.pixelSize: Appearance.font.size.small
                        tracking: 0.4
                    }

                    // the miniature: where that desktop's windows sit
                    Item {
                        id: mini

                        readonly property real k: Math.min(width / Math.max(1, chip.cellOf?.w ?? 1), height / Math.max(1, chip.cellOf?.h ?? 1))

                        x: 22
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: 18
                        clip: true

                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            color: "transparent"
                            border.width: 1
                            border.color: Colours.alpha(chip.active ? Colours.accent : root.ink, chip.active ? 0.5 : 0.18)
                        }

                        Repeater {
                            model: chip.wins.slice(0, 8)

                            Rectangle {
                                required property var modelData

                                x: Math.max(-4, ((modelData?.x ?? 0) - (chip.cellOf?.monX ?? 0)) * mini.k)
                                y: Math.max(-4, ((modelData?.y ?? 0) - (chip.cellOf?.monY ?? 0)) * mini.k)
                                width: Math.max(3, (modelData?.w ?? 0) * mini.k)
                                height: Math.max(2, (modelData?.h ?? 0) * mini.k)
                                radius: 1
                                color: (modelData?.address ?? "") === Desk.activeAddress ? Colours.alpha(Colours.accent, 0.8) : Colours.alpha(root.ink, 0.42)
                            }
                        }
                    }

                    // Hover tooltip: what waits on that desktop.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 6
                        visible: chipHover.hovered && !root.dragging
                        width: tip.implicitWidth + 18
                        height: 22
                        radius: Appearance.r(7)
                        color: Colours.alpha(Colours.surface, 0.96)
                        border.width: 1
                        border.color: Colours.alpha(root.ink, 0.14)
                        z: 30

                        P5Text {
                            id: tip

                            anchors.centerIn: parent
                            text: {
                                const n = chip.wins.length;
                                if (n === 0)
                                    return `DESKTOP ${chip.ws}  ·  EMPTY`;
                                const names = chip.wins.slice(0, 3).map(w => `${w.cls || w.title}`.toUpperCase()).join(", ");
                                return `DESKTOP ${chip.ws}  ·  ${names}${n > 3 ? `  +${n - 3}` : ""}`;
                            }
                            color: root.dim
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 0.8
                        }
                    }

                    HoverHandler {
                        id: chipHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.poke();
                            if (chip.active) {
                                root.goHome();
                                return;
                            }
                            Sfx.select();
                            Desk.goToWorkspace(chip.ws);
                            Desk.refresh();
                        }
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ the canvas
    Rectangle {
        id: well

        x: 0
        y: root.stripH + root.gap
        width: root.width
        height: Math.max(40, root.height - root.stripH - root.barH - root.gap * 2)
        radius: Appearance.r(14)
        color: Colours.alpha(Qt.darker(root.ground, Colours.light ? 1.06 : 1.45), 0.9)
        border.width: 1
        border.color: Colours.alpha(root.ink, 0.08)
        antialiasing: true
    }

    Item {
        id: field

        objectName: "mapField"
        x: well.x + 1
        y: well.y + 1
        width: well.width - 2
        height: well.height - 2
        clip: true

        // The one desktop, in monitor-relative canvas coordinates: its
        // top-left is (0,0) and it is (cell.w × cell.h) big.
        readonly property var cell: root.homeCell

        // The zoom at which the monitor fills the field with a margin.
        readonly property real homeZoom: {
            const c = field.cell;
            if (!c || !(c.w > 0) || !(c.h > 0) || !(field.width > 1) || !(field.height > 1))
                return 0.1;
            return Math.min(field.width / c.w, field.height / c.h) * 0.9;
        }
        readonly property real homeX: field.cell ? field.cell.w / 2 : 0
        readonly property real homeY: field.cell ? field.cell.h / 2 : 0

        // The whole canvas: the monitor plus every window of this desktop,
        // however far out it lives.
        readonly property var contentRect: {
            const c = field.cell;
            if (!c)
                return {
                    x0: 0,
                    y0: 0,
                    x1: 1920,
                    y1: 1080
                };
            let x0 = 0;
            let y0 = 0;
            let x1 = c.w;
            let y1 = c.h;
            for (let i = 0; i < root.homes.length; i++) {
                const w = root.homes[i];
                const wx = (w?.x ?? 0) - c.monX;
                const wy = (w?.y ?? 0) - c.monY;
                x0 = Math.min(x0, wx);
                y0 = Math.min(y0, wy);
                x1 = Math.max(x1, wx + (w?.w ?? 0));
                y1 = Math.max(y1, wy + (w?.h ?? 0));
            }
            return {
                x0: x0,
                y0: y0,
                x1: x1,
                y1: y1
            };
        }
        readonly property real contentX: (field.contentRect.x0 + field.contentRect.x1) / 2
        readonly property real contentY: (field.contentRect.y0 + field.contentRect.y1) / 2
        readonly property bool spillsOver: field.contentRect.x0 < -4 || field.contentRect.y0 < -4 || field.contentRect.x1 > (field.cell?.w ?? 0) + 4 || field.contentRect.y1 > (field.cell?.h ?? 0) + 4

        readonly property real fitContent: {
            const r = field.contentRect;
            const rw = Math.max(1, r.x1 - r.x0);
            const rh = Math.max(1, r.y1 - r.y0);
            return Math.max(0.001, Math.min(Math.max(1, field.width) / rw, Math.max(1, field.height) / rh) * 0.88);
        }

        readonly property real minZoom: Math.min(field.homeZoom * 0.3, field.fitContent * 0.9)
        readonly property real maxZoom: field.homeZoom * 2.6

        // Canvas → field, and back.
        function sx(x: real): real {
            return field.width / 2 + (x - root.panX) * root.zoom;
        }
        function sy(y: real): real {
            return field.height / 2 + (y - root.panY) * root.zoom;
        }
        function toX(px: real): real {
            return root.panX + (px - field.width / 2) / root.zoom;
        }
        function toY(py: real): real {
            return root.panY + (py - field.height / 2) / root.zoom;
        }

        // ── the dot grid: it is the canvas — it moves and scales with the
        //    camera, so the plane reads as endless. One tiled picture under a
        //    scale, never thousands of items; coarser as you pull back.
        Item {
            id: grid

            // never an open-ended loop: a canvas created at size 0 has zoom 0
            // for a moment, and `while (s * 0 < 22)` froze the whole shell
            readonly property real stepC: {
                const z = Math.max(0.00001, root.zoom || 0);
                let s = 160;
                for (let i = 0; i < 12 && s * z < 22; i++)
                    s *= 4;
                return s;
            }
            readonly property real per: Math.max(4, grid.stepC * Math.max(0.00001, root.zoom || 0))
            readonly property real k: grid.per / 64
            readonly property real ox: ((field.sx(0) % grid.per) + grid.per) % grid.per
            readonly property real oy: ((field.sy(0) % grid.per) + grid.per) % grid.per

            anchors.fill: parent
            opacity: Colours.light ? 0.35 : 0.5

            Image {
                x: grid.ox - grid.per * 1.5
                y: grid.oy - grid.per * 1.5
                width: (field.width + grid.per * 3) / Math.max(0.01, grid.k)
                height: (field.height + grid.per * 3) / Math.max(0.01, grid.k)
                fillMode: Image.Tile
                smooth: true
                source: Colours.light ? "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64'><circle cx='32' cy='32' r='2.2' fill='%23000000' fill-opacity='0.5'/></svg>" : "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='64' height='64'><circle cx='32' cy='32' r='2.2' fill='%23ffffff' fill-opacity='0.34'/></svg>"
                sourceSize.width: 64
                sourceSize.height: 64

                transform: Scale {
                    xScale: grid.k
                    yScale: grid.k
                }
            }
        }

        // ── drag bare canvas to look around; a click lands home, a double
        //    click shows the whole canvas
        MouseArea {
            id: pan

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            cursorShape: pressed && moved ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            property real lastX: 0
            property real lastY: 0
            property bool moved: false

            onPressed: event => {
                lastX = event.x;
                lastY = event.y;
                root.pointerDown = true;
                moved = false;
                root.grabbing = true;
                root.poke();
            }

            onPositionChanged: event => {
                if (!pressed)
                    return;
                const dx = event.x - lastX;
                const dy = event.y - lastY;
                if (!moved && Math.abs(dx) + Math.abs(dy) < 3)
                    return;
                moved = true;
                homeSettle.stop();
                root.takeCamera();
                root.panXRaw = root.clampX(root.panXRaw - dx / root.zoomRaw, root.zoomRaw);
                root.panYRaw = root.clampY(root.panYRaw - dy / root.zoomRaw, root.zoomRaw);
                lastX = event.x;
                lastY = event.y;
            }

            onReleased: {
                root.grabbing = false;
                root.pointerDown = false;
                const wasClick = !pan.moved;
                pan.moved = false;
                if (wasClick)
                    clickWait.restart();
            }

            onDoubleClicked: {
                clickWait.stop();
                root.fitAll();
            }

            onCanceled: {
                root.grabbing = false;
                root.pointerDown = false;
                pan.moved = false;
            }
        }

        // a single click waits one beat for the second one
        Timer {
            id: clickWait

            interval: 240
            onTriggered: root.goHome()
        }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onWheel: event => {
                root.poke();
                const touchpad = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0;
                // a touchpad and Shift+wheel look around; the wheel (and
                // Ctrl with a touchpad) zooms at the pointer
                if ((touchpad && !(event.modifiers & Qt.ControlModifier)) || (event.modifiers & Qt.ShiftModifier)) {
                    const dx = touchpad ? -event.pixelDelta.x : -(event.angleDelta.y || event.angleDelta.x) * 0.6;
                    const dy = touchpad ? -event.pixelDelta.y : 0;
                    root.panBy(dx, dy);
                    return;
                }
                const d = event.angleDelta.y || event.pixelDelta.y;
                if (d === 0)
                    return;
                root.glide = 140;
                root.setZoom(root.zoom * (d > 0 ? 1.18 : 1 / 1.18), event.x, event.y);
            }
        }

        HoverHandler {
            id: fieldHover

            onPointChanged: {
                root.hoverX = fieldHover.point.position.x;
                root.hoverY = fieldHover.point.position.y;
            }
            onHoveredChanged: {
                if (!fieldHover.hovered) {
                    root.hoverX = -1;
                    root.hoverY = -1;
                }
            }
        }

        // ── the monitor: the wallpaper on it, so the canvas reads as YOUR
        //    desktop; a quiet accent frame and its number in the corner
        Item {
            id: monitor

            visible: field.cell !== null
            x: field.sx(0)
            y: field.sy(0)
            width: (field.cell?.w ?? 0) * root.zoom
            height: (field.cell?.h ?? 0) * root.zoom

            Rectangle {
                anchors.fill: parent
                anchors.margins: -10
                radius: Math.max(4, Math.min(16, 18 * root.zoom)) + 8
                color: Colours.alpha(Colours.accent, 0.05)
                visible: !root.touched || root.zoom < field.homeZoom * 1.2
            }

            Item {
                anchors.fill: parent
                clip: true

                Image {
                    anchors.fill: parent
                    visible: Config.map.previews
                    source: Config.wallpaper.current ? "file://" + Config.wallpaper.current : ""
                    sourceSize.width: 720
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    opacity: 0.62
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, Colours.light ? 0.06 : 0.28)
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: Math.max(2, Math.min(12, 16 * root.zoom))
                color: "transparent"
                border.width: 1.5
                border.color: Colours.alpha(Colours.accent, 0.55)
                antialiasing: true
            }

            Rectangle {
                visible: Config.map.showWorkspaceLabels
                x: 8
                y: 8
                width: deskLabel.implicitWidth + 14
                height: 20
                radius: Appearance.r(6)
                color: Colours.alpha(Qt.rgba(0, 0, 0, 1), 0.45)

                P5Text {
                    id: deskLabel

                    anchors.centerIn: parent
                    display: true
                    text: `DESKTOP ${root.homeWs}`
                    color: Colours.alpha(Colours.accent, 0.95)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }
            }

            // nothing on this desktop
            P5Text {
                anchors.centerIn: parent
                visible: root.homes.length === 0
                text: "NOTHING OPEN HERE"
                color: Colours.alpha("#ffffff", 0.7)
                font.pixelSize: Appearance.font.size.small
                tracking: 1.4
            }
        }

        // ── the windows — cards with their app's icon, on the monitor and
        //    on the canvas around it
        Repeater {
            model: root.frame

            Item {
                id: card

                required property var modelData
                required property int index

                objectName: `card-${card.win?.address ?? ""}`
                readonly property var win: card.modelData
                readonly property bool onHome: (card.win?.ws ?? -1) === root.homeWs
                readonly property bool hidden: (card.win?.hidden ?? false) === true

                readonly property bool isActive: (card.win?.address ?? "") === Desk.activeAddress
                readonly property bool isCursor: root.keys && card.win === root.picked
                readonly property bool isDragged: root.dragging && root.dragAddr === (card.win?.address ?? "-")
                readonly property bool isLanded: (card.win?.address ?? "") === root.landedAddr
                readonly property bool hot: (card.win?.address ?? "-") === root.hotAddr
                readonly property bool roomy: card.width >= 92 && card.height >= 48

                // its turn in the opening cascade, 0 → 1
                readonly property real arrive: Math.max(0, Math.min(1, root.intro * 1.8 - card.index * 0.12))

                visible: card.onHome && !card.hidden
                opacity: (root.cardsDimmed && !card.isDragged && !card.isLanded ? 0 : 1) * card.arrive

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                x: card.isDragged ? field.sx(root.dragWX) : field.sx((card.win?.x ?? 0) - (field.cell?.monX ?? 0))
                y: card.isDragged ? field.sy(root.dragWY) : field.sy((card.win?.y ?? 0) - (field.cell?.monY ?? 0))
                width: Math.max(16, (card.win?.w ?? 0) * root.zoom)
                height: Math.max(12, (card.win?.h ?? 0) * root.zoom)
                scale: (card.isDragged ? 1.03 : (card.hot ? 1.015 : 1)) * (0.9 + 0.1 * card.arrive)

                Behavior on scale {
                    SpringAnimation {
                        spring: 3
                        damping: 0.6
                        epsilon: 0.01
                    }
                }

                // The one under the pointer comes forward.
                z: card.isDragged ? 9 : (card.hot ? 8 : (card.isCursor ? 6 : (card.isActive ? 5 : 1)))

                // the lift: a soft shadow under the card
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: card.isDragged ? 8 : 3
                    anchors.leftMargin: 2
                    anchors.rightMargin: -2
                    anchors.bottomMargin: card.isDragged ? -10 : -4
                    radius: 7
                    color: Qt.rgba(0, 0, 0, card.isDragged ? 0.42 : 0.26)
                    visible: card.width > 30
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    visible: card.isCursor
                    color: "transparent"
                    border.width: 2
                    border.color: Colours.accent
                    radius: 8
                    antialiasing: true
                }

                // the active window glows
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: Math.min(9, card.height / 4) + 3
                    color: "transparent"
                    border.width: 3
                    border.color: Colours.alpha(Colours.accent, 0.22)
                    visible: card.isActive && !card.isDragged
                }

                Rectangle {
                    id: body

                    anchors.fill: parent
                    radius: Math.min(6, card.height / 4)
                    gradient: Gradient {
                        GradientStop {
                            position: 0
                            color: Colours.alpha(Colours.light ? Colours.surfaceHigh : Qt.lighter(Colours.surface, 1.55), card.hot || card.isDragged ? 0.98 : 0.93)
                        }
                        GradientStop {
                            position: 1
                            color: Colours.alpha(Colours.light ? Colours.surface : Qt.lighter(Colours.surface, 1.2), card.hot || card.isDragged ? 0.98 : 0.93)
                        }
                    }
                    border.width: card.isActive || card.isDragged ? 1.5 : 1
                    border.color: card.isDragged ? Colours.accent : (card.isActive ? Colours.alpha(Colours.accent, 0.9) : (card.hot ? Colours.alpha(Colours.accent, 0.65) : Colours.alpha(root.ink, 0.22)))
                    antialiasing: true
                    clip: true

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    // the title strip
                    Rectangle {
                        width: parent.width
                        height: Math.min(18, Math.max(5, card.height * 0.16))
                        color: card.isActive ? Colours.alpha(Colours.accent, 0.3) : Colours.alpha(root.ink, 0.07)

                        Row {
                            x: 5
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            visible: parent.height >= 13 && card.width >= 70

                            AppIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 11
                                height: 11
                                cls: card.win?.cls ?? ""
                            }

                            P5Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(0, card.width - 64)
                                text: `${card.win?.title || card.win?.cls || ""}`
                                color: Colours.alpha(root.ink, 0.78)
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // the app's icon in the middle — the card IS the window
                    AppIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: Math.min(9, card.height * 0.08)
                        width: Math.max(12, Math.min(48, Math.min(card.width, card.height) * 0.42))
                        height: width
                        visible: card.height >= 22 && card.width >= 22
                        cls: card.win?.cls ?? ""
                        opacity: card.hot ? 1 : 0.9
                    }

                    // tiled: a small grid mark in the corner
                    Icon {
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 3
                        visible: card.win?.floating === false && card.roomy
                        name: "grid_view"
                        color: Colours.alpha(root.ink, 0.45)
                        font.pixelSize: 11
                    }
                }

                // the name, under the card, while you point at it
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 6
                    visible: Config.map.showTitles && card.hot && !root.dragging
                    width: Math.min(320, nameTip.implicitWidth + 18)
                    height: 22
                    radius: Appearance.r(7)
                    color: Colours.alpha(Colours.surface, 0.96)
                    border.width: 1
                    border.color: Colours.alpha(Colours.accent, 0.4)
                    z: 20

                    P5Text {
                        id: nameTip

                        anchors.centerIn: parent
                        width: Math.min(302, implicitWidth)
                        text: card.win?.title || card.win?.cls || ""
                        color: root.ink
                        font.pixelSize: Appearance.font.size.tiny
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    id: cardArea

                    anchors.fill: parent
                    cursorShape: card.isDragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton

                    property bool moved: false
                    property real grabX: 0     // where inside the window you took hold
                    property real grabY: 0
                    property real pressX: 0    // where the press landed, to tell a
                    property real pressY: 0    // click from a drag, at any zoom

                    onPressed: event => {
                        cardArea.moved = false;
                        root.pointerDown = true;
                        root.poke();
                        cardArea.pressX = event.x;
                        cardArea.pressY = event.y;
                        if (event.button !== Qt.LeftButton)
                            return;
                        const p = cardArea.mapToItem(field, event.x, event.y);
                        cardArea.grabX = field.toX(p.x) - ((card.win?.x ?? 0) - (field.cell?.monX ?? 0));
                        cardArea.grabY = field.toY(p.y) - ((card.win?.y ?? 0) - (field.cell?.monY ?? 0));
                    }

                    onPositionChanged: event => {
                        if (!pressed || !(pressedButtons & Qt.LeftButton))
                            return;
                        const p = cardArea.mapToItem(field, event.x, event.y);
                        const wx = field.toX(p.x) - cardArea.grabX;
                        const wy = field.toY(p.y) - cardArea.grabY;

                        if (!cardArea.moved) {
                            const slip = Math.abs(event.x - cardArea.pressX) + Math.abs(event.y - cardArea.pressY);
                            if (slip < 6)
                                return;
                            cardArea.moved = true;
                            root.dragAddr = card.win?.address ?? "";
                            root.sentX = -999999;
                            root.sentY = -999999;
                            root.floated = false;

                            // Hyprland cannot move a tiled window by pixel.
                            // Dragging one plainly means "put it there", so
                            // float it — and say so once. "enable" is
                            // idempotent: a stale poll can never TILE it.
                            if (card.win?.floating === false) {
                                if (Config.map.dragFloats) {
                                    root.floatNow(root.dragAddr);
                                    root.floated = true;
                                    root.floatTries = 0;
                                    Desk.hintFloat();
                                } else {
                                    Toast.show("TILED  ·  DROP IT ON ANOTHER DESKTOP TO SEND IT THERE  ·  F FLOATS IT", "info", 3000);
                                }
                            }
                        }

                        root.dragWX = wx;
                        root.dragWY = wy;
                        const g = cardArea.mapToItem(null, event.x, event.y);
                        const t = root.tabAt(g.x, g.y);
                        if (t !== root.tabDropWs)
                            root.tabDropWs = t;
                    }

                    onReleased: event => {
                        if (cardArea.moved) {
                            const g = cardArea.mapToItem(null, event.x, event.y);
                            const t = root.tabAt(g.x, g.y);
                            if (t > 0)
                                root.tabDropWs = t;
                            root.endDrag();
                            cardArea.moved = false;
                            root.pointerDown = false;
                            return;
                        }
                        root.pointerDown = false;
                        root.tabDropWs = 0;
                        if (event.button === Qt.MiddleButton) {
                            root.closeWin(card.win);
                            return;
                        }
                        // A plain click is the whole point of the map: you
                        // go to the window, the desktop pans it centred.
                        frameRefresh.restart();
                        if (Config.map.clickFocuses)
                            root.goTo(card.win);
                        else
                            root.close();
                    }

                    onCanceled: {
                        if (cardArea.moved)
                            root.endDrag();
                        cardArea.moved = false;
                        root.pointerDown = false;
                        root.tabDropWs = 0;
                    }
                }

                // the hands on a card you point at: float/tile, close
                Row {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: Math.min(18, Math.max(5, card.height * 0.16)) + 4
                    anchors.rightMargin: 4
                    spacing: 4
                    visible: card.hot && card.roomy && !root.dragging
                    z: 3

                    Repeater {
                        model: [
                            {
                                icon: card.win?.floating ? "grid_view" : "picture_in_picture",
                                act: "float"
                            },
                            {
                                icon: "close",
                                act: "close"
                            }
                        ]

                        Rectangle {
                            id: act

                            required property var modelData

                            width: 20
                            height: 20
                            radius: 10
                            color: actArea.pressed ? Colours.accent : (act.modelData.act === "close" ? Colours.alpha("#d6293e", 0.85) : Colours.alpha(Qt.rgba(0, 0, 0, 1), 0.55))
                            border.width: 1
                            border.color: Colours.alpha("#ffffff", 0.22)

                            Icon {
                                anchors.centerIn: parent
                                name: act.modelData.icon
                                color: "#ffffff"
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: actArea

                                anchors.fill: parent
                                anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.poke();
                                    if (act.modelData.act === "close")
                                        root.closeWin(card.win);
                                    else
                                        root.toggleFloat(card.win);
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── windows out of view: an arrow on the edge of the field points at
        //    each one; click it and the camera flies there
        Repeater {
            model: root.homes

            Item {
                id: beacon

                required property var modelData

                readonly property var win: beacon.modelData
                readonly property real cx: field.sx((beacon.win?.x ?? 0) - (field.cell?.monX ?? 0) + (beacon.win?.w ?? 0) / 2)
                readonly property real cy: field.sy((beacon.win?.y ?? 0) - (field.cell?.monY ?? 0) + (beacon.win?.h ?? 0) / 2)
                readonly property real hw: (beacon.win?.w ?? 0) * root.zoom / 2
                readonly property real hh: (beacon.win?.h ?? 0) * root.zoom / 2
                readonly property bool out: beacon.cx + beacon.hw < 0 || beacon.cx - beacon.hw > field.width || beacon.cy + beacon.hh < 0 || beacon.cy - beacon.hh > field.height
                readonly property real ang: Math.atan2(beacon.cy - field.height / 2, beacon.cx - field.width / 2)

                visible: beacon.out && !root.dragging
                width: 30
                height: 30
                x: Math.max(6, Math.min(field.width - 36, beacon.cx - 15))
                y: Math.max(6, Math.min(field.height - 36, beacon.cy - 15))
                z: 12

                Rectangle {
                    anchors.fill: parent
                    radius: 15
                    color: beaconArea.containsPress ? Colours.accent : Colours.alpha(Colours.surface, 0.94)
                    border.width: 1
                    border.color: Colours.alpha(Colours.accent, beaconHover.hovered ? 0.95 : 0.55)
                    scale: beaconHover.hovered ? 1.12 : 1

                    Behavior on scale {
                        SpringAnimation {
                            spring: 3.4
                            damping: 0.6
                            epsilon: 0.01
                        }
                    }

                    AppIcon {
                        anchors.centerIn: parent
                        width: 17
                        height: 17
                        cls: beacon.win?.cls ?? ""
                    }
                }

                // the arrow, on the rim, pointing out to where it is
                Icon {
                    x: 15 + Math.cos(beacon.ang) * 19 - width / 2
                    y: 15 + Math.sin(beacon.ang) * 19 - height / 2
                    name: "chevron_right"
                    rotation: beacon.ang * 180 / Math.PI
                    color: Colours.accent
                    font.pixelSize: 14
                }

                HoverHandler {
                    id: beaconHover
                }

                MouseArea {
                    id: beaconArea

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sfx.cursor();
                        root.poke();
                        root.reveal(beacon.win, true);
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ the controls
    Item {
        id: bar

        x: 0
        y: root.height - root.barH
        width: root.width
        height: root.barH

        // what is going on — or what you can do here
        P5Text {
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.right: tools.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            // the most useful line first; on a narrow map the tail elides
            text: {
                const n = root.homes.length;
                const where = `DESKTOP ${root.homeWs}  ·  ${n} WINDOW${n === 1 ? "" : "S"}`;
                if (root.dragging)
                    return root.dropWs > 0 ? `RELEASE: TO DESKTOP ${root.dropWs}` : "RELEASE TO PLACE IT  ·  ON A CHIP TO SEND IT";
                if (root.hotWin)
                    return `${`${root.hotWin.cls || root.hotWin.title}`.toUpperCase()}  ·  CLICK GOES  ·  DRAG MOVES`;
                if (n === 0)
                    return `${where}  ·  CHIPS SWITCH`;
                if (root.outside > 0 && !root.touched)
                    return `${where}  ·  ${root.outside} OUT THERE — FIT`;
                return root.keys ? `${where}  ·  ARROWS · ENTER · 0 FITS` : `${where}  ·  SCROLL ZOOMS`;
            }
            color: root.dragging ? Colours.alpha(Colours.accent, 0.95) : Colours.alpha(root.dim, 0.9)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.1
        }

        Row {
            id: tools

            anchors.right: parent.right
            anchors.rightMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Repeater {
                model: [
                    {
                        id: "fit",
                        icon: "zoom_out_map",
                        label: "FIT"
                    },
                    {
                        id: "out",
                        icon: "remove",
                        label: ""
                    },
                    {
                        id: "pct",
                        icon: "",
                        label: "%"
                    },
                    {
                        id: "in",
                        icon: "add",
                        label: ""
                    },
                    {
                        id: "home",
                        icon: "filter_center_focus",
                        label: "HOME"
                    }
                ]

                Rectangle {
                    id: tool

                    required property var modelData

                    objectName: `tool-${tool.modelData.id}`
                    readonly property bool lit: (tool.modelData.id === "home" && !root.touched) || (tool.modelData.id === "fit" && field.spillsOver && !root.touched)

                    width: Math.max(28, toolRow.implicitWidth + 16)
                    height: 26
                    radius: Appearance.pill(26)
                    color: toolArea.pressed ? Colours.alpha(Colours.accent, 0.4) : (toolHover.hovered ? Colours.alpha(root.ink, 0.12) : Colours.alpha(root.ink, 0.05))
                    border.width: 1
                    border.color: tool.lit ? Colours.alpha(Colours.accent, 0.7) : Colours.alpha(root.ink, toolHover.hovered ? 0.24 : 0.1)
                    scale: toolArea.pressed ? 0.94 : 1

                    Behavior on scale {
                        SpringAnimation {
                            spring: 4
                            damping: 0.5
                            epsilon: 0.01
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    Row {
                        id: toolRow

                        anchors.centerIn: parent
                        spacing: 4

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tool.modelData.icon !== ""
                            name: tool.modelData.icon
                            color: tool.lit ? Colours.accent : root.ink
                            font.pixelSize: 15
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: tool.modelData.label !== ""
                            display: true
                            // the model stays fixed (a model that changes with
                            // the zoom rebuilt the buttons under the pointer)
                            text: tool.modelData.id === "pct" ? `${Math.round(root.zoom / Math.max(0.0001, field.homeZoom) * 100)}%` : tool.modelData.label
                            color: tool.lit ? Colours.accent : root.dim
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 0.8
                        }
                    }

                    HoverHandler {
                        id: toolHover
                    }

                    MouseArea {
                        id: toolArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            switch (tool.modelData.id) {
                            case "fit":
                                root.fitAll();
                                break;
                            case "out":
                                root.zoomBy(1 / 1.3);
                                break;
                            case "in":
                                root.zoomBy(1.3);
                                break;
                            default:
                                root.goHome();
                            }
                        }
                    }
                }
            }
        }
    }
}
