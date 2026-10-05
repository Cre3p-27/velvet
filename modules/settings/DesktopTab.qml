//  VELVET  ·  modules/settings/DesktopTab.qml
//  The desktop, arranged by hand.
//
//  A picture of your screen with your wallpaper on it. Drag a program out of
//  the tray at the bottom and drop it where you want it. Drag it around, pull
//  its corner to resize. That arrangement is remembered against the wallpaper
//  that is up, and it opens itself on login.
//
//  The canvas is infinite, so the picture is a row of desktops: pick one in the
//  strip on top (the editor stays open and the real screen follows), zoom out
//  with the wheel to see them all, click one to edit it, or carry a program
//  onto another desktop to move it there.
//
//  The tray holds two things: the little terminal programs Velvet ships —
//  a clock, vitals, a visualiser — and every application you have installed.
//  A terminal program is still just a window, so it floats, sizes and pins
//  like everything else.
//
//  Nothing here writes to disk while your hand is moving. A drag keeps its own
//  position and commits once, on release, so arranging six things does not
//  rewrite the scene file six hundred times.
import qs.config
import qs.services
import qs.components
import qs.modules.wallpaper as WP
import Quickshell
import Quickshell.Widgets
import QtQuick

FocusScope {
    id: root

    focus: true

    // The designer measures against your real monitor and marks what is
    // already running, so it asks for fresh window data while it is open.
    // A repeating ask rather than a claim you have to remember to release:
    // interest lapses on its own when this tab goes away.
    Timer {
        interval: 2000   // Desk already polls at 500 ms while watched
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: Desk.watch()
    }

    // The designer edits whichever scene is on its table — the live one, or
    // a saved one picked from the SAVED DESKTOPS list beside it.
    readonly property var items: Scenes.editing
    property int selected: -1
    readonly property var chosen: root.selected >= 0 && root.selected < root.items.length ? root.items[root.selected] : null

    property string query: ""
    property bool snap: true
    property bool onlyInstalled: false

    // The designer always arranges the wallpaper that is up — never a saved
    // scene for some other wallpaper. Coming here puts the live desk back
    // on the table, whatever was on it before.
    Component.onCompleted: {
        Scenes.editKey = "";
        root.settle();
    }

    // ─────────────────────────────────────────────────────────── drag state
    //  -1 means "not dragging one of mine"; a palette drag carries `newItem`
    //  instead and only becomes real when it lands.
    property int dragIndex: -1
    property var newItem: null
    property bool sizing: false
    property bool dragging: false

    property real liveX: 0
    property real liveY: 0
    property real liveW: 0.3
    property real liveH: 0.35

    property real ghostX: 0
    property real ghostY: 0

    // Square cells: the columns are a fixed count and the rows follow from the
    // screen's shape, so a snapped tile lands on a line that is actually
    // drawn. Quantising both axes to the same fraction looked right in the
    // code and wrong on the screen.
    readonly property real grid: 24
    readonly property int rows: Math.max(4, Math.round(root.grid / Math.max(0.2, stage.ratio)))

    function quant(v: real): real {
        if (!root.snap)
            return v;
        return Math.round(v * root.grid) / root.grid;
    }

    function quantY(v: real): real {
        if (!root.snap)
            return v;
        return Math.round(v * root.rows) / root.rows;
    }

    // ───────────────────────────────────────────────────────── the canvas
    //  The screen is the middle of an endless canvas. Zoom out and you see the
    //  space around it: a module put out there sits off-screen until the
    //  canvas is panned to it. Desktops are the numbers on top — a click
    //  edits one without leaving the editor, and a program carried onto a
    //  number is sent there.
    property int editWs: Hypr.activeWsId > 0 ? Hypr.activeWsId : 1
    property real zoom: 1
    property real camX: 0
    property real camY: 0
    property bool touched: false
    property int dropWs: -1
    property real landX: 0
    property real landY: 0
    property bool panning: false
    property double ownMove: 0

    // How far the canvas reaches past the screen, in screens.
    readonly property real padX: 0.8
    readonly property real padY: 0.6
    readonly property real mockMaxH: Math.max(150, (stage.height - 44) * 0.52)
    readonly property real baseW: Math.max(160, Math.min(stage.width - 16, root.mockMaxH * stage.ratio))
    readonly property real baseH: root.baseW / stage.ratio
    readonly property real canvasL: -root.padX * root.baseW
    readonly property real canvasT: -root.padY * root.baseH
    readonly property real canvasW: root.baseW * (1 + 2 * root.padX)
    readonly property real canvasH: root.baseH * (1 + 2 * root.padY)
    // One screen pixel in the zoomed world — keeps hairlines hairlines.
    readonly property real hair: 1 / Math.max(0.05, root.zoom)

    // The desktops to pick from: the monitor's own, plus any a program of
    // yours is planned on. A string so the list only changes when it must —
    // Desk rebuilds its cells twice a second and the pills should not blink.
    readonly property string deskKey: {
        const seen = {};
        const m = Desk.focusedMonitor;
        const cs = Desk.cells;
        for (let i = 0; i < cs.length; i++)
            if (!m || cs[i].mon === m.name)
                seen[cs[i].ws] = true;
        const it = root.items;
        for (let i = 0; i < it.length; i++) {
            const w = it[i].ws ?? 0;
            if (w > 0 && it[i].kind !== "widget")
                seen[w] = true;
        }
        seen[root.editWs] = true;
        return Object.keys(seen).map(k => parseInt(k, 10)).sort((a, b) => a - b).join(",");
    }
    readonly property var deskList: root.deskKey === "" ? [1] : root.deskKey.split(",").map(s => parseInt(s, 10))
    readonly property var deskModel: root.deskList.map(w => ({
                ws: w
            }))
    readonly property int cellCount: root.deskList.length
    readonly property real fitZoom: Math.max(0.1, Math.min(1, (view.width - 16) / Math.max(1, root.canvasW), (view.height - 12) / Math.max(1, root.canvasH)))
    readonly property int deskCount: root.countOn(root.editWs)

    onBaseWChanged: {
        root.touched = false;
        root.settle();
    }

    // Is this item shown on the desktop being edited? Widgets live on the
    // wallpaper and are on every desktop; "wherever you are" shows on this one.
    function onDesk(it: var): bool {
        if (!it)
            return false;
        if (it.kind === "widget")
            return true;
        const w = it.ws ?? 0;
        return w === 0 || w === root.editWs;
    }

    function countOn(ws: int): int {
        let n = 0;
        const it = root.items;
        for (let i = 0; i < it.length; i++) {
            if (it[i].kind === "widget")
                continue;
            const w = it[i].ws ?? 0;
            if (w === ws || (w === 0 && ws === root.editWs))
                n++;
        }
        return n;
    }

    function stepSelection(dir: int): void {
        const on = [];
        for (let i = 0; i < root.items.length; i++)
            if (root.onDesk(root.items[i]))
                on.push(i);
        if (on.length === 0) {
            root.selected = -1;
            return;
        }
        const at = on.indexOf(root.selected);
        root.selected = on[at < 0 ? (dir > 0 ? 0 : on.length - 1) : (at + dir + on.length) % on.length];
        Sfx.cursor();
    }

    // Widgets stay on the screen; a program may go out onto the canvas.
    function clampFx(v: real, size: real, free: bool): real {
        return free ? Math.max(-root.padX, Math.min(1 + root.padX - size, v)) : Math.max(0, Math.min(1 - size, v));
    }

    function clampFy(v: real, size: real, free: bool): real {
        return free ? Math.max(-root.padY, Math.min(1 + root.padY - size, v)) : Math.max(0, Math.min(1 - size, v));
    }

    // ── camera
    function clampCam(c: real, z: real, lo: real, hi: real, size: real): real {
        const half = size / (2 * z);
        if (hi - lo <= 2 * half)
            return (lo + hi) / 2;
        return Math.max(lo + half, Math.min(hi - half, c));
    }

    function clampX(x: real, z: real): real {
        return root.clampCam(x, z, root.canvasL, root.canvasL + root.canvasW, view.width - 16);
    }

    function clampY(y: real, z: real): real {
        return root.clampCam(y, z, root.canvasT, root.canvasT + root.canvasH, view.height - 12);
    }

    function glideTo(x: real, y: real, z: real): void {
        glideAnim.stop();
        glideAnim.toX = root.clampX(x, z);
        glideAnim.toY = root.clampY(y, z);
        glideAnim.toZ = z;
        glideAnim.start();
    }

    // Zoom around the point under the pointer, so what you look at stays put.
    function zoomAt(factor: real, vx: real, vy: real): void {
        glideAnim.stop();
        root.touched = true;
        const z0 = root.zoom;
        const z1 = Math.max(root.fitZoom, Math.min(1, z0 * factor));
        const wx = (vx - world.x) / z0;
        const wy = (vy - world.y) / z0;
        root.zoom = z1;
        root.camX = root.clampX(wx + (view.width / 2 - vx) / z1, z1);
        root.camY = root.clampY(wy + (view.height / 2 - vy) / z1, z1);
    }

    // The whole canvas in view.
    function showAll(): void {
        root.touched = true;
        root.glideTo(root.baseW / 2, root.baseH / 2, root.fitZoom);
        Sfx.cursor();
    }

    // Back to the screen, filling the view.
    function recentre(): void {
        root.touched = true;
        root.glideTo(root.baseW / 2, root.baseH / 2, 1);
    }

    // Edit this desktop. `follow` also takes the real screen there (a pill
    // click does; the editor catching up with where you already are does not).
    function goTo(ws: int, follow: bool): void {
        if (!(ws > 0))
            return;
        root.ownMove = Date.now();
        root.editWs = ws;
        if (root.chosen && !root.onDesk(root.chosen))
            root.selected = -1;
        if (follow)
            Hypr.focusWorkspace(ws);
    }

    // The view changed size, or this is the first look: keep what you were
    // looking at, or if you never moved the camera, the screen.
    function settle(): void {
        glideAnim.stop();
        root.zoom = Math.max(root.fitZoom, Math.min(1, root.zoom));
        root.camX = root.clampX(root.touched ? root.camX : root.baseW / 2, root.zoom);
        root.camY = root.clampY(root.touched ? root.camY : root.baseH / 2, root.zoom);
    }

    // ── carrying something over the canvas
    //  (vx, vy) is the pointer in the view. A desktop number under it is where
    //  the thing would go; otherwise it stays on the desktop being edited.
    function deskAt(vx: real, vy: real): int {
        const p = deskStrip.mapFromItem(view, vx, vy);
        if (p.x < 0 || p.y < 0 || p.x > deskStrip.width || p.y > deskStrip.height)
            return -1;
        const hit = deskStrip.childAt(p.x, p.y);
        const ws = hit && hit.modelData ? Number(hit.modelData.ws) : -1;
        return ws > 0 ? ws : -1;
    }

    function steer(movable: bool, vx: real, vy: real): void {
        const ws = movable ? root.deskAt(vx, vy) : -1;
        if (ws > 0 && ws !== root.editWs) {
            root.dropWs = ws;
            root.landX = root.clampFx(root.liveX, root.liveW, false);
            root.landY = root.clampFy(root.liveY, root.liveH, false);
        } else {
            root.dropWs = root.editWs;
        }
    }

    // A tray chip being carried: the same, with the pointer in this tab's space.
    function steerNew(): void {
        const p = view.mapFromItem(root, root.ghostX, root.ghostY);
        const ws = root.deskAt(p.x, p.y);
        const inside = p.x >= 0 && p.y >= 0 && p.x <= view.width && p.y <= view.height;
        root.dropWs = ws > 0 ? ws : (inside ? root.editWs : -1);
    }

    // Puts a new thing on a desktop, its centre at (cx, cy) in fractions of it.
    function place(item: var, ws: int, cx: real, cy: real): void {
        const w = item.w ?? 0.32;
        const h = item.h ?? 0.36;
        const free = item.kind !== "widget";
        Scenes.add(Object.assign({}, item, {
            x: root.clampFx(root.quant(cx - w / 2), w, free),
            y: root.clampFy(root.quantY(cy - h / 2), h, free),
            w: w,
            h: h,
            ws: item.kind === "widget" ? 0 : ws,
            float: true
        }));
        root.selected = root.items.length - 1;
        Sfx.select();
    }

    ParallelAnimation {
        id: glideAnim

        property real toX: 0
        property real toY: 0
        property real toZ: 1

        NumberAnimation {
            target: root
            property: "camX"
            to: glideAnim.toX
            duration: Appearance.anim.normal
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "camY"
            to: glideAnim.toY
            duration: Appearance.anim.normal
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "zoom"
            to: glideAnim.toZ
            duration: Appearance.anim.normal
            easing.type: Easing.OutCubic
        }
    }

    // You switched desktop some other way (keys, the bar): the editor follows.
    Connections {
        target: Hypr

        function onActiveWsIdChanged(): void {
            if (Date.now() - root.ownMove > 800)
                root.goTo(Hypr.activeWsId, false);
        }
    }

    // ───────────────────────────────────────────────────────────── the tray
    readonly property var appHits: {
        const q = root.query.trim();
        const scored = [];
        const apps = Apps.all;
        for (let i = 0; i < apps.length; i++) {
            const e = apps[i];
            if (!e || !e.name)
                continue;
            const s = q === "" ? 1 : Math.max(Apps.score(e.name, q), Apps.score(e.id ?? "", q) * 0.6);
            if (s < 0)
                continue;
            scored.push({
                entry: e,
                rank: s + Apps.frecency(e.id) * 40
            });
        }
        scored.sort((a, b) => b.rank - a.rank);
        const out = [];
        for (let i = 0; i < Math.min(scored.length, 16); i++)
            out.push(scored[i].entry);
        return out;
    }

    readonly property var toolHits: {
        const q = root.query.trim().toLowerCase();
        if (!q)
            return TermApps.all;
        const out = [];
        for (let i = 0; i < TermApps.all.length; i++) {
            const t = TermApps.all[i];
            if (t.name.toLowerCase().indexOf(q) !== -1 || t.id.indexOf(q) !== -1)
                out.push(t);
        }
        return out;
    }

    readonly property var tuiHits: {
        const q = root.query.trim().toLowerCase();
        const out = [];
        for (let i = 0; i < TermApps.tui.length; i++) {
            const t = TermApps.tui[i];
            if (root.onlyInstalled && TermApps.isMissing(t.id))
                continue;
            if (!q || t.name.toLowerCase().indexOf(q) !== -1 || (t.sub ?? "").toLowerCase().indexOf(q) !== -1 || (t.run ?? "").toLowerCase().indexOf(q) !== -1)
                out.push(t);
        }
        return out;
    }

    // ═══════════════════════════════════════════════════════════════ the stage
    Item {
        id: stage

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * 0.63

        readonly property real ratio: {
            const m = Desk.focusedMonitor;
            if (m && m.h > 0)
                return m.w / m.h;
            return 16 / 9;
        }

        // ── which desktop you are arranging, and the zoom
        Item {
            id: deskBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            height: Math.max(30, deskStrip.height)

            P5Text {
                id: deskLabel

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "DESKTOP"
                color: Colours.alpha(Colours.accent, 0.9)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 3
            }

            DesktopStrip {
                id: deskStrip

                anchors.left: deskLabel.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - deskLabel.width - 12 - (hud.visible ? hud.width + 12 : 0)
                model: root.deskModel
                showCanvas: false
                current: root.editWs
                aimed: root.dragging && !root.sizing && root.dropWs !== root.editWs ? root.dropWs : -1
                goes: false
                pillWidth: 38
                pillHeight: 30
                countOf: ws => root.countOn(ws)
                onPicked: ws => root.goTo(ws, true)
            }

            Row {
                id: hud

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "zoom_out"
                    enabled: root.zoom > root.fitZoom + 0.001
                    opacity: enabled ? 1 : 0.35
                    onClicked: root.zoomAt(1 / 1.45, view.width / 2, view.height / 2)
                }

                P5Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    horizontalAlignment: Text.AlignHCenter
                    text: `${Math.round(root.zoom * 100)}%`
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "zoom_in"
                    enabled: root.zoom < 0.999
                    opacity: enabled ? 1 : 0.35
                    onClicked: root.zoomAt(1.45, view.width / 2, view.height / 2)
                }

                MiniButton {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 122
                    accent: root.zoom >= 0.98
                    glyph: root.zoom < 0.98 ? "crop_free" : "grid_view"
                    label: root.zoom < 0.98 ? "THE SCREEN" : "SHOW CANVAS"
                    onClicked: root.zoom < 0.98 ? root.recentre() : root.showAll()
                }
            }
        }

        // ── the canvas: the screen in the middle of endless space. Scroll to
        //    zoom, drag to pan, drag a module out onto the canvas.
        Item {
            id: view

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: deskBar.bottom
            anchors.topMargin: 8
            height: root.baseH + 30
            clip: true

            onWidthChanged: root.settle()
            onHeightChanged: root.settle()

            MouseArea {
                id: panArea

                property real pressX: 0
                property real pressY: 0
                property real pressCamX: 0
                property real pressCamY: 0

                anchors.fill: parent
                cursorShape: root.dragging || root.panning ? Qt.ClosedHandCursor : Qt.ArrowCursor

                onPressed: event => {
                    glideAnim.stop();
                    panArea.pressX = event.x;
                    panArea.pressY = event.y;
                    panArea.pressCamX = root.camX;
                    panArea.pressCamY = root.camY;
                    root.panning = false;
                }

                onPositionChanged: event => {
                    if (!pressed)
                        return;
                    if (!root.panning && Math.abs(event.x - panArea.pressX) + Math.abs(event.y - panArea.pressY) > 6)
                        root.panning = true;
                    if (root.panning) {
                        root.touched = true;
                        root.camX = root.clampX(panArea.pressCamX - (event.x - panArea.pressX) / root.zoom, root.zoom);
                        root.camY = root.clampY(panArea.pressCamY - (event.y - panArea.pressY) / root.zoom, root.zoom);
                    }
                }

                onReleased: {
                    if (root.panning) {
                        root.panning = false;
                        return;
                    }
                    root.selected = -1;
                }

                onDoubleClicked: root.zoom < 0.98 ? root.recentre() : root.showAll()

                onWheel: wheel => root.zoomAt(wheel.angleDelta.y > 0 ? 1.18 : 1 / 1.18, wheel.x, wheel.y)
            }

            Item {
                id: world

                x: view.width / 2 - root.camX * root.zoom
                y: view.height / 2 - root.camY * root.zoom
                width: root.baseW
                height: root.baseH
                scale: root.zoom
                transformOrigin: Item.TopLeft

                // The space around the screen: what sits out here is off-screen
                // until you pan the canvas to it. Fades in as you zoom out.
                Item {
                    x: root.canvasL
                    y: root.canvasT
                    width: root.canvasW
                    height: root.canvasH
                    z: 0
                    opacity: Math.max(0, Math.min(1, (0.98 - root.zoom) * 8))
                    visible: opacity > 0.01

                    Rectangle {
                        anchors.fill: parent
                        radius: 12 * root.hair
                        color: Colours.alpha(Colours.ink, 0.1)
                        border.width: 1.5 * root.hair
                        border.color: Colours.alpha(Colours.ink, 0.4)
                        antialiasing: true
                    }

                    Repeater {
                        model: 11

                        Rectangle {
                            required property int index

                            x: (index - 3) * root.baseW / 4 - root.canvasL
                            width: root.hair
                            height: parent.height
                            color: Colours.alpha(Colours.ink, 0.14)
                        }
                    }

                    Repeater {
                        model: 9

                        Rectangle {
                            required property int index

                            y: (index - 2) * root.baseH / 4 - root.canvasT
                            height: root.hair
                            width: parent.width
                            color: Colours.alpha(Colours.ink, 0.14)
                        }
                    }

                    P5Text {
                        x: 14 * root.hair
                        y: 8 * root.hair
                        text: "THE CANVAS  ·  WHAT SITS OUT HERE IS OFF-SCREEN UNTIL YOU PAN TO IT"
                        color: Colours.alpha(Colours.ink, 0.55)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 2
                        scale: root.hair
                        transformOrigin: Item.TopLeft
                    }

                    P5Text {
                        x: -root.canvasL
                        y: -root.canvasT - height - 4 * root.hair
                        text: `YOUR SCREEN  ·  DESKTOP ${root.editWs}`
                        color: Colours.accent
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 2
                        scale: root.hair
                        transformOrigin: Item.BottomLeft
                    }
                }


                // The desktop being edited — the only live one.
                Item {
                    id: mock

                    width: root.baseW
                    height: root.baseH
                    x: 0
                    z: 5
                    // Your wallpaper, so what you are arranging is judged against what
                    // it will actually sit on.
                    Plate {
                        anchors.fill: parent
                        radius: Appearance.r(8)
                        color: Colours.paper
                        clip: true
                        antialiasing: true

                        Image {
                            anchors.fill: parent
                            source: Config.wallpaper.current ? "file://" + Config.wallpaper.current : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Colours.alpha(Colours.paper, 0.25)
                        }
                    }

                    // The snap grid, only while you are actually moving something.
                    Item {
                        anchors.fill: parent
                        visible: root.dragging && root.snap
                        opacity: 0.5

                        Repeater {
                            model: Math.round(root.grid) - 1

                            Rectangle {
                                required property int index

                                width: root.hair
                                height: mock.height
                                x: Math.round(mock.width * (index + 1) / root.grid)
                                color: Colours.alpha(Colours.ink, 0.18)
                            }
                        }

                        Repeater {
                            model: root.rows - 1

                            Rectangle {
                                required property int index

                                height: root.hair
                                width: mock.width
                                y: Math.round(mock.height * (index + 1) / root.rows)
                                color: Colours.alpha(Colours.ink, 0.18)
                            }
                        }
                    }

                    // Where the bar sits, so you do not park a window under it.
                    Rectangle {
                        visible: Config.bar.enabled
                        readonly property real k: mock.width / Math.max(1, Desk.focusedMonitor?.w ?? 1920)
                        readonly property real thick: Math.max(4, Config.bar.thickness * k)
                        readonly property real inset: Config.bar.margin * k
                        readonly property bool vertical: Config.bar.position === "left" || Config.bar.position === "right"

                        x: Config.bar.position === "right" ? mock.width - thick - inset : inset
                        y: Config.bar.position === "bottom" ? mock.height - thick - inset : inset
                        width: vertical ? thick : mock.width - inset * 2
                        height: vertical ? mock.height - inset * 2 : thick
                        radius: Math.max(2, Config.bar.rounding * k)
                        color: Colours.alpha(Colours.surface, 0.5)
                        border.width: root.hair
                        border.color: Colours.alpha(Colours.accent, 0.3)
                        antialiasing: true
                    }

                    // The edit desktop is outlined whenever there are several to
                    // tell apart, and lights up when what you carry would land here.
                    Rectangle {
                        readonly property bool target: root.dragging && root.dropWs === root.editWs

                        anchors.fill: parent
                        radius: Appearance.r(8)
                        color: "transparent"
                        border.width: (target || root.zoom < 0.98 ? 2 : 1) * root.hair
                        border.color: target ? Colours.accent : (root.zoom < 0.98 ? Colours.alpha(Colours.accent, 0.85) : Colours.alpha(Colours.ink, 0.25))
                        antialiasing: true

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    // ── everything you have placed
                    Repeater {
                        id: placed

                        model: root.items

                        Item {
                            id: tile

                            required property var modelData
                            required property int index

                            readonly property bool isSelected: tile.index === root.selected
                            readonly property bool isDragged: root.dragIndex === tile.index && root.dragging

                            readonly property real fx: tile.isDragged ? root.liveX : (tile.modelData.x ?? 0)
                            readonly property real fy: tile.isDragged ? root.liveY : (tile.modelData.y ?? 0)
                            readonly property real fw: tile.isDragged ? root.liveW : (tile.modelData.w ?? 0.3)
                            readonly property real fh: tile.isDragged ? root.liveH : (tile.modelData.h ?? 0.3)

                            readonly property bool live: Scenes.isRunning(tile.modelData)
                            readonly property bool runnable: tile.modelData.kind === "widget" || Scenes.commandFor(tile.modelData) !== ""

                            visible: root.onDesk(tile.modelData)
                            x: tile.fx * mock.width
                            y: tile.fy * mock.height
                            width: Math.max(18, tile.fw * mock.width)
                            height: Math.max(14, tile.fh * mock.height)
                            z: tile.isDragged ? 30 : (tile.isSelected ? 20 : 10)

                            Rectangle {
                                anchors.fill: parent
                                radius: Math.max(2, Appearance.rounding.small * 0.6)
                                color: tile.modelData.kind === "widget" ? Colours.alpha(Colours.surface, tile.isSelected || tileArea.containsMouse ? 0.25 : 0.0) : Colours.alpha(Colours.surface, tile.isDragged ? 0.82 : 0.94)
                                border.width: (tile.isSelected ? 2 : 1) * root.hair
                                border.color: tile.isSelected ? Colours.accent : Colours.alpha(Colours.ink, tileArea.containsMouse ? 0.6 : 0.3)
                                antialiasing: true

                                Behavior on border.color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }

                            // A widget is shown as ITSELF — the real thing, at the size
                            // the wallpaper will draw it — not as an icon and a label.
                            Item {
                                id: preview

                                anchors.fill: parent
                                visible: tile.modelData.kind === "widget"
                                clip: true

                                readonly property var opts: tile.modelData.opts ?? ({})
                                readonly property string chips: {
                                    const o = preview.opts.frame ?? "auto";
                                    return o === "auto" ? Config.wallpaper.livingChips : o;
                                }
                                readonly property real chipOpacity: {
                                    const o = preview.opts.opacity ?? -1;
                                    return o >= 0 ? o : Config.wallpaper.livingOpacity;
                                }
                                // mock pixels per real pixel
                                readonly property real k: mock.width / Math.max(1, Desk.focusedMonitor?.w ?? 1920)

                                Loader {
                                    anchors.centerIn: parent
                                    active: preview.visible

                                    sourceComponent: WP.Widgets {
                                        id: pw

                                        wid: tile.modelData.widget ?? ""
                                        framed: preview.chips !== "raw"
                                        look: preview.chips
                                        shape: preview.opts.shape ?? ""
                                        tone: preview.opts.tone ?? ""
                                        colourSlot: preview.opts.slot ?? 0
                                        details: preview.opts.details ?? true
                                        opts: preview.opts
                                        chipFill: preview.chips === "ink" ? Qt.rgba(0.02, 0.03, 0.05, 0.62) : Colours.alpha(Colours.surface, 0.55)
                                        chipBorder: preview.chips === "ink" ? Qt.rgba(1, 1, 1, 0.14) : Colours.alpha(Colours.accent, 0.28)
                                        chipOpacity: preview.chips === "raw" ? 1 : preview.chipOpacity

                                        // Same rule as the wallpaper layer, then down to the picture.
                                        readonly property real fit: Math.max(0.4, Math.min(2.2, Math.min(tile.width / preview.k / Math.max(24, pw.implicitWidth), tile.height / preview.k / Math.max(24, pw.implicitHeight))))
                                        scale: pw.fit * Config.wallpaper.livingScale * preview.k
                                    }
                                }
                            }

                            // CAVA is shown LIVE: its look with every switch, drawn
                            // from the music that plays (a calm demo swell without).
                            readonly property bool isCava: Scenes.moduleOf(tile.modelData) === "cava"

                            CavaPreview {
                                readonly property var mon: Desk.focusedMonitor
                                readonly property real fontPx: 0.834 * (Number(tile.modelData.opts?.win?.size ?? 0) || 11)

                                anchors.fill: parent
                                anchors.margins: 2
                                visible: tile.isCava
                                running: tile.isCava && root.visible && tile.visible
                                o: tile.modelData.opts?.o ?? ({})
                                columns: {
                                    const o = tile.modelData.opts?.o ?? ({});
                                    const side = o.orient === "left" || o.orient === "right";
                                    return side ? tile.fh * (mon?.h ?? 1800) / (fontPx * 2) : tile.fw * (mon?.w ?? 3200) / fontPx;
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 3
                                width: parent.width - 10
                                // The live cava speaks for itself; its name rides
                                // quietly in the corner instead.
                                visible: tile.modelData.kind !== "widget" && !tile.isCava

                                IconImage {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: Scenes.iconFor(tile.modelData) !== "" && tile.height > 46
                                    implicitSize: Math.max(14, Math.min(40, Math.min(tile.width, tile.height) * 0.36))
                                    source: Scenes.iconFor(tile.modelData) !== "" ? Quickshell.iconPath(Scenes.iconFor(tile.modelData), "application-x-executable") : ""
                                }

                                Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: Scenes.iconFor(tile.modelData) === "" && tile.height > 46
                                    name: (tile.modelData.kind === "term" || tile.modelData.kind === "tui") ? TermApps.iconOf(Scenes.moduleOf(tile.modelData)) : (tile.modelData.kind === "widget" ? (LockModules.find(tile.modelData.widget ?? "")?.glyph ?? "widgets") : "terminal")
                                    color: Colours.accent
                                    font.pixelSize: Math.max(14, Math.min(34, Math.min(tile.width, tile.height) * 0.32))
                                }

                                P5Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    display: true
                                    text: Scenes.labelFor(tile.modelData)
                                    color: Colours.ink
                                    font.pixelSize: Math.max(8, Math.min(Appearance.font.size.small, tile.width * 0.11))
                                    elide: Text.ElideRight
                                }

                                P5Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    visible: tile.height > 64 || tile.modelData.kind === "widget"
                                    text: tile.modelData.kind === "widget" ? "LIVE ON THE WALLPAPER" : ((tile.modelData.ws ?? 0) > 0 ? `DESKTOP ${tile.modelData.ws}` : "ANY DESKTOP")
                                    color: tile.modelData.kind === "widget" ? Colours.alpha(Colours.accent, 0.85) : Colours.alpha(Colours.inkDim, 0.85)
                                    font.pixelSize: Appearance.font.size.tiny
                                    tracking: 1
                                    elide: Text.ElideRight
                                }
                            }

                            Plate {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 4
                                visible: tile.isCava && tile.height > 22
                                width: cavaTag.implicitWidth + 12
                                height: cavaTag.implicitHeight + 4
                                radius: Appearance.pill(height)
                                color: Colours.alpha(Colours.surface, 0.8)
                                antialiasing: true

                                P5Text {
                                    id: cavaTag

                                    anchors.centerIn: parent
                                    display: true
                                    text: `${Scenes.labelFor(tile.modelData)} · LIVE`
                                    color: Colours.ink
                                    font.pixelSize: Appearance.font.size.tiny
                                }
                            }

                            // A dot when it is open right now; a warning when it has no
                            // command to run, which is the one way a scene can be
                            // quietly useless.
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 5
                                width: 6
                                height: 6
                                radius: 3
                                visible: tile.live
                                color: Colours.accent
                                antialiasing: true
                            }

                            Icon {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 3
                                visible: !tile.runnable
                                name: "error"
                                color: Colours.danger
                                font.pixelSize: 13
                            }

                            MouseArea {
                                id: tileArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                                property bool moved: false
                                property real offX: 0
                                property real offY: 0

                                onPressed: event => {
                                    tileArea.moved = false;
                                    root.selected = tile.index;
                                    tileArea.offX = event.x / Math.max(1, mock.width);
                                    tileArea.offY = event.y / Math.max(1, mock.height);
                                }

                                onPositionChanged: event => {
                                    if (!pressed)
                                        return;
                                    const p = tileArea.mapToItem(mock, event.x, event.y);
                                    const nx = p.x / Math.max(1, mock.width) - tileArea.offX;
                                    const ny = p.y / Math.max(1, mock.height) - tileArea.offY;
                                    if (!tileArea.moved) {
                                        if (Math.abs(nx - tile.fx) + Math.abs(ny - tile.fy) < 0.006)
                                            return;
                                        tileArea.moved = true;
                                        root.dragIndex = tile.index;
                                        root.sizing = false;
                                        root.dragging = true;
                                        root.dropWs = root.editWs;
                                        root.liveW = tile.modelData.w ?? 0.3;
                                        root.liveH = tile.modelData.h ?? 0.3;
                                    }
                                    const free = tile.modelData.kind !== "widget";
                                    root.liveX = root.clampFx(root.quant(nx), root.liveW, free);
                                    root.liveY = root.clampFy(root.quantY(ny), root.liveH, free);
                                    const vp = tileArea.mapToItem(view, event.x, event.y);
                                    root.steer(free, vp.x, vp.y);
                                }

                                // Flags first, commit last: committing rewrites the
                                // scene, which rebuilds every delegate including this
                                // one, and there is no reason to touch it afterwards.
                                onReleased: {
                                    const moved = tileArea.moved;
                                    tileArea.moved = false;
                                    if (moved)
                                        root.commitDrag();
                                }

                                onCanceled: {
                                    const moved = tileArea.moved;
                                    tileArea.moved = false;
                                    if (moved)
                                        root.commitDrag();
                                }

                                onDoubleClicked: Scenes.launchItem(tile.modelData, true)
                            }

                            // ── the corner you pull to resize
                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                width: Math.min(14 * root.hair, tile.width * 0.45)
                                height: width
                                radius: 3 * root.hair
                                // Not `|| sizeArea.containsMouse`: an invisible item is
                                // not hit-tested, so that term could never turn itself
                                // on and only made the condition look cleverer.
                                visible: tile.isSelected || tileArea.containsMouse
                                color: sizeArea.containsMouse ? Colours.accent : Colours.alpha(Colours.ink, 0.35)
                                antialiasing: true

                                Icon {
                                    anchors.centerIn: parent
                                    name: "open_in_full"
                                    color: sizeArea.containsMouse ? Colours.on(Colours.accent) : Colours.paper
                                    font.pixelSize: Math.max(6, parent.width * 0.7)
                                }

                                MouseArea {
                                    id: sizeArea

                                    anchors.fill: parent
                                    anchors.margins: -4 * root.hair
                                    hoverEnabled: true
                                    cursorShape: Qt.SizeFDiagCursor

                                    property bool moved: false
                                    // Where inside the handle you took hold. Without
                                    // it the corner jumps to the pointer the instant
                                    // the resize starts, and the handle slides out
                                    // from under the cursor.
                                    property real holdX: 0
                                    property real holdY: 0

                                    onPressed: event => {
                                        sizeArea.moved = false;
                                        root.selected = tile.index;
                                        const p = sizeArea.mapToItem(mock, event.x, event.y);
                                        sizeArea.holdX = p.x / Math.max(1, mock.width) - ((tile.modelData.x ?? 0) + (tile.modelData.w ?? 0.3));
                                        sizeArea.holdY = p.y / Math.max(1, mock.height) - ((tile.modelData.y ?? 0) + (tile.modelData.h ?? 0.3));
                                    }

                                    onPositionChanged: event => {
                                        if (!pressed)
                                            return;
                                        const p = sizeArea.mapToItem(mock, event.x, event.y);
                                        const w = p.x / Math.max(1, mock.width) - sizeArea.holdX - (tile.modelData.x ?? 0);
                                        const h = p.y / Math.max(1, mock.height) - sizeArea.holdY - (tile.modelData.y ?? 0);

                                        if (!sizeArea.moved) {
                                            if (Math.abs(w - (tile.modelData.w ?? 0.3)) + Math.abs(h - (tile.modelData.h ?? 0.3)) < 0.006)
                                                return;
                                            sizeArea.moved = true;
                                            root.dragIndex = tile.index;
                                            root.sizing = true;
                                            root.dragging = true;
                                            root.dropWs = root.editWs;
                                            root.liveX = tile.modelData.x ?? 0;
                                            root.liveY = tile.modelData.y ?? 0;
                                        }
                                        const wide = tile.modelData.kind === "widget" ? 1 : 1 + root.padX;
                                        const high = tile.modelData.kind === "widget" ? 1 : 1 + root.padY;
                                        root.liveW = Math.max(0.06, Math.min(wide - root.liveX, root.quant(w)));
                                        root.liveH = Math.max(0.06, Math.min(high - root.liveY, root.quantY(h)));
                                    }

                                    // A plain click on the handle must not rewrite the
                                    // scene file, rebuild every tile and play a sound.
                                    onReleased: {
                                        const moved = sizeArea.moved;
                                        sizeArea.moved = false;
                                        if (moved)
                                            root.commitDrag();
                                    }

                                    onCanceled: {
                                        const moved = sizeArea.moved;
                                        sizeArea.moved = false;
                                        if (moved)
                                            root.commitDrag();
                                    }
                                }
                            }
                        }
                    }

                    P5Text {
                        anchors.centerIn: parent
                        visible: root.deskCount === 0 && !root.dragging
                        width: mock.width * 0.7
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: root.cellCount > 1 ? `DESKTOP ${root.editWs} IS EMPTY  ·  DRAG SOMETHING UP HERE FROM BELOW` : "DRAG SOMETHING UP HERE FROM BELOW"
                        color: Colours.alpha(Colours.ink, 0.75)
                        font.pixelSize: Appearance.font.size.small
                        tracking: 2.4
                    }
                }
            }
        }

        // ── the caption under the screen
        Item {
            id: caption

            anchors.horizontalCenter: view.horizontalCenter
            anchors.top: view.bottom
            anchors.topMargin: 6
            width: root.baseW
            height: 20

            P5Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 90 - (undoPill.visible ? undoPill.width + 8 : 0)
                elide: Text.ElideRight
                text: root.dragging && root.cellCount > 1 && !root.sizing ? "DROP IT ON A DESKTOP NUMBER ABOVE TO SEND IT THERE" : (root.zoom < 0.98 ? "DRAG PANS  ·  SCROLL ZOOMS  ·  MODULES CAN SIT OUT HERE" : Scenes.editingStatus)
                color: Colours.alpha(Colours.inkDim, 0.85)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.6
            }

            // UNDO lives here, under the picture, where coming and going
            // moves nothing: in the side card it pushed every row below it
            // down while it was up — and pulled them back up under the
            // pointer when it expired.
            Item {
                id: undoPill

                anchors.right: snapPill.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                visible: Scenes.undoStore !== null
                width: undoRow.implicitWidth + 20
                height: 20

                Plate {
                    anchors.fill: parent
                    radius: Appearance.pill(height)
                    color: Colours.alpha(Colours.warning, undoArea.containsMouse ? 1 : 0.85)
                    antialiasing: true
                }

                Row {
                    id: undoRow

                    anchors.centerIn: parent
                    spacing: 4

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "undo"
                        color: Colours.on(Colours.warning)
                        font.pixelSize: 13
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `UNDO  ·  ${Scenes.undoWhat}`
                        color: Colours.on(Colours.warning)
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.2
                    }
                }

                MouseArea {
                    id: undoArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Scenes.undo();
                        root.selected = -1;
                    }
                }
            }

            Item {
                id: snapPill

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 74
                height: 20

                Plate {
                    anchors.fill: parent
                    radius: Appearance.pill(height)
                    color: root.snap ? Colours.alpha(Colours.accent, 0.85) : Colours.alpha(Colours.ink, 0.12)
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                P5Text {
                    anchors.centerIn: parent
                    text: root.snap ? "SNAP ON" : "SNAP OFF"
                    color: root.snap ? Colours.on(Colours.accent) : Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.4
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.snap = !root.snap;
                        Sfx.toggle();
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════ the tray
        Item {
            id: trayHead

            anchors.left: parent.left
            anchors.right: stage.right
            anchors.rightMargin: 4
            anchors.top: caption.bottom
            anchors.topMargin: 20
            height: 26

            P5Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "DRAG ONTO THE SCREEN"
                color: Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 3
            }

            Plate {
                id: installedChip

                anchors.right: searchBox.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 126
                height: 26
                radius: Appearance.r(13)
                color: root.onlyInstalled ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.ink, 0.09)
                antialiasing: true

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                P5Text {
                    anchors.centerIn: parent
                    text: root.onlyInstalled ? "INSTALLED ONLY" : "ALL MODULES"
                    color: root.onlyInstalled ? Colours.on(Colours.accent) : Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.onlyInstalled = !root.onlyInstalled;
                        Sfx.toggle();
                    }
                }
            }

            Plate {
                id: searchBox

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(260, parent.width * 0.5)
                height: 26
                radius: Appearance.rounding.small
                color: Colours.alpha(Colours.ink, 0.07)
                border.width: search.activeFocus ? 1 : 0
                border.color: Colours.accent
                antialiasing: true

                Icon {
                    id: searchIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    color: Colours.alpha(Colours.inkDim, 0.8)
                    font.pixelSize: 14
                }

                TextInput {
                    id: search

                    anchors.left: searchIcon.right
                    anchors.leftMargin: 6
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    color: Colours.ink
                    font.family: Appearance.fontFamily.body
                    font.pixelSize: Appearance.font.size.small
                    selectByMouse: true
                    clip: true
                    onTextChanged: root.query = text

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text === ""
                        text: "FIND A MODULE OR APP"
                        color: Colours.alpha(Colours.inkDim, 0.6)
                        font.pixelSize: Appearance.font.size.small
                        tracking: 1
                    }
                }
            }
        }

        Flickable {
            id: trayScroll

            anchors.left: parent.left
            anchors.right: stage.right
            anchors.rightMargin: 4
            anchors.top: trayHead.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4

            contentHeight: trayBody.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: trayBody

                width: trayScroll.width
                spacing: 10

                P5Text {
                    text: "VELVET MODULES"
                    color: Colours.alpha(Colours.accent, 0.9)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }

                Flow {
                    width: parent.width
                    spacing: 7

                    Repeater {
                        model: root.toolHits

                        TrayChip {
                            required property var modelData

                            label: modelData.name
                            sub: modelData.sub
                            glyph: modelData.icon
                            iconName: ""
                            payload: ({
                                    kind: "term",
                                    term: modelData.id,
                                    name: modelData.name,
                                    w: modelData.w,
                                    h: modelData.h
                                })
                        }
                    }
                }

                P5Text {
                    text: "DESKTOP WIDGETS"
                    color: Colours.alpha(Colours.accent, 0.9)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }

                Flow {
                    width: parent.width
                    spacing: 7

                    Repeater {
                        // power needs the lock surface and session is the
                        // lock's own terminal — neither belongs on a desktop.
                        model: LockModules.all.filter(m => m.id !== "power" && m.id !== "session").concat([{
                                    id: "calendar",
                                    name: "CALENDAR",
                                    glyph: "calendar_month"
                                }])

                        TrayChip {
                            required property var modelData

                            label: modelData.name
                            sub: "LIVE ON THE WALLPAPER  ·  NO WINDOW NEEDED"
                            glyph: modelData.glyph
                            iconName: ""
                            payload: ({
                                    kind: "widget",
                                    widget: modelData.id,
                                    name: modelData.name,
                                    w: 0.24,
                                    h: 0.2,
                                    // New widgets start in the SHAPES look; FRAME in
                                    // the inspector switches any one of them.
                                    opts: {
                                        frame: "shapes",
                                        opacity: -1
                                    }
                                })
                        }
                    }
                }

                P5Text {
                    text: "MORE MODULES"
                    color: Colours.alpha(Colours.inkDim, 0.7)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }

                Flow {
                    width: parent.width
                    spacing: 7

                    Repeater {
                        model: root.tuiHits

                        TrayChip {
                            required property var modelData

                            label: modelData.name
                            sub: TermApps.isMissing(modelData.id) ? `NOT INSTALLED  ·  NEEDS ${TermApps.missingCommand(modelData.id).toUpperCase()}` : modelData.sub
                            glyph: modelData.icon
                            iconName: ""
                            missing: TermApps.isMissing(modelData.id)
                            need: TermApps.missingCommand(modelData.id)
                            payload: ({
                                    kind: "tui",
                                    tui: modelData.id,
                                    name: modelData.name,
                                    w: modelData.w,
                                    h: modelData.h
                                })
                        }
                    }
                }

                P5Text {
                    text: root.query ? "MATCHING APPS" : "APPS YOU USE"
                    color: Colours.alpha(Colours.inkDim, 0.7)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }

                Flow {
                    width: parent.width
                    spacing: 7

                    Repeater {
                        model: root.appHits

                        TrayChip {
                            required property var modelData

                            label: modelData.name ?? ""
                            sub: (modelData.genericName || modelData.comment || "APPLICATION").toString().toUpperCase()
                            glyph: "apps"
                            iconName: modelData.icon ?? ""
                            payload: ({
                                    kind: "app",
                                    app: modelData.id,
                                    name: modelData.name,
                                    icon: modelData.icon ?? ""
                                })
                        }
                    }
                }
            }

            SmoothScroll {
                view: trayScroll
            }
        }
    }

    // ══════════════════════════════════════════════════════════════ the side
    Item {
        id: side

        anchors.left: stage.right
        anchors.leftMargin: 26
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // ── what the whole scene can do, in one card
        Plate {
            id: sceneCard

            anchors.left: parent.left
            anchors.right: parent.right
            height: sceneActions.implicitHeight + 24
            radius: Appearance.rounding.normal
            color: Colours.alpha(Colours.surfaceHigh, 0.5)
            border.width: 1
            border.color: Colours.alpha(Colours.ink, 0.08)
            antialiasing: true

            Column {
                id: sceneActions

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                anchors.topMargin: 12
                spacing: 6

            // The wallpaper↔desk link, made visible: this layout belongs to
            // a wallpaper and follows it when the picture changes. One click
            // turns the follow off — the arrangement stays saved either way.
            Plate {
                width: parent.width
                height: 48
                radius: Appearance.rounding.normal
                color: Colours.alpha(Colours.surfaceHigh, 0.6)
                border.width: 1
                border.color: Colours.alpha(Colours.accent, Config.scene.onWallpaperChange ? 0.55 : 0.2)

                Behavior on border.color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "image"
                        color: Colours.accent
                        font.pixelSize: Appearance.font.size.huge
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -1
                        width: parent.width - 60

                        P5Text {
                            width: parent.width
                            text: "DESKTOP FOLLOWS ITS WALLPAPER"
                            color: Colours.ink
                            font.pixelSize: Appearance.font.size.small
                            elide: Text.ElideRight
                        }

                        P5Text {
                            width: parent.width
                            text: `${Scenes.nameOf(Scenes.editingKey)}${Scenes.editingElsewhere ? "  ·  EDITING" : ""}  ·  ${Scenes.saved} SAVED`
                            color: Colours.accentInk
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1.5
                            elide: Text.ElideRight
                        }
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Config.scene.onWallpaperChange ? "ON" : "OFF"
                        color: Config.scene.onWallpaperChange ? Colours.success : Colours.alpha(Colours.inkDim, 0.6)
                        font.pixelSize: Appearance.font.size.small
                        tracking: 2
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Config.set("scene.onWallpaperChange", !Config.scene.onWallpaperChange);
                        Sfx.toggle();
                    }
                }
            }

            // The bigger picture: the taskbar, windows, lock screen … of this
            // wallpaper are one tab over.
            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "tune"
                        color: perLink.hovered ? Colours.accent : Colours.inkDim
                        font.pixelSize: 15
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "TASKBAR, WINDOWS, LOCK … PER WALLPAPER  ›"
                        color: perLink.hovered ? Colours.accent : Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.2
                    }
                }

                HoverHandler {
                    id: perLink

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        Sfx.select();
                        Panels.openSettingsTabNamed("PER WALLPAPER");
                    }
                }
            }

            // Whose desk this is, in plain words — the promise that a
            // wallpaper brings its own widgets back with it.
            Plate {
                id: deskCard

                width: parent.width
                height: deskWords.implicitHeight + 16
                radius: Appearance.rounding.small
                readonly property color tone: Scenes.editingKey === Scenes.anyKey ? Colours.accent : (Scenes.editingHasOwn ? Colours.success : Colours.warning)
                color: Colours.alpha(tone, 0.1)
                border.width: 1
                border.color: Colours.alpha(tone, 0.45)
                antialiasing: true

                Row {
                    id: deskWords

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: Scenes.editingKey === Scenes.anyKey ? "public" : (Scenes.editingHasOwn ? "bookmark_added" : "bookmark_border")
                        color: deskCard.tone
                        font.pixelSize: Appearance.font.size.large
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 30
                        wrapMode: Text.WordWrap
                        text: {
                            if (Scenes.editingKey === Scenes.anyKey)
                                return "THE EVERYWHERE DESK  ·  EVERY WALLPAPER WITHOUT ITS OWN SHOWS THIS";
                            if (Scenes.editingHasOwn)
                                return "THIS WALLPAPER HAS ITS OWN DESK  ·  SWITCH AWAY AND BACK: THESE WIDGETS RETURN EXACTLY AS SET";
                            return "THIS WALLPAPER SHOWS YOUR EVERYWHERE DESK  ·  YOUR FIRST CHANGE HERE GIVES IT ITS OWN";
                        }
                        color: Colours.ink
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 1.2
                    }
                }
            }

            // What is on the table right now — live, in one line.
            P5Text {
                width: parent.width
                text: Scenes.editingStatus
                color: Scenes.editingElsewhere ? Colours.accentInk : Colours.alpha(Colours.inkDim, 0.75)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.6
                elide: Text.ElideRight
            }

            // Widgets placed but the layer that draws them is off: say so, and
            // make the fix one click instead of a hunt through settings.
            MiniButton {
                readonly property bool hasWidgets: Scenes.editing.some(it => it && it.kind === "widget")
                visible: hasWidgets && !(Config.wallpaper.renderer === "builtin" && Config.wallpaper.living && Config.wallpaper.livingWidgets)
                width: parent.width
                label: "WIDGETS ARE HIDDEN · SHOW THEM ON THE WALLPAPER"
                glyph: "visibility"
                accent: true
                onClicked: {
                    if (Config.wallpaper.renderer !== "builtin")
                        Config.set("wallpaper.renderer", "builtin");
                    Scenes.ensureWidgetLayer();
                    Sfx.select();
                }
            }

            // This scene belongs to another wallpaper: its widgets are not on
            // screen now. One click puts them on the wallpaper that is up.
            MiniButton {
                readonly property bool hasWidgets: Scenes.editing.some(it => it && it.kind === "widget")
                visible: hasWidgets && Scenes.editingElsewhere
                width: parent.width
                label: "THIS IS ANOTHER WALLPAPER'S DESK · COPY IT TO THE ONE THAT IS UP"
                glyph: "content_copy"
                onClicked: {
                    Scenes.copyToCurrent(Scenes.editingKey);
                    Sfx.select();
                }
            }

            // The two things you actually do, side by side.
            Row {
                width: parent.width
                spacing: 6

                MiniButton {
                    width: (parent.width - 6) / 2
                    label: "OPEN WHAT IS MISSING"
                    glyph: "play_arrow"
                    accent: true
                    enabled: Scenes.editingCount > 0
                    onClicked: Scenes.launchEditing(false)
                }

                MiniButton {
                    width: (parent.width - 6) / 2
                    label: "CAPTURE WHAT IS OPEN"
                    glyph: "photo_camera"
                    onClicked: Scenes.captureOpen()
                }
            }

            // The rare moves, quiet in one row.
            Row {
                width: parent.width
                spacing: 4

                MiniButton {
                    width: Scenes.editingCanFallBack ? (parent.width - 8) / 3 : (parent.width - 4) / 2
                    label: "USE ON ALL WALLPAPERS"
                    enabled: Scenes.editingCount > 0
                    onClicked: Scenes.makeDefault()
                }

                MiniButton {
                    width: (parent.width - 8) / 3
                    label: "SAME AS EVERYWHERE"
                    visible: Scenes.editingCanFallBack
                    onClicked: {
                        Scenes.useFallback();
                        root.selected = -1;
                    }
                }

                MiniButton {
                    width: Scenes.editingCanFallBack ? (parent.width - 8) / 3 : (parent.width - 4) / 2
                    label: "CLEAR THIS DESK"
                    danger: true
                    enabled: Scenes.editingCount > 0
                    onClicked: {
                        Scenes.clearScene();
                        root.selected = -1;
                    }
                }
            }
            }
        }

        Rectangle {
            id: sep1

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sceneCard.bottom
            anchors.topMargin: 14
            height: 1
            color: Colours.alpha(Colours.ink, 0.08)
        }

        // ── every saved desktop, one list
        //  Click a row to put that scene on the designer's table. The small
        //  buttons open it, copy it onto the wallpaper that is up, or delete
        //  it. The live scene and EVERYWHERE cannot be deleted.
        Item {
            id: savedBox

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sep1.bottom
            anchors.topMargin: 12
            // Folded to its title while a tile is picked: the tile's own
            // settings need the height far more than the list does.
            readonly property bool folded: root.chosen !== null
            height: savedBox.folded ? 18 : Math.max(110, Math.min(240, parent.height * 0.24))

            P5Text {
                text: savedBox.folded ? `SAVED DESKTOPS  ·  ${Scenes.savedList.length}  ·  SHOW` : "SAVED DESKTOPS"
                color: savedBox.folded && foldArea.containsMouse ? Colours.accent : Colours.alpha(Colours.inkDim, 0.7)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 3

                MouseArea {
                    id: foldArea

                    anchors.fill: parent
                    enabled: savedBox.folded
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected = -1
                }
            }

            ListView {
                id: savedList

                visible: !savedBox.folded

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 22
                anchors.bottom: parent.bottom

                model: Scenes.savedList
                spacing: 5
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: SavedSceneRow {
                    required property var modelData

                    width: savedList.width
                    row: modelData
                }

                SmoothScroll {
                    view: savedList
                }
            }
        }

        Rectangle {
            id: sep2

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: savedBox.bottom
            anchors.topMargin: 12
            height: 1
            color: Colours.alpha(Colours.ink, 0.08)
        }

        // ── and what one item can do
        Item {
            id: inspector

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: sep2.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom

            P5Text {
                id: insLabel

                width: inspector.width
                display: root.chosen !== null
                text: root.chosen ? Scenes.labelFor(root.chosen).toUpperCase() : "PICK SOMETHING ON THE SCREEN"
                color: root.chosen ? Colours.ink : Colours.alpha(Colours.inkDim, 0.6)
                font.pixelSize: root.chosen ? Appearance.font.size.large : Appearance.font.size.tiny
                tracking: root.chosen ? 1 : 3
                elide: Text.ElideRight
            }

            P5Text {
                id: insSub

                anchors.top: insLabel.bottom
                anchors.topMargin: 3
                width: inspector.width
                wrapMode: Text.WordWrap
                text: {
                    if (!root.chosen)
                        return "EVERYTHING YOU CAN DO WITH A TILE IS RIGHT HERE";
                    if (root.chosen.kind === "widget")
                        return Scenes.editingKey === Scenes.anyKey ? "PART OF YOUR EVERYWHERE DESK  ·  EVERY CHANGE SHOWS LIVE" : `SAVED WITH ${Scenes.nameOf(Scenes.editingKey).toUpperCase()}  ·  EVERY CHANGE SHOWS LIVE`;
                    const cmd = Scenes.commandFor(root.chosen);
                    if (!cmd)
                        return "NO COMMAND — VELVET DOES NOT KNOW HOW TO START THIS";
                    // The raw command line was four lines of kitty flags that
                    // pushed the settings off the bottom of the screen.
                    const up = Scenes.isRunning(root.chosen);
                    if (root.chosen.kind === "term" || root.chosen.kind === "tui")
                        return up ? "A MODULE IN ITS OWN WINDOW  ·  RUNNING" : "A MODULE IN ITS OWN WINDOW  ·  NOT OPEN YET";
                    return up ? "AN APP  ·  RUNNING" : "AN APP  ·  NOT OPEN YET";
                }
                color: !root.chosen || root.chosen.kind === "widget" ? Colours.alpha(Colours.inkDim, 0.8) : (Scenes.commandFor(root.chosen) ? Colours.alpha(Colours.inkDim, 0.8) : Colours.danger)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }

            // A module (Velvet's own or one of MORE MODULES): every switch it
            // has, from the catalogue, on one scrolling card.
            ModuleInspector {
                id: moduleInspector

                anchors.top: progCol.bottom
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: root.chosen !== null && (root.chosen.kind === "term" || root.chosen.kind === "tui")
                item: root.chosen ?? ({})
                itemIndex: root.selected
                snaps: root.snaps
            }

            // A widget: every option it has, visible, on one scrolling card.
            WidgetInspector {
                id: widgetInspector

                anchors.top: insSub.bottom
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                visible: root.chosen !== null && root.chosen.kind === "widget"
                item: root.chosen ?? ({})
                itemIndex: root.selected
                onPicked: i => root.selected = i
                onRemoveRequested: root.removeChosen()
            }

            // Nothing selected: three quiet hints instead of a dead corner.
            Column {
                anchors.top: insSub.bottom
                anchors.topMargin: 18
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 10
                visible: root.chosen === null

                Repeater {
                    model: [
                        {
                            g: "touch_app",
                            t: "DRAG A TILE TO MOVE IT"
                        },
                        {
                            g: "open_in_full",
                            t: "PULL ITS CORNER TO RESIZE"
                        },
                        {
                            g: "delete",
                            t: "DEL TAKES IT OFF THE DESK"
                        }
                    ]

                    Row {
                        required property var modelData

                        width: parent.width
                        spacing: 10

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.g
                            color: Colours.alpha(Colours.accent, 0.85)
                            font.pixelSize: Appearance.font.size.normal
                        }

                        P5Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 34
                            text: modelData.t
                            color: Colours.alpha(Colours.inkDim, 0.8)
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1.6
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // A widget has its own, far larger card below; this column is
            // for programs: open / take off and where it lives. Everything
            // else a module can be is on the ModuleInspector under it.
            Column {
                id: progCol

                anchors.top: insSub.bottom
                anchors.topMargin: 14
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 6
                visible: root.chosen !== null && root.chosen.kind !== "widget"

                // The two things you do with it, right away.
                Row {
                    width: parent.width
                    spacing: 6

                    // Forcing a launch opened a SECOND window of something
                    // already running. Running → restart it instead.
                    MiniButton {
                        readonly property bool up: root.chosen !== null && Scenes.isRunning(root.chosen)

                        width: (parent.width - 6) * 0.62
                        label: up ? "RESTART IT" : "OPEN IT NOW"
                        glyph: up ? "refresh" : "play_arrow"
                        accent: !up
                        visible: root.chosen?.kind !== "widget"
                        onClicked: {
                            if (up)
                                Scenes.relaunch(root.chosen);
                            else
                                Scenes.launchItem(root.chosen, false);
                        }
                    }

                    MiniButton {
                        width: root.chosen?.kind === "widget" ? parent.width : (parent.width - 6) * 0.38
                        label: "TAKE IT OFF"
                        glyph: "close"
                        danger: true
                        onClicked: root.removeChosen()
                    }
                }

                P5Text {
                    visible: root.chosen?.kind !== "widget"   // wallpaper widgets have no desktop or float
                    text: "PLACEMENT"
                    color: Colours.alpha(Colours.inkDim, 0.7)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 3
                }

                // ── which desktop it opens on
                Item {
                    visible: root.chosen?.kind !== "widget"   // wallpaper widgets have no desktop or float
                    width: parent.width
                    height: 38

                    P5Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "DESKTOP"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 2.4
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5

                        Stepper {
                            glyph: "remove"
                            onPressed: root.bumpWorkspace(-1)
                        }

                        Plate {
                            width: 74
                            height: 26
                            radius: Appearance.rounding.small
                            color: Colours.alpha(Colours.ink, 0.09)
                            antialiasing: true

                            P5Text {
                                anchors.centerIn: parent
                                text: (root.chosen?.ws ?? 0) > 0 ? `${root.chosen.ws}` : "ANY"
                                color: Colours.ink
                                font.pixelSize: Appearance.font.size.small
                                tracking: 1
                            }
                        }

                        Stepper {
                            glyph: "add"
                            onPressed: root.bumpWorkspace(1)
                        }
                    }
                }

                // ── floating or tiled
                Item {
                    visible: root.chosen?.kind !== "widget"   // wallpaper widgets have no desktop or float
                    width: parent.width
                    height: 38

                    P5Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80
                        text: "FLOAT"
                        color: Colours.inkDim
                        font.pixelSize: Appearance.font.size.tiny
                        tracking: 2.4
                        elide: Text.ElideRight
                    }

                    Item {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 58
                        height: 26

                        Plate {
                            anchors.fill: parent
                            radius: Appearance.pill(height)
                            color: (root.chosen?.float ?? true) ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.ink, 0.12)
                            antialiasing: true

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        Plate {
                            width: 20
                            height: 20
                            radius: Appearance.r(10)
                            y: 3
                            x: (root.chosen?.float ?? true) ? parent.width - width - 3 : 3
                            color: Colours.paper
                            antialiasing: true

                            Behavior on x {
                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                    easing.type: Easing.OutBack
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Scenes.patchAt(root.selected, {
                                    float: !(root.chosen?.float ?? true)
                                });
                                Sfx.toggle();
                            }
                        }
                    }
                }

            }
        }
    }

    // ══════════════════════════════════════════════════ what you are carrying
    Item {
        id: ghost

        visible: root.dragging && root.newItem !== null
        x: root.ghostX - width / 2
        y: root.ghostY - height / 2
        width: 128
        height: 44
        z: 200
        opacity: 0.95

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Colours.alpha(Colours.surfaceHigh, 0.96)
            border.width: 1
            border.color: Colours.accent
            antialiasing: true
        }

        P5Text {
            anchors.centerIn: parent
            width: parent.width - 14
            horizontalAlignment: Text.AlignHCenter
            display: true
            text: root.newItem?.name ?? ""
            color: Colours.ink
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }
    }

    // ══════════════════════════════════════════════════════════════ behaviour
    readonly property var snaps: [
        {
            name: "FULL",
            x: 0.02,
            y: 0.03,
            w: 0.96,
            h: 0.94
        },
        {
            name: "LEFT HALF",
            x: 0.02,
            y: 0.03,
            w: 0.47,
            h: 0.94
        },
        {
            name: "RIGHT HALF",
            x: 0.51,
            y: 0.03,
            w: 0.47,
            h: 0.94
        },
        {
            name: "TOP",
            x: 0.02,
            y: 0.03,
            w: 0.96,
            h: 0.46
        },
        {
            name: "BOTTOM",
            x: 0.02,
            y: 0.51,
            w: 0.96,
            h: 0.46
        },
        {
            name: "CENTRE",
            x: 0.2,
            y: 0.18,
            w: 0.6,
            h: 0.64
        },
        {
            name: "CORNER",
            x: 0.7,
            y: 0.06,
            w: 0.28,
            h: 0.3
        }
    ]

    function bumpWorkspace(delta: int): void {
        if (!root.chosen)
            return;
        const now = root.chosen.ws ?? 0;
        const next = Math.max(0, Math.min(24, now + delta));
        Scenes.patchAt(root.selected, {
        ws: next
        });
        if (next > 0)
        root.goTo(next, false);
        Sfx.cursor();
    }

    function removeChosen(): void {
        if (root.selected < 0)
            return;
        Scenes.removeAt(root.selected);
        // Nothing picked afterwards: with the next tile auto-selected, a
        // second click on TAKE IT OFF (or a second Del) removed that one too.
        root.selected = -1;
        Sfx.back();
    }

    function commitDrag(): void {
        if (root.dragIndex >= 0) {
            const it = root.items[root.dragIndex];
            const over = root.dropWs > 0 && root.dropWs !== root.editWs && !root.sizing;
            const r = v => Math.round(v * 1000) / 1000;
            // Dropped on another desktop's number: it goes there, kept on screen.
            const fields = over ? {
                x: r(root.landX),
                y: r(root.landY),
                w: r(root.liveW),
                h: r(root.liveH),
                ws: root.dropWs
            } : {
                x: r(root.liveX),
                y: r(root.liveY),
                w: r(root.liveW),
                h: r(root.liveH)
            };
            // A fixed module put out on the canvas would never be seen again:
            // out there it has to move with the canvas.
            let moved = false;
            if (!over && it && it.kind !== "widget" && Scenes.pinnedOf(it)) {
                const cx = fields.x + fields.w / 2;
                const cy = fields.y + fields.h / 2;
                if (cx < 0 || cx > 1 || cy < 0 || cy > 1) {
                    fields.opts = Object.assign({}, it.opts ?? {}, {
                        canvas: "moves"
                    });
                    moved = true;
                }
            }
            Scenes.patchAt(root.dragIndex, fields);
            Sfx.select();
            if (over) {
                root.selected = -1;
                Toast.ok(`MOVED TO DESKTOP ${root.dropWs}`);
            } else if (moved) {
                Toast.ok("OUT ON THE CANVAS: IT NOW MOVES WITH THE CANVAS");
            }
        }
        root.dragIndex = -1;
        root.sizing = false;
        root.dragging = false;
        root.dropWs = -1;
    }

    // A tray chip landed. Only count it if it landed on the screen.
    function dropNew(globalX: real, globalY: real): void {
        const item = root.newItem;
        root.newItem = null;
        root.dragging = false;
        root.dropWs = -1;
        if (!item)
        return;

        const p = view.mapFromItem(root, globalX, globalY);
        // Let go over a desktop number: that desktop gets it.
        const pill = root.deskAt(p.x, p.y);
        if (pill > 0) {
            root.place(item, pill, 0.5, 0.5);
            if (pill !== root.editWs && item.kind !== "widget")
                root.goTo(pill, false);
            return;
        }
        if (p.x < 0 || p.y < 0 || p.x > view.width || p.y > view.height) {
            Sfx.back();
            return;
        }
        const wx = (p.x - world.x) / root.zoom;
        const wy = (p.y - world.y) / root.zoom;
        root.place(item, root.editWs, wx / root.baseW, wy / root.baseH);
    }

    // The centre of the first place a w×h box fits without covering anything
    // on the desk — scanning from the middle outwards, so a new thing lands
    // where you look first. Falls back to the middle when the desk is full.
    function freeSpot(w: real, h: real): var {
        const taken = root.items;
        const overlaps = (x, y) => {
            for (let i = 0; i < taken.length; i++) {
                const t = taken[i];
                if (!t || !root.onDesk(t))
                continue;
                if (x < (t.x ?? 0) + (t.w ?? 0) && x + w > (t.x ?? 0) && y < (t.y ?? 0) + (t.h ?? 0) && y + h > (t.y ?? 0))
                    return true;
            }
            return false;
        };
        const cands = [];
        const step = 1 / 24;
        for (let y = 0; y <= 1 - h + 1e-6; y += step)
            for (let x = 0; x <= 1 - w + 1e-6; x += step)
                cands.push({
                    x: x,
                    y: y,
                    d: Math.pow(x + w / 2 - 0.5, 2) + Math.pow(y + h / 2 - 0.5, 2)
                });
        cands.sort((a, b) => a.d - b.d);
        for (let i = 0; i < cands.length; i++)
            if (!overlaps(cands[i].x, cands[i].y))
                return Qt.point(cands[i].x + w / 2, cands[i].y + h / 2);
        return Qt.point(0.5, 0.5);
    }

    Keys.onPressed: event => {
        if (search.activeFocus || widgetInspector.typing || moduleInspector.typing)
            return;
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            root.removeChosen();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
        root.stepSelection(-1);
        event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
        root.stepSelection(1);
        event.accepted = true;
        } else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
        root.zoomAt(1.45, view.width / 2, view.height / 2);
        event.accepted = true;
        } else if (event.key === Qt.Key_Minus) {
        root.zoomAt(1 / 1.45, view.width / 2, view.height / 2);
        event.accepted = true;
        } else if (event.key === Qt.Key_0) {
        root.recentre();
        event.accepted = true;
        }
    }

    // ═════════════════════════════════════════════════════ inline components
    component TrayChip: Item {
        id: chip

        property string label: ""
        property string sub: ""
        property string glyph: "apps"
        property string iconName: ""
        property var payload: null
        property bool missing: false
        property string need: ""

        implicitWidth: 176
        implicitHeight: 46
        width: implicitWidth
        height: implicitHeight

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: chip.missing ? Colours.alpha(Colours.surfaceHigh, 0.3) : Colours.alpha(Colours.surfaceHigh, chipArea.containsMouse ? 1 : 0.65)
            border.width: 1
            border.color: chip.missing ? Colours.alpha(Colours.ink, 0.08) : Colours.alpha(Colours.ink, chipArea.containsMouse ? 0.3 : 0.12)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Row {
            id: chipRow

            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.iconName !== ""
                implicitSize: 20
                source: chip.iconName ? Quickshell.iconPath(chip.iconName, "application-x-executable") : ""
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.iconName === ""
                name: chip.glyph
                color: chip.missing ? Colours.alpha(Colours.inkDim, 0.6) : Colours.accent
                font.pixelSize: 18
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 26
                spacing: -1

                P5Text {
                    width: parent.width
                    display: true
                    text: chip.label
                    color: chip.missing ? Colours.alpha(Colours.inkDim, 0.75) : Colours.ink
                    font.pixelSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }

                P5Text {
                    width: parent.width
                    text: chip.sub
                    color: Colours.alpha(Colours.inkDim, 0.65)
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 0.4
                    elide: Text.ElideRight
                }
            }
        }

        MouseArea {
            id: chipArea

            anchors.fill: parent
            // Keep the grab: the tray scrolls, and its Flickable would
            // otherwise steal the drag the moment it heads for the screen.
            preventStealing: true
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            property bool moved: false

            property real fromX: 0
            property real fromY: 0

            onPressed: event => {
                chipArea.moved = false;
                chipArea.fromX = event.x;
                chipArea.fromY = event.y;
            }

            onPositionChanged: event => {
                if (!pressed || chip.missing)
                    return;
                // One pixel of hand jitter used to count as a drag, and the
                // drop then landed back over the tray and was thrown away —
                // so a click added nothing and made a sound like it had.
                if (!chipArea.moved) {
                    if (Math.abs(event.x - chipArea.fromX) + Math.abs(event.y - chipArea.fromY) < 8)
                        return;
                    chipArea.moved = true;
                    root.newItem = chip.payload;
                    root.dragging = true;
                }
                const g = chip.mapToItem(root, event.x, event.y);
                root.ghostX = g.x;
                root.ghostY = g.y;
                root.steerNew();
            }

            onReleased: {
                if (chip.missing) {
                    Toast.warn(`INSTALL ${chip.need.toUpperCase()} TO USE ${chip.label}`);
                    return;
                }
                if (chipArea.moved) {
                    root.dropNew(root.ghostX, root.ghostY);
                } else {
                    // A plain click places it, because dragging is a gesture
                    // you have to already know about — on the first free
                    // spot, not on top of whatever sits in the middle.
                    const spot = root.freeSpot(chip.payload?.w ?? 0.32, chip.payload?.h ?? 0.36);
                    root.newItem = null;
                    root.dragging = false;
                    root.dropWs = -1;
                    root.place(chip.payload, root.editWs, spot.x, spot.y);
                }
                chipArea.moved = false;
            }

            onCanceled: {
                root.newItem = null;
                root.dragging = false;
                root.dropWs = -1;
                chipArea.moved = false;
            }
        }
    }

    // One compact action. The big stacked buttons made the designer feel
    // like a form; these read as tools.
    component MiniButton: Item {
        id: mb

        property string label: ""
        property string glyph: ""
        property bool accent: false
        property bool danger: false

        signal clicked

        height: 30
        opacity: mb.enabled ? 1 : 0.35

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: {
                if (!mb.enabled)
                    return Colours.alpha(Colours.ink, 0.05);
                if (mb.danger)
                    return Colours.alpha(Colours.danger, mbArea.containsMouse ? 0.95 : 0.75);
                if (mb.accent)
                    return Colours.alpha(Colours.accent, mbArea.containsMouse ? 1 : 0.85);
                return Colours.alpha(Colours.ink, mbArea.containsMouse ? 0.16 : 0.08);
            }
            border.width: 1
            border.color: mb.accent && !mb.danger ? Colours.alpha(Colours.accent, 0.3) : Colours.alpha(Colours.ink, 0.1)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: mb.glyph !== ""
                name: mb.glyph
                color: mb.enabled ? (mb.danger ? Colours.on(Colours.danger) : (mb.accent ? Colours.on(Colours.accent) : Colours.inkDim)) : Colours.alpha(Colours.inkDim, 0.4)
                font.pixelSize: 14
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: mb.label
                color: mb.enabled ? (mb.danger ? Colours.on(Colours.danger) : (mb.accent ? Colours.on(Colours.accent) : Colours.ink)) : Colours.alpha(Colours.inkDim, 0.4)
                font.pixelSize: Appearance.font.size.tiny + 1
                tracking: 0.4
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mbArea

            anchors.fill: parent
            hoverEnabled: true
            enabled: mb.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sfx.select();
                mb.clicked();
            }
        }
    }

    component IconButton: Item {
        id: ib

        property string glyph: "chevron_right"
        property bool danger: false

        signal clicked

        width: 26
        height: 26

        Plate {
            anchors.fill: parent
            radius: Appearance.pill(height)
            color: Colours.alpha(ib.danger ? Colours.danger : Colours.ink, ibArea.containsMouse ? 0.3 : 0.1)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Icon {
            anchors.centerIn: parent
            name: ib.glyph
            color: ib.danger ? Colours.danger : Colours.ink
            font.pixelSize: 14
        }

        MouseArea {
            id: ibArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sfx.select();
                ib.clicked();
            }
        }
    }

    component SavedSceneRow: Item {
        id: row

        property var row: null

        height: 48

        // Not `data`: that is the Item's reserved default property, and
        // redeclaring it would refuse to load.
        readonly property var entry: row.row ?? ({})
        readonly property string key: entry.key ?? ""
        readonly property bool live: entry.live === true
        readonly property bool editing: entry.editing === true

        // Copy (replaces the desk you are on) and delete ask twice: the
        // first click arms, the row says what will happen, a second click
        // within three seconds does it. A single stray click used to swap
        // the whole live desk for another one.
        property string armed: ""

        Timer {
            id: disarm

            interval: 3000
            onTriggered: row.armed = ""
        }

        function arm(what: string): bool {
            if (row.armed === what) {
                row.armed = "";
                disarm.stop();
                return true;
            }
            row.armed = what;
            disarm.restart();
            Sfx.toggle();
            return false;
        }

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: row.editing ? Colours.alpha(Colours.accent, 0.85) : Colours.alpha(Colours.ink, rowArea.containsMouse ? 0.14 : 0.06)
            border.width: row.live ? 1 : 0
            border.color: Colours.alpha(Colours.accent, 0.7)
            antialiasing: true

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: rowButtons.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: -1

            P5Text {
                width: parent.width
                display: true
                text: `${entry.name ?? ""}${row.live ? "  ·  UP" : ""}`
                color: row.editing ? Colours.on(Colours.accent) : Colours.ink
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            P5Text {
                width: parent.width
                text: row.armed === "copy" ? "CLICK AGAIN · REPLACES THE DESK YOU ARE ON" : (row.armed === "delete" ? "CLICK AGAIN · DELETES THIS DESK" : `${entry.count ?? 0} ITEM${(entry.count ?? 0) === 1 ? "" : "S"}`)
                color: row.armed !== "" ? Colours.warning : (row.editing ? Colours.alpha(Colours.on(Colours.accent), 0.8) : Colours.inkDim)
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1
                elide: Text.ElideRight
            }
        }

        Row {
            id: rowButtons

            // Above the row's own MouseArea: the whole row is clickable
            // (copy onto the live desktop), but the buttons must still
            // receive their clicks — declared first, they would sit under
            // it and every press would land on the row instead.
            z: 1

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            IconButton {
                glyph: "play_arrow"
                onClicked: Scenes.launchKey(row.key, false, false)
            }
            IconButton {
                glyph: row.armed === "copy" ? "check" : "content_copy"
                visible: !row.live
                danger: row.armed === "copy"
                onClicked: {
                    if (row.arm("copy"))
                        Scenes.copyToCurrent(row.key);
                }
            }
            IconButton {
                glyph: row.armed === "delete" ? "check" : "delete"
                danger: true
                onClicked: {
                    if (row.arm("delete"))
                        Scenes.removeScene(row.key);
                }
            }
        }

        MouseArea {
            id: rowArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                // A click LOOKS: that desk goes on the designer's table to
                // see and edit, and the desk you are on is untouched. (It
                // used to copy the row over the live desk — one stray click
                // replaced everything.) Copying is the button, asked twice.
                Scenes.edit(row.live ? Scenes.key : row.key);
            }
        }
    }

    component Stepper: Item {
        id: st

        property string glyph: "add"

        signal pressed

        width: 26
        height: 26

        Plate {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Colours.alpha(Colours.ink, stArea.containsMouse ? 0.2 : 0.09)
            antialiasing: true
        }

        Icon {
            anchors.centerIn: parent
            name: st.glyph
            color: Colours.ink
            font.pixelSize: 15
        }

        MouseArea {
            id: stArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: st.pressed()
        }
    }
}
