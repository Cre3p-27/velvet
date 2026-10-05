//  VELVET  ·  modules/map/WindowMap.qml
//  The mini desktop — cozy and minimal, no live video.
//
//  A small plate, centred under the top edge, showing YOUR desktop: the
//  monitor drawn as a quiet frame, and every window of this desktop as a
//  simple named card — on the monitor, and on the infinite canvas around
//  it (windows live far outside the edges; peaclock sits at x −3165).
//
//  At rest the camera fits the monitor. Zoom out and it pulls back — by
//  itself it keeps going until every window of this desktop fits the
//  field, the canvas and the monitor together, panning itself to the
//  middle of it all. Zoom in lands back on the monitor. Drag the empty
//  space to look around; Home snaps back.
//
//  The other desktops live only in the numbered tab row: click a tab to
//  go there, drag a window onto a tab to send it there.
//
//  Click a card and YOU go to the window — it is focused, never moved
//  for you. Drag a card to move its window, anywhere on the canvas.
//  Click the bare desktop or anywhere off the plate to dismiss.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property bool pinned: Panels.windowMap
    readonly property bool mine: root.modelData === Hypr.focusedScreen
    // Opened by reaching for the edge (EdgeSensor) — takes no keyboard.
    readonly property bool hovered: Panels.mapHover !== "" && Panels.mapHover === (root.modelData?.name ?? "")

    // Opened on purpose on the screen you are looking at, or reached for with
    // the pointer on this one. Never on every monitor at once.
    readonly property bool shown: (root.pinned && root.mine) || root.hovered

    // While the desktop pans to a clicked window, the cards are a moment
    // behind the world — they step aside for that beat and come back with
    // the next poll.
    property bool cardsDimmed: false

    // ──────────────────────────────────────────────────── which desktop is up
    readonly property var homeCell: Desk.homeCell
    readonly property int homeWs: root.homeCell ? root.homeCell.ws : 1

    // The tabs: one per desktop. At least the configured count, and every
    // workspace Hyprland actually has, whichever is more.
    readonly property int tabCount: {
        let n = Config.map.desktops;
        for (let i = 0; i < Desk.cells.length; i++)
            n = Math.max(n, Desk.cells[i].ws);
        return n;
    }

    // ───────────────────────────────────────────────────────────── the camera
    //  `zoom` is plate pixels per canvas pixel; `panX/panY` is the point of
    //  the CANVAS in the middle of the field, in monitor-relative
    //  coordinates: the monitor's top-left is (0,0) and the canvas runs on
    //  forever in every direction. At rest the camera fits the monitor.
    //  Zooming OUT pulls it back until the WHOLE canvas — monitor and every
    //  window of this desktop, however far out — fits the field, panning
    //  itself to the middle of it all. Zooming IN lands back on the monitor.
    property bool touched: false
    property real zoomRaw: 1
    property real panXRaw: 0
    property real panYRaw: 0

    readonly property real zoom: root.touched ? root.zoomRaw : field.homeZoom
    readonly property real panX: root.touched ? root.panXRaw : field.homeX
    readonly property real panY: root.touched ? root.panYRaw : field.homeY

    // Panning and dragging have to track the pointer exactly; easing them puts
    // the plate behind your hand. `snapping` is the other exception: taking
    // the camera has to LAND on the home view, not glide towards it.
    property bool grabbing: false
    property bool snapping: false

    Behavior on zoomRaw {
        enabled: !root.grabbing && !root.snapping
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutQuad
        }
    }
    Behavior on panXRaw {
        enabled: !root.grabbing && !root.dragging && !root.snapping
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutQuad
        }
    }
    Behavior on panYRaw {
        enabled: !root.grabbing && !root.dragging && !root.snapping
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutQuad
        }
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

    function goHome(): void {
        root.touched = false;
        Sfx.cursor();
    }

    function setZoom(next: real, atX: real, atY: real): void {
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

    // The canvas runs on forever, but the camera never drifts fully away
    // from the desktop: at least a quarter of the monitor stays in view.
    function clampX(x: real, z: real): real {
        const c = root.homeCell;
        if (!c)
            return x;
        const hw = field.width / (2 * Math.max(0.0001, z));
        return Math.max(-hw + c.w * 0.25, Math.min(c.w + hw - c.w * 0.25, x));
    }

    function clampY(y: real, z: real): real {
        const c = root.homeCell;
        if (!c)
            return y;
        const hh = field.height / (2 * Math.max(0.0001, z));
        return Math.max(-hh + c.h * 0.25, Math.min(c.h + hh - c.h * 0.25, y));
    }

    onHomeWsChanged: {
        // The desktop changed: the camera comes home with you.
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
            // A FRESH array with the landed positions patched in: the
            // Repeater rebuilds from it, so the update reaches the screen
            // guaranteed, no matter how the engine tracks object writes.
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
            for (let i = 0; i < next.length; i++) {
                if ((cur[i].ws ?? -1) === root.homeWs)
                    cur[i].hidden = false;
                if (fresh)
                    Object.assign(cur[i], next[i]);
            }
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
    property int tabDropWs: 0 // the tab the pointer is over while dragging
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
        // again — gently — and keep sliding: the float lands in
        // milliseconds and the slides right behind it take.
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
            // the position travels with it — the same spot on the new
            // desktop, canvas included.
            Desk.sendToWorkspace(addr, tabWs);
            Toast.ok(`MOVED TO WORKSPACE ${tabWs}`);
            // The card leaves this desktop now, not when the poll lands —
            // via the safe timer path, so the rebuild never runs inside
            // this handler.
            root.patchFrame(addr, {
                ws: tabWs,
                hidden: true
            });
            const target = Desk.cellFor(tabWs);
            if (placeable && target) {
                landing.address = addr;
                // Centred on the target monitor — a window moved to another
                // desktop should land in the middle of it, not wherever the
                // drag happened to end.
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
                // Land the card right here, right now (via the safe timer
                // path): the drop point is the truth, and only a poll that
                // STARTED after this drop may move the card again.
                root.patchFrame(addr, {
                    x: px,
                    y: py
                });
                root.landedAddr = addr;
                // Safety net: if anything re-tiled the window mid-drag, the
                // next poll shows it tiled — check once and re-float.
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
    // float it back — "enable" is idempotent, so this never harms a
    // window that is already floating.
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
    // The cards you can reach: the ones on the desktop the plate shows.
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
            root.reveal(list[best]);
        }
    }

    // Which desktop's tab the pointer is over, asked from the dragged card's
    // own move handler. No hover state involved — hover can be gated during
    // a press grab, position cannot.
    function tabAt(x: real, y: real): int {
        // `null` = the root QML view — the window's own coordinate space.
        const p = tabsRow.mapFromItem(null, x, y);
        if (p.y < -14 || p.y > tabsRow.height + 14)
            return 0;
        let best = 0;
        let bestD = Infinity;
        for (let i = 0; i < tabsRep.count; i++) {
            const t = tabsRep.itemAt(i);
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

    // Keep the keyboard cursor inside the field.
    function reveal(win: var): void {
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
        if (wx > root.panX - hw && wx < root.panX + hw && wy > root.panY - hh && wy < root.panY + hh)
            return;
        root.takeCamera();
        root.panXRaw = root.clampX(wx, root.zoomRaw);
        root.panYRaw = root.clampY(wy, root.zoomRaw);
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

    // ═══════════════════════════════════════════════════════════════ the window
    screen: modelData
    color: "transparent"
    WlrLayershell.namespace: "velvet-map"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.pinned && root.mine ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: -1

    visible: Config.map.enabled

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // Input while open, silence while closed. OPENING is the EdgeSensor's
    // job — a dedicated strip window beside this one, shaped like the bar.
    // When closed, this window eats NOTHING.
    mask: Region {
        item: root.shown ? inputArea : deadZone
    }

    Item {
        id: inputArea

        anchors.fill: parent
    }

    Item {
        id: deadZone

        width: 0
        height: 0
    }

    // Everything that counts as "still using the map".
    Item {
        id: shield

        readonly property int span: Math.max(plate.width + 44, Math.max(80, Config.map.edgeWidth) + 44)

        x: Math.round((root.width - shield.span) / 2)
        y: 0
        width: shield.span
        height: plate.y + plate.height + 28

        z: 50

        HoverHandler {
            id: plateHover

            onHoveredChanged: {
                if (hovered)
                    closeTimer.stop();
                else
                    closeTimer.restart();
            }
        }
    }

    Timer {
        id: closeTimer
        interval: Config.map.closeDelay

        // The ONLY way the map closes: the pointer leaves the plate and its
        // margin. Clicking windows, desktops or tabs never closes it.
        onTriggered: {
            if (plateHover.hovered)
                return;
            if (root.dragging) {
                closeTimer.restart();
                return;
            }
            root.closeQuiet();
        }
    }

    function close(): void {
        Sfx.close();
        Panels.windowMap = false;
        Panels.mapHover = "";
    }

    function closeQuiet(): void {
        Panels.windowMap = false;
        Panels.mapHover = "";
    }

    // Hard watchdog: three quiet minutes close the map, pinned or not.
    Timer {
        id: openWatchdog

        interval: 180000
        onTriggered: {
            console.warn("MAP: watchdog closed the map after three quiet minutes");
            root.closeQuiet();
        }
    }

    function poke(): void {
        openWatchdog.restart();
    }

    onPinnedChanged: {
        if (root.pinned)
            Sfx.open();
        else
            Panels.mapHover = "";
    }

    // Keep the window data fresh while the map is up.
    Timer {
        interval: 250
        repeat: true
        running: root.shown
        triggeredOnStart: true
        onTriggered: Desk.watch()
    }

    // The desktop zoom (scripts/desktop_zoom.py) keeps a canvas state with
    // every floating window's ORIGINAL geometry. Opening the map restores
    // any active canvas zoom, and a marker keeps the wheel from starting a
    // new one underneath it.
    Process {
        id: zoomGuardOpen

        // resetcanvas, not reset: undo the canvas zoom but leave the user's
        // cursor zoom alone (see reset_canvas() in the script). The path
        // comes from the shell, not from one user's home folder.
        command: ["bash", "-c", 'touch /tmp/velvet-map-open && python3 "$1" resetcanvas', "velvet", Quickshell.shellPath("scripts/desktop_zoom.py")]
    }

    Process {
        id: zoomGuardClose

        command: ["bash", "-c", "rm -f /tmp/velvet-map-open"]
    }

    onShownChanged: {
        if (!root.shown) {
            root.dragAddr = "";
            root.tabDropWs = 0;
            openWatchdog.stop();
            zoomGuardClose.running = false;
            zoomGuardClose.running = true;
            return;
        }
        zoomGuardOpen.running = false;
        zoomGuardOpen.running = true;
        openWatchdog.restart();
        Desk.watch();
        frameRefresh.restart();
        root.touched = false;
        root.cursor = Math.max(0, root.homes.findIndex(w => w.address === Desk.activeAddress));
        if (root.pinned)
            keyboard.forceActiveFocus();
        else
            closeTimer.restart();   // reached for but never entered: let it go again
    }

    // The map is created when it is first needed (shell.qml, Parked), by which
    // time `shown` is already true and has gone by: say it once more.
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (root.shown)
                root.shownChanged();
        }
    }

    // An opened-on-purpose map still has to be dismissable with the mouse:
    // a click off the plate closes it (it used to swallow every click).
    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        onPressed: {
            if (root.pinned && !plateHover.hovered)
                root.close();
        }
    }

    Item {
        id: keyboard

        anchors.fill: parent
        focus: root.pinned && root.mine

        Keys.onEscapePressed: root.close()
        Keys.onLeftPressed: root.step(-1, 0)
        Keys.onRightPressed: root.step(1, 0)
        Keys.onUpPressed: root.step(0, -1)
        Keys.onDownPressed: root.step(0, 1)

        Keys.onReturnPressed: {
            const w = root.picked;
            if (!w)
                return;
            root.goTo(w);
        }

        Keys.onPressed: event => {
            root.poke();
            const w = root.picked;

            if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
                if (w)
                    Desk.closeWindow(w.address);
                event.accepted = true;
            } else if (event.key === Qt.Key_F) {
                if (w)
                    Desk.toggleFloat(w.address);
                event.accepted = true;
            } else if (event.key === Qt.Key_B) {
                if (w)
                    Desk.bringHere(w.address);
                event.accepted = true;
            } else if (event.key === Qt.Key_Home) {
                root.goHome();
                event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                if (w) {
                    Desk.sendToWorkspace(w.address, event.key - Qt.Key_0);
                    Toast.ok(`SENT TO WORKSPACE ${event.key - Qt.Key_0}`);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
                root.setZoom(root.zoom * 1.25, field.width / 2, field.height / 2);
                event.accepted = true;
            } else if (event.key === Qt.Key_Minus) {
                root.setZoom(root.zoom / 1.25, field.width / 2, field.height / 2);
                event.accepted = true;
            }
        }
    }

    // ═════════════════════════════════════════════════════════════════ the plate
    Item {
        id: plate

        readonly property int pad: 13
        readonly property int footer: 24

        readonly property real aspect: {
            const m = Desk.focusedMonitor;
            if (m && m.h > 0)
                return m.w / m.h;
            return root.width / Math.max(1, root.height);
        }

        readonly property int roomW: Math.max(240, root.width - 64)
        readonly property int roomH: Math.max(160, root.height - 60 - plate.pad * 2 - plate.footer)

        readonly property int innerW: {
            const want = Math.min(plate.roomW, Math.round(root.width * Config.map.plateWidth));
            return Math.max(240, Math.round(Math.min(want, plate.roomH * plate.aspect)));
        }
        readonly property int innerH: Math.max(140, Math.round(plate.innerW / Math.max(0.3, plate.aspect)))

        width: plate.innerW + plate.pad * 2
        height: plate.innerH + plate.pad * 2 + plate.footer
        x: Math.round((root.width - width) / 2)
        y: 14

        opacity: root.shown ? 1 : 0
        visible: opacity > 0.01

        transform: Translate {
            y: root.shown ? 0 : -plate.height - 30

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutExpo
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Colours.alpha(Colours.surface, 0.97)
            antialiasing: true

            // The house texture — every panel in the shell carries it.
            Halftone {
                anchors.fill: parent
                strength: 0.03
                density: 1.6
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Colours.alpha(Colours.ink, 0.14)
                antialiasing: true
            }
        }

        // ═══════════════════════════════════════════════════════════ the tabs
        //  One numbered tab per desktop, across the top of the plate. Click
        //  a tab to go there; drag a window onto a tab to send it there.
        //  The little dot means windows live on that desktop.
        Row {
            id: tabsRow

            anchors.top: parent.top
            anchors.topMargin: 9
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            height: 22

            Repeater {
                id: tabsRep

                model: root.tabCount

                Item {
                    id: tab

                    required property int index
                    readonly property int ws: tab.index + 1
                    readonly property bool active: tab.ws === root.homeWs
                    readonly property bool occupied: root.frame.some(w => (w?.ws ?? -1) === tab.ws)

                    width: tab.ws >= 10 ? 26 : 22
                    height: 22

                    Plate {
                        anchors.fill: parent
                        radius: Appearance.r(6)
                        color: tab.active ? Colours.alpha(Colours.accent, 0.16) : (tabHover.hovered ? Colours.alpha(Colours.surfaceHigh, 0.9) : "transparent")
                        border.width: 1
                        border.color: tab.active ? Colours.alpha(Colours.accent, 0.75) : (tabHover.hovered ? Colours.alpha(Colours.ink, 0.22) : Colours.alpha(Colours.ink, 0.1))
                        antialiasing: true
                    }

                    P5Text {
                        anchors.centerIn: parent
                        display: true
                        text: `${tab.ws}`
                        color: tab.active ? Colours.accent : Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 0.4
                    }

                    // Occupied dot.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        width: 4
                        height: 4
                        radius: 2
                        visible: tab.occupied && !tab.active && !tabHover.hovered
                        color: Colours.alpha(Colours.inkDim, 0.7)
                    }

                    // Hover tooltip: what waits on that desktop.
                    Plate {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 4
                        visible: tabHover.hovered
                        width: tabTip.contentWidth + 16
                        height: 20
                        radius: Appearance.r(6)
                        color: Colours.alpha(Colours.surface, 0.94)
                        border.width: 1
                        border.color: Colours.alpha(Colours.ink, 0.12)
                        antialiasing: true

                        P5Text {
                            id: tabTip

                            readonly property int count: root.frame.filter(w => w.ws === tab.ws).length

                            anchors.centerIn: parent
                            display: true
                            text: `DESKTOP ${tab.ws}  ·  ${tabTip.count} WINDOW${tabTip.count === 1 ? "" : "S"}`
                            color: Colours.alpha(Colours.inkDim, 0.85)
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1
                        }
                    }

                    // Only the hover tint. The drop target comes from the
                    // dragged card's position (tabAt), not from hover.
                    HoverHandler {
                        id: tabHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.poke();
                            if (tab.active) {
                                Sfx.back();
                                return;
                            }
                            Sfx.select();
                            Desk.goToWorkspace(tab.ws);
                            Desk.refresh();
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════ the field
        Item {
            id: field

            x: plate.pad
            y: plate.pad + 36
            width: plate.innerW
            height: plate.innerH - 36
            clip: true

            // The one desktop, in monitor-relative canvas coordinates: its
            // top-left is (0,0) and it is (cell.w × cell.h) big. The canvas
            // itself runs on forever — zooming out shows what lies around.
            readonly property var cell: root.homeCell

            // The zoom at which the monitor exactly fills the field.
            readonly property real homeZoom: {
                const c = field.cell;
                if (!c || !(c.w > 0) || !(c.h > 0))
                    return 1;
                return Math.min(field.width / c.w, field.height / c.h) * 0.985;
            }
            readonly property real homeX: field.cell ? field.cell.w / 2 : 0
            readonly property real homeY: field.cell ? field.cell.h / 2 : 0

            // The whole canvas: the monitor plus every window of this
            // desktop, however far out it lives. Zooming out lands here —
            // nothing on the canvas can stay hidden.
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

            readonly property real fitContent: {
                const r = field.contentRect;
                const rw = Math.max(1, r.x1 - r.x0);
                const rh = Math.max(1, r.y1 - r.y0);
                return Math.min(field.width / rw, field.height / rh) * 0.985;
            }

            readonly property real minZoom: Math.min(field.homeZoom * 0.3, field.fitContent * 0.9)
            readonly property real maxZoom: field.homeZoom * 2.6

            // Canvas → plate, and back.
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

            // ── drag empty space to look around, click it to reset
            MouseArea {
                id: pan

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

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
                    if (wasClick) {
                        Sfx.cursor();
                        root.goHome();
                    }
                }

                onCanceled: {
                    root.grabbing = false;
                    root.pointerDown = false;
                    pan.moved = false;
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                onWheel: event => {
                    root.poke();
                    const k = event.angleDelta.y > 0 ? 1.22 : 1 / 1.22;
                    root.setZoom(root.zoom * k, event.x, event.y);
                }
            }

            // ── the monitor, drawn as a quiet frame — and it IS a hitbox:
            //    it glows when the pointer is over it, and a click on it
            //    (or any bare canvas) resets the camera home.
            Rectangle {
                visible: field.cell !== null
                x: field.sx(0)
                y: field.sy(0)
                width: (field.cell?.w ?? 0) * root.zoom
                height: (field.cell?.h ?? 0) * root.zoom
                radius: Math.max(2, Math.min(12, 16 * root.zoom))
                color: desktopHover.hovered ? Colours.alpha(Colours.accent, 0.07) : Colours.alpha(Colours.ink, 0.03)
                border.width: 1
                border.color: desktopHover.hovered ? Colours.alpha(Colours.accent, 0.55) : Colours.alpha(Colours.accent, 0.28)
                antialiasing: true

                Behavior on border.color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                HoverHandler {
                    id: desktopHover
                }
            }

            P5Text {
                visible: Config.map.showWorkspaceLabels && field.cell !== null
                x: field.sx(0) + 7
                y: field.sy(0) + 5
                text: `${root.homeWs}`
                color: Colours.alpha(Colours.accent, 0.75)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
            }

            // ── the windows — cozy named cards, on the monitor and on the
            //    infinite canvas around it
            Repeater {
                model: root.frame

                Item {
                    id: card

                    required property var modelData
                    required property int index

                    readonly property var win: card.modelData
                    readonly property bool onHome: (card.win?.ws ?? -1) === root.homeWs
                    readonly property bool hidden: (card.win?.hidden ?? false) === true

                    readonly property bool isActive: (card.win?.address ?? "") === Desk.activeAddress
                    readonly property bool isCursor: root.pinned && card.win === root.picked
                    readonly property bool isDragged: root.dragging && root.dragAddr === (card.win?.address ?? "-")
                    readonly property bool isLanded: (card.win?.address ?? "") === root.landedAddr

                    visible: card.onHome && !card.hidden
                    opacity: root.cardsDimmed && !card.isDragged && !card.isLanded ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    x: card.isDragged ? field.sx(root.dragWX) : field.sx((card.win?.x ?? 0) - (field.cell?.monX ?? 0))
                    y: card.isDragged ? field.sy(root.dragWY) : field.sy((card.win?.y ?? 0) - (field.cell?.monY ?? 0))
                    width: Math.max(16, (card.win?.w ?? 0) * root.zoom)
                    height: Math.max(12, (card.win?.h ?? 0) * root.zoom)

                    // The one under the pointer comes forward.
                    z: card.isDragged ? 9 : (cardArea.containsMouse ? 8 : (card.isCursor ? 6 : (card.isActive ? 5 : 1)))

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -3
                        visible: card.isCursor
                        color: "transparent"
                        border.width: 2
                        border.color: Colours.accent
                        radius: 3
                        antialiasing: true
                    }

                    // The cozy body — a quiet filled card, never a picture.
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: Colours.alpha(Colours.surfaceHigh, 0.55)
                        border.width: card.isDragged ? 2 : 1
                        border.color: card.isActive ? Colours.alpha(Colours.ink, 0.85) : (card.isDragged ? Colours.accent : (cardArea.containsMouse ? Colours.alpha(Colours.accent, 0.5) : Colours.alpha(Colours.ink, 0.22)))
                        antialiasing: true

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    // The window's class, centred — the card IS the label.
                    P5Text {
                        anchors.centerIn: parent
                        width: Math.max(0, parent.width - 8)
                        horizontalAlignment: Text.AlignHCenter
                        text: card.win?.cls ?? ""
                        color: Colours.alpha(Colours.inkDim, 0.7)
                        font.pixelSize: Math.max(6, Appearance.font.size.tiny * root.zoom)
                        tracking: 0.6
                        elide: Text.ElideRight
                        visible: card.height >= 16
                    }

                    // The tiled marker: a small notch.
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 2
                        width: 5
                        height: 5
                        radius: 2.5
                        visible: card.win?.floating === false && card.width > 60
                        color: Colours.alpha(Colours.inkDim, 0.55)
                        antialiasing: true
                    }

                    // The name appears under the card only while you are
                    // pointing at it.
                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 3
                        visible: Config.map.showTitles && cardArea.containsMouse && !root.dragging
                        width: Math.max(card.width, 150)
                        horizontalAlignment: Text.AlignHCenter
                        text: card.win?.title ?? card.win?.cls ?? ""
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.small
                        tracking: 0.4
                        elide: Text.ElideRight
                        z: 20
                    }

                    MouseArea {
                        id: cardArea

                        anchors.fill: parent
                        hoverEnabled: true
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
                                // float it — and say so once. The float goes
                                // straight down the socket so it lands before
                                // the first slide, and "enable" is idempotent:
                                // the old "set" spelling toggled, and a stale
                                // poll could make it TILE the window.
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
                            if (event.button === Qt.MiddleButton) {
                                Sfx.close();
                                root.pointerDown = false;
                                root.tabDropWs = 0;
                                Desk.closeWindow(card.win?.address ?? "");
                                return;
                            }
                            // A plain click is the whole point of the map: you
                            // go to the window, the desktop pans it centred.
                            root.pointerDown = false;
                            root.tabDropWs = 0;
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
                }
            }
        }

        // ── one line of small type: where you are, and what the tabs do.
        P5Text {
            anchors.left: parent.left
            anchors.leftMargin: plate.pad + 2
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 5
            text: {
                const where = `WORKSPACE ${root.homeWs}`;
                if (root.dragging)
                    return root.dropWs > 0 ? `RELEASE ON TAB ${root.dropWs} TO SEND IT THERE` : `RELEASE ON A TAB TO SEND IT THERE  ·  RELEASE HERE TO PLACE IT`;
                if (root.homes.length === 0)
                    return `${where}  ·  NOTHING OPEN  ·  TABS SWITCH DESKTOPS`;
                if (!root.touched)
                    return `${where}  ·  TABS SWITCH DESKTOPS  ·  ZOOM OUT TO SEE THE CANVAS`;
                return `${where}  ·  ${Math.round(root.zoom / Math.max(0.0001, field.homeZoom) * 100)}%  ·  HOME RESETS`;
            }
            color: root.dragging ? Colours.alpha(Colours.accent, 0.85) : Colours.alpha(Colours.inkDim, 0.7)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.2
        }
    }
}
