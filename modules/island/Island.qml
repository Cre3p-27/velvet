//  VELVET  ·  modules/island/Island.qml
//  The Dynamic Island — the black pill that owns the top edge now.
//
//  Touching the top edge used to dump the whole minimap on you. Not any
//  more: the island slides in as a small black pill, and everything grows
//  out of it, in one gesture:
//
//    · hold the left button and PULL DOWN      → the active module expands,
//                                                following your hand
//    · hold and SWIPE LEFT or RIGHT            → cycle the four modules; on
//                                                release the pill settles into
//                                                a small text view of the new
//                                                module
//    · a plain CLICK                           → opens or closes the module
//
//  The modules, with the map in the middle of the swipe cycle:
//    0  NOW PLAYING  — MPRIS: cover, titles, transport, progress.
//    1  DESKTOP MAP  — the real minimap. Not drawn here: opening it hands
//                      off to WindowMap, which slides in exactly where the
//                      pill was. Every map feature (dragging windows, the
//                      camera, the keyboard) stays in its proven home.
//                      Both swipe directions reach something from here.
//    2  TASKS        — the workflow list: check things off, type new ones.
//                      (Off when Config.map.islandTasks is false; the
//                      weather and system then close the gap.)
//    3  WEATHER      — now, hi/lo, humidity, the next hours.
//    4  SYSTEM       — CPU, memory, temperature, storage, uptime.
//
//  The MPRIS import is quarantined in services/MprisBridge.qml; the bridge
//  is created here at runtime (the Lyrics pattern), so a Quickshell build
//  without the service loses one module, never the shell.
//
//  ON A SIDE EDGE (POSITION → LEFT EDGE / RIGHT EDGE) it is built for the
//  edge, like a vertical taskbar: a rail of the modules' icons that slides
//  out of the side. Point at it and every module's live line unfolds
//  beside its icon; click an icon (or pull it out of the rail) and that
//  module opens beside the rail; scrub along the rail or turn the wheel to
//  flip between them; hold it for Velly.
//
//  DOCKED (the default) it grows out of the line where the desktop starts —
//  the screen frame, or a taskbar on that edge — square where it meets that
//  line and flared into it, so frame, bar and island read as one surface.
//
//  Like the map, this window eats nothing while closed: the input mask is
//  dead until the island is active on this screen. Hearing the hover is the
//  EdgeSensor strip's job, exactly as before.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

PanelWindow {
    id: root

    required property ShellScreen modelData

    // The optional chain guards a startup instant: the binding can be
    // evaluated once before the Variants model hands over the screen.
    readonly property bool active: Panels.islandScreen === (root.modelData?.name ?? "") && !Panels.windowMap && Config.map.island
    readonly property bool mine: root.modelData === Hypr.focusedScreen

    // Which screen edge it lives on — MODULES → DYNAMIC ISLAND → POSITION.
    // TOP: the middle of the top edge, it drops down and grows both ways.
    // LEFT / RIGHT EDGE: it slides out of that side at ISLAND HEIGHT, stays
    // flush with its edge (16 px in, clear of a taskbar there) and grows into
    // the screen — sideways away from the edge, downwards from the pill.
    readonly property string edge: Appearance.islandEdge
    readonly property bool onSide: root.edge !== "top"
    // 0 → 1 as it slides out of its side edge (the top uses its own y)
    property real slide: root.active ? 1 : 0

    Behavior on slide {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutExpo
        }
    }

    // ── where it meets its edge ─────────────────────────────────────────────
    //  DOCKED (MODULES → DYNAMIC ISLAND → DOCK TO THE EDGE): flush with the
    //  line where the desktop starts on its edge (inside the screen frame,
    //  inside a pinned taskbar there), square on that side, flared into it.
    //  Free: a pill a few pixels off that line. Either way it rises from
    //  BEHIND the line (edgeClip), never across the bar or the frame.
    readonly property bool docked: Config.map.islandDock
    // OVER THE BAR lets a top island cover a top taskbar: then only the
    // frame counts.
    readonly property real topInset: Config.bar.enabled && Config.bar.position === "top" && Config.map.islandPlace === "over" ? (Config.bar.frame ? Math.max(0, Config.bar.frameWidth) : 0) : Appearance.edgeInset("top")
    readonly property real inset: root.edge === "top" ? (root.docked ? root.topInset : 0) : Appearance.edgeInset(root.edge)
    // A docked island also paints a few pixels over the frame, so the
    // frame's outline does not run across its foot.
    readonly property int lip: root.docked ? 3 : 0
    // the soft inner curves where it flares into its edge
    // (an angular look has none: its corners are all square)
    readonly property real fillet: root.docked ? Appearance.r(Math.max(10, Math.min(26, Math.round(Config.bar.frameRounding * 0.45 + 4)))) : 0

    function capsuleX(w: real): real {
        const free = root.docked ? 0 : 12 + Config.map.islandGap;
        if (root.edge === "left")
            return Math.round(root.lip + free - (1 - root.slide) * (w + 40));
        if (root.edge === "right")
            return Math.round(root.width - root.inset - w - free + (1 - root.slide) * (w + 40));
        const x = (root.width - w) / 2 + Config.map.islandShift;
        return Math.round(Math.max(4 + root.fillet, Math.min(root.width - w - 4 - root.fillet, x)));
    }

    // y inside edgeClip
    function capsuleY(h: real): real {
        if (root.onSide)
            return Appearance.edgeY(root.height, h, h);
        if (root.docked)
            return root.active ? root.lip : -h - 14 - root.fillet;
        return root.active ? root.topInset + 10 + Config.map.islandGap : -h - 14;
    }

    // The docked outline as an SVG path in the capsule's own coordinates:
    // drawn once for the top edge (u along the edge, v away from it) and
    // turned onto the side edges — a mirror for the left (its arcs turn
    // the other way), a rotation for the right. `open` leaves out the foot
    // on the frame, for the ring.
    function dockPath(w: real, h: real, open: bool): string {
        const side = root.onSide;
        const W = side ? h : w;
        const H = side ? w : h;
        const R = Math.max(0, Math.min(Appearance.r(24), W / 2, H / 2));
        const f = Math.max(0, Math.min(root.fillet, H - R));
        const lip = root.lip;
        const P = (u, v) => {
            if (root.edge === "left")
                return `${v.toFixed(2)},${u.toFixed(2)}`;
            if (root.edge === "right")
                return `${(w - v).toFixed(2)},${u.toFixed(2)}`;
            return `${u.toFixed(2)},${v.toFixed(2)}`;
        };
        const s1 = root.edge === "left" ? 0 : 1;
        const s0 = 1 - s1;
        let d = open ? `M ${P(-f, 0)}` : `M ${P(-f, -lip)} L ${P(-f, 0)}`;
        d += ` A ${f} ${f} 0 0 ${s1} ${P(0, f)} L ${P(0, H - R)} A ${R} ${R} 0 0 ${s0} ${P(R, H)} L ${P(W - R, H)} A ${R} ${R} 0 0 ${s0} ${P(W, H - R)} L ${P(W, f)} A ${f} ${f} 0 0 ${s1} ${P(W + f, 0)}`;
        if (!open)
            d += ` L ${P(W + f, -lip)} Z`;
        return d;
    }

    // ──────────────────────────────────────────────────────────── the modules
    //  Width and height are the capsule's full size once the module is open;
    //  closed, the capsule is just the pill row (38 px) on top. The TASKS
    //  module exists only when it is switched on — the array shrinks and the
    //  swipe cycle closes over the gap.
    //  Every module keeps its slot by name. The numbers used to be spelled out
    //  in five places — the array, the pill text, the pill glyph, the body
    //  loader and a comment — so switching the TASKS module off moved all of
    //  them at once and the assistant had nowhere to stand. One table now:
    //  everything else asks it.
    //
    //    0  NOW PLAYING     1  DESKTOP MAP
    //    2  TASKS (opt)     3/2  WEATHER     4/3  SYSTEM     5/4  VELLY (opt)
    //
    readonly property int deskIdx: 1
    readonly property int tasksIdx: Config.map.islandTasks ? 2 : -1
    readonly property int weatherIdx: Config.map.islandTasks ? 3 : 2
    readonly property int systemIdx: Config.map.islandTasks ? 4 : 3
    readonly property int vellyIdx: Config.velly.enabled ? (Config.map.islandTasks ? 5 : 4) : -1

    readonly property var meta: {
        const out = [
            { w: 380, h: 396, glyph: "music_note" },
            { w: root.mapW, h: root.mapH, glyph: "apps" }
        ];
        if (Config.map.islandTasks)
            out.push({ w: 380, h: 372, glyph: "checklist" });
        out.push({ w: 430, h: 356, glyph: "cloud" });
        out.push({ w: 400, h: 336, glyph: "memory" });
        // The assistant gets the tallest capsule of the lot: orb, answer,
        // tool chips and an input row all live inside it.
        if (Config.velly.enabled)
            out.push({ w: 462, h: 560, glyph: "auto_awesome" });
        return out;
    }

    // ── the DESKTOP module's size: the canvas keeps the monitor's shape and
    // takes MAP SIZE (MODULES → DESKTOP MAP) of the screen's width, never so
    // much that the island leaves no room round it.
    readonly property real mapAspect: {
        const m = Desk.focusedMonitor;
        return m && m.h > 0 ? m.w / m.h : Math.max(1, root.width) / Math.max(1, root.height);
    }
    readonly property int mapFieldW: {
        let w = Math.round(Math.max(520, Math.min(root.width - 240, root.width * Math.max(0.24, Config.map.plateWidth))));
        const roomH = Math.max(240, root.height - 330);
        if (w / root.mapAspect > roomH)
            w = Math.round(roomH * root.mapAspect);
        return Math.max(420, w);
    }
    readonly property int mapW: root.mapFieldW + 28
    readonly property int mapH: root.pillH + 4 + 34 + 8 + Math.round(root.mapFieldW / root.mapAspect) + 8 + 34 + 10

    // The island starts on the map, in the middle of the swipe cycle:
    // music lies left of it, tasks/weather/system right.
    property int moduleIdx: 1
    property int previewIdx: 1

    // Turning the TASKS module off (or on) reshapes the cycle — clamp the
    // cursor into the new array instead of leaving it in a gap.
    onMetaChanged: {
        root.moduleIdx = Math.max(0, Math.min(root.meta.length - 1, root.moduleIdx));
        root.previewIdx = root.moduleIdx;
    }
    // After the first swipe or open, the pill keeps a small text view of the
    // active module instead of the bare dots.
    property bool touched: false

    // What the pill says, live from the services. Short enough to read in
    // one glance; the label elides the rest.
    function pillText(i: int): string {
        if (i === 0) {
            if (!(root.bridge?.has ?? false))
                return "NOTHING PLAYING";
            const t = root.bridge.title;
            const a = root.bridge.artist;
            return a.length > 0 ? `${t}  ·  ${a}` : t;
        }
        if (i === root.deskIdx) {
            const ws = Desk.homeCell?.ws ?? 1;
            const n = Desk.windows.filter(w => w.ws === ws).length;
            return `MAP  ·  DESKTOP ${ws}  ·  ${n} WINDOW${n === 1 ? "" : "S"}`;
        }
        if (i === root.tasksIdx)
            return `TASKS  ·  ${Tasks.pill}`;
        if (i === root.weatherIdx) {
            if (!Config.services.weather)
                return "WEATHER OFF";
            if (!Weather.ready)
                return "WEATHER  ·  —";
            return `${Math.round(Weather.temperature)}°  ·  ${Weather.description.toUpperCase()}`;
        }
        // The assistant writes her own one-line answer: she knows whether she
        // is listening, thinking or has no key — the island does not.
        if (i === root.vellyIdx)
            return Velly.pill;
        return `CPU ${Math.round(SysInfo.cpuPercent)}%  ·  RAM ${SysInfo.memoryUsedGb.toFixed(1)}G`;
    }

    function pillGlyph(i: int): string {
        if (i === root.deskIdx)
            return "apps";
        if (i === 0)
            return "music_note";
        if (i === root.tasksIdx)
            return "checklist";
        if (i === root.weatherIdx)
            return Weather.ready ? Weather.icon : "cloud";
        if (i === root.vellyIdx)
            return Velly.glyph;
        return "memory";
    }

    // ─────────────────────────────────────────────── the MPRIS bridge (late)
    //  The same runtime creation Lyrics uses: the MPRIS service is a
    //  build-time option, so the import lives in MprisBridge.qml and the
    //  shell never dies over it. One bridge per island instance.
    property var bridge: null
    property string bridgeError: ""

    function makeBridge(): void {
        if (root.bridge !== null || root.bridgeError !== "")
            return;
        const comp = Qt.createComponent(Qt.resolvedUrl("../../services/MprisBridge.qml"), Component.PreferSynchronous);
        if (comp.status === Component.Error) {
            root.bridgeError = comp.errorString().trim();
            console.warn("Velvet: island — MPRIS unavailable:", root.bridgeError);
            return;
        }
        const obj = comp.createObject(root);
        if (!obj) {
            root.bridgeError = "MprisBridge.qml could not be created";
            console.warn("Velvet: island —", root.bridgeError);
            return;
        }
        root.bridge = obj;
    }

    Timer {
        running: true
        interval: 1
        onTriggered: root.makeBridge()
    }

    // ───────────────────────────────────────────────────────────── the gesture
    property bool pressed: false
    property string axis: ""      // "", "h" or "v" — locked on the first clear move
    property real dragDX: 0
    property real dragDY: 0
    property real progress: 0     // 0…1, vertical pull
    property bool expanded: false

    // ──────────────────────────────────────────────────────── the long press
    //  Holding the pill without moving it wakes Velly: the assistant lives
    //  behind the same surface as everything else, and asking for her is a
    //  press you keep, not a button you have to find.
    //
    //  The press is not the hold. It first has to hold still for a beat, and
    //  only then do the riser, the hairline and the timer start together — so
    //  a pull-down and a module swipe never charge at you, and the gesture
    //  stays as quiet as it looks. The moment the pointer commits to a drag,
    //  the charge is disarmed and the riser is cut off mid-note.
    //
    //  A press that fired her sets `consumed`, and the release that follows is
    //  swallowed instead of read as a click. Without that flag the hold would
    //  wake her and then immediately toggle the capsule shut again.
    property bool arming: false
    property bool consumed: false

    // The hold time is the sum of the parts: a beat of intent, then the
    // charge. Config.velly.longPress still means the whole gesture.
    readonly property int holdMs: Math.max(320, Config.velly.longPress)
    readonly property int intentMs: 150
    readonly property int armMs: Math.max(170, root.holdMs - root.intentMs)

    function awaitIntent(): void {
        if (root.vellyIdx < 0 || root.consumed)
            return;
        intentTimer.restart();
    }

    function armHold(): void {
        if (root.vellyIdx < 0)
            return;
        root.arming = true;
        Sfx.charge();
        armTimer.restart();
    }

    function disarm(): void {
        if (root.arming)
            Sfx.stopCharge();
        root.arming = false;
        intentTimer.stop();
        armTimer.stop();
    }

    function fireVelly(): void {
        root.disarm();
        root.consumed = true;
        root.pressed = false;
        root.axis = "";
        root.progress = 0;
        root.moduleIdx = root.vellyIdx;
        root.previewIdx = root.vellyIdx;
        root.touched = true;
        Velly.wake();
        if (!root.expanded) {
            root.expanded = true;
            Sfx.open();
        }
        Sfx.whoosh();
        root.poke();
    }

    Timer {
        id: intentTimer

        interval: root.intentMs
        onTriggered: {
            if (root.pressed && root.axis === "" && !root.consumed)
                root.armHold();
        }
    }

    Timer {
        id: armTimer

        interval: root.armMs
        onTriggered: root.fireVelly()
    }

    readonly property int pillH: 38
    readonly property int restW: Math.max(220, Config.map.islandWidth)
    readonly property real travel: 300

    // ── the rail (side edges) ───────────────────────────────────────────────
    //  One cell per module, the order of the swipe cycle, top to bottom.
    readonly property int railW: 48
    readonly property int cellH: 44
    readonly property int railPad: 8
    readonly property real railH: root.meta.length * root.cellH + root.railPad * 2
    // the rail's y on screen: centred on ISLAND HEIGHT (+ the nudge)
    readonly property real railTop: Appearance.edgeY(root.height, root.railH, root.railH)
    // the live lines that unfold beside the rail
    readonly property int labelW: 300
    property int railHot: -1
    property int pressIdx: -1
    readonly property int shownIdx: root.pressed && root.axis === "h" ? root.previewIdx : root.moduleIdx
    readonly property bool sideLabels: root.onSide && !root.expanded && !(root.pressed && root.axis === "v") && (root.hoverPeek || (root.pressed && root.axis === "h"))
    readonly property real sideFullW: root.railW + root.meta[root.moduleIdx].w
    readonly property real sideFullH: Math.max(root.railH, root.meta[root.moduleIdx].h)
    readonly property bool sideOpen: root.onSide && (root.expanded || (root.pressed && root.axis === "v"))

    readonly property bool showText: root.touched || root.pressed || root.expanded || root.hoverPeek

    // Hover-peek: resting the mouse on the untouched pill grows it into the
    // text view after a beat — a tooltip that never needed a click. The
    // delay keeps a passing cursor from making the pill twitch.
    property bool hoverPeek: false

    Timer {
        id: peekDelay

        interval: 180
        // On a side edge the rail's lines unfold on every visit: the icons
        // alone do not say what is playing or how warm it is.
        onTriggered: root.hoverPeek = (root.onSide || !root.touched) && !root.pressed
    }

    function ease(t: real): real {
        const p = Math.max(0, Math.min(1, t));
        return p * p * (3 - 2 * p);
    }

    readonly property real textW: Math.min(480, Math.max(restW, 48 + Math.min(320, pillLabel.implicitWidth) + 10 + 41 + 20))

    readonly property real shellW: {
        const m = root.meta[root.moduleIdx];
        if (root.onSide) {
            const rest = root.railW + (root.sideLabels ? root.labelW : 0);
            if (root.expanded)
                return root.sideFullW;
            if (root.pressed && root.axis === "v")
                return rest + (root.sideFullW - rest) * root.ease(root.progress);
            return rest;
        }
        if (root.expanded)
            return m.w;
        if (root.pressed && root.axis === "v") {
            const from = root.showText ? root.textW : root.restW;
            return from + (m.w - from) * root.ease(root.progress);
        }
        return root.showText ? root.textW : root.restW;
    }

    readonly property real shellH: {
        if (root.onSide) {
            if (root.expanded)
                return root.sideFullH;
            if (root.pressed && root.axis === "v")
                return root.railH + (root.sideFullH - root.railH) * root.ease(root.progress);
            return root.railH;
        }
        if (root.expanded)
            return root.meta[root.moduleIdx].h;
        if (root.pressed && root.axis === "v")
            return root.pillH + (root.meta[root.moduleIdx].h - root.pillH) * root.ease(root.progress);
        return root.pillH;
    }

    // ── the island's face — MODULES → DYNAMIC ISLAND → ISLAND THEME.
    //  INK BLACK: the classic solid pill. GLASS: a dark frost — Hyprland
    //  blurs the desktop behind it (HyprConf's layer rule), the tint keeps
    //  ink legible and a soft sheen from above does the rest. WALLPAPER: a
    //  prominence-weighted mix of the picture's own colours. FRAME: the
    //  screen frame's (and a connected bar's) own colour — docked, island,
    //  frame and bar are one surface. TONE: the accent's deep shade. All of
    //  them honour ISLAND OPACITY.
    readonly property string theme: Config.map.islandTheme
    readonly property bool glassy: root.theme === "glass"
    readonly property color shellCol: {
        const op = Config.map.islandOpacity;
        switch (root.theme) {
        case "glass":
            return Colours.light ? Colours.alpha(Colours.surface, Math.max(0.42, 0.66 * op)) : Qt.rgba(0.016, 0.018, 0.024, Math.max(0.36, 0.56 * op));
        case "wallpaper":
            return Colours.alpha(Colours.wallpaperTint, 0.97 * op);
        case "frame":
            return Colours.alpha(Colours.frameBase, Math.max(0.2, Math.min(1, Config.bar.frameOpacity)) * op);
        case "tone":
            return Colours.alpha(Colours.tone, op);
        default:
            // A light ground gives the island a light face, so its ink stays ink.
            return Colours.light ? Colours.alpha(Colours.surfaceHigh, op) : Qt.rgba(0.019, 0.019, 0.021, op);
        }
    }
    // glass catches light at the top: the sheen's first stop
    readonly property color sheenCol: Qt.rgba(Math.min(1, root.shellCol.r + 0.10), Math.min(1, root.shellCol.g + 0.10), Math.min(1, root.shellCol.b + 0.11), Math.min(1, root.shellCol.a + 0.08))

    // Docked into a frame that has an OUTLINE, the island carries that very
    // line round itself — the frame's edge bends round the island.
    readonly property bool frameLine: root.docked && Config.bar.frame && Config.bar.frameOutline
    readonly property real ringW: root.frameLine ? 1.5 : 1

    // The capsule's ring: a quiet ink line on black, a brighter rim on glass
    // (glass catches light at its edge), the accent glowing on wallpaper;
    // none where a docked FRAME island is the frame.
    readonly property color shellRing: {
        if (root.frameLine)
            return Colours.alpha(Colours.accent, 0.5);
        if (root.theme === "frame" && root.docked)
            return "transparent";
        if (root.theme === "dark" || root.theme === "frame" || root.theme === "tone")
            return Colours.alpha(Config.map.islandAccent ? Colours.accent : Colours.ink, Config.map.islandAccent ? 0.26 : 0.18);
        if (root.theme === "glass")
            return Colours.alpha(Config.map.islandAccent ? Colours.accent : Colours.ink, Config.map.islandAccent ? 0.5 : 0.3);
        return Colours.alpha(Config.map.islandAccent ? Colours.accent : Colours.ink, 0.5);
    }

    function poke(): void {
        openWatchdog.restart();
    }

    function openModule(): void {
        root.touched = true;
        // The map opens right here now, like every other module — it used to
        // hand off to a second window that slid in somewhere else.
        if (!root.expanded) {
            root.expanded = true;
            Sfx.open();
        }
    }

    // Asked for from outside — a settings row, an IPC call, the assistant's
    // own "show me" — so the island does not have to know module indices.
    function openVelly(): void {
        if (root.vellyIdx < 0)
            return;
        Velly.wantIsland = false;
        root.moduleIdx = root.vellyIdx;
        root.previewIdx = root.vellyIdx;
        root.touched = true;
        if (!root.expanded) {
            root.expanded = true;
            Sfx.open();
        }
        root.poke();
    }

    // A tab of the open island (or Ctrl+Tab): straight to that module.
    function switchTo(i: int): void {
        root.poke();
        if (i < 0 || i >= root.meta.length || i === root.moduleIdx)
            return;
        root.moduleIdx = i;
        root.previewIdx = i;
        root.touched = true;
        if (!root.expanded) {
            root.expanded = true;
            Sfx.open();
        } else {
            Sfx.cursor();
        }
    }

    // Asked for by the map shortcut, the bar's map button or a menu.
    function openMap(): void {
        Panels.islandWantMap = false;
        root.moduleIdx = root.deskIdx;
        root.previewIdx = root.deskIdx;
        root.touched = true;
        if (!root.expanded) {
            root.expanded = true;
            Sfx.open();
        }
        root.poke();
    }

    readonly property bool mapOpen: root.active && root.expanded && root.moduleIdx === root.deskIdx
    onMapOpenChanged: {
        if (root.mapOpen)
            Panels.islandMapOpen = true;
        else if (root.mine || !Panels.islandMapOpen)
            Panels.islandMapOpen = false;
    }

    Connections {
        target: Panels

        function onIslandWantMapChanged(): void {
            if (Panels.islandWantMap && root.active)
                root.openMap();
        }
    }

    // what the open module is busy with (a window dragged on the map): the
    // island must not close under that hand
    readonly property bool bodyBusy: body.item !== null && body.item.busy === true

    Connections {
        target: Velly

        function onWantIslandChanged(): void {
            if (Velly.wantIsland && root.active)
                root.openVelly();
        }
    }

    // ── the gesture, for the pill row (top) and the rail (sides) alike ──────
    //  Positions come in the window's own coordinates: the capsule moves and
    //  grows under the pointer while you drag, its children's do not hold.
    //  "out" is away from the island's edge (down from the top, into the
    //  screen from a side), "along" runs with the edge.
    property real gStartX: 0
    property real gStartY: 0
    property real lastWheel: 0

    function railIdxAt(py: real): int {
        const i = Math.floor((py - root.railTop - root.railPad) / root.cellH);
        return i >= 0 && i < root.meta.length ? i : -1;
    }

    function gesturePress(px: real, py: real, idx: int): void {
        root.poke();
        root.gStartX = px;
        root.gStartY = py;
        root.pressed = true;
        root.axis = "";
        root.dragDX = 0;
        root.dragDY = 0;
        root.pressIdx = idx;
        root.awaitIntent();
    }

    function gestureMove(px: real, py: real): void {
        if (!root.pressed)
            return;
        const dx = px - root.gStartX;
        const dy = py - root.gStartY;
        const out = root.edge === "left" ? dx : (root.edge === "right" ? -dx : dy);
        const along = root.onSide ? dy : dx;
        root.dragDX = along;
        root.dragDY = out;
        if (root.axis === "") {
            if (Math.abs(along) > 14) {
                root.axis = "h";
                Sfx.cursor();
            } else if (out > 12) {
                root.axis = "v";
                // pulled out of the rail: the module you took hold of
                if (root.onSide && root.pressIdx >= 0 && root.pressIdx !== root.moduleIdx) {
                    root.moduleIdx = root.pressIdx;
                    root.previewIdx = root.pressIdx;
                }
            }
            if (root.axis !== "")
                root.disarm();
        }
        if (root.axis === "v") {
            root.progress = root.ease((out - 12) / root.travel);
        } else if (root.axis === "h") {
            const n = root.meta.length;
            if (root.onSide && root.pressIdx >= 0) {
                const i = root.railIdxAt(py);
                root.previewIdx = i >= 0 ? i : (py < root.railTop ? 0 : n - 1);
            } else {
                root.previewIdx = (root.moduleIdx + (along > 0 ? 1 : -1) + n) % n;
            }
        }
    }

    // The wheel is the third way to browse: the modules cycle like a
    // carousel. On the top pill only while it rests (open, the wheel is the
    // module's); on the rail always — open, it flips the open module (past
    // the map, which never opens here). Trackpads emit a burst per flick: a
    // short gate keeps one flick from spinning through every module.
    function gestureWheel(dy: real): void {
        if (root.pressed || (root.expanded && !root.onSide) || dy === 0)
            return;
        const t = Date.now();
        if (t - root.lastWheel < 140)
            return;
        root.lastWheel = t;
        root.poke();
        const n = root.meta.length;
        const step = dy < 0 ? 1 : -1;
        const next = (root.moduleIdx + step + n) % n;
        root.moduleIdx = next;
        root.previewIdx = next;
        root.touched = true;
        Sfx.cursor();
    }

    function commit(): void {
        // A hold that already fired Velly owns this release.
        if (root.consumed) {
            root.consumed = false;
            root.pressed = false;
            root.axis = "";
            root.progress = 0;
            return;
        }
        const ax = root.axis;
        const dx = root.dragDX;
        const at = root.pressIdx;
        root.pressed = false;
        root.pressIdx = -1;
        if (ax === "h") {
            // the rail scrubs: where you let go is the module
            if (root.onSide ? root.previewIdx !== root.moduleIdx : Math.abs(dx) >= 70) {
                root.moduleIdx = root.previewIdx;
                root.touched = true;
                Sfx.cursor();
            }
            root.previewIdx = root.moduleIdx;
        } else if (ax === "v") {
            if (root.progress >= 0.5)
                root.openModule();
        } else if (at >= 0) {
            // A click on one of the rail's icons: that module, open — or,
            // when it is the one already open, closed again.
            if (root.expanded && root.moduleIdx === at) {
                root.expanded = false;
                Sfx.back();
            } else if (root.expanded) {
                root.moduleIdx = at;
                root.previewIdx = at;
                root.touched = true;
                Sfx.cursor();
            } else {
                root.moduleIdx = at;
                root.previewIdx = at;
                root.openModule();
            }
        } else {
            // A plain click: the module opens or closes.
            if (root.expanded) {
                root.expanded = false;
                Sfx.back();
            } else {
                root.openModule();
            }
        }
        root.axis = "";
        root.progress = 0;
    }

    function abort(): void {
        root.pressed = false;
        root.pressIdx = -1;
        root.axis = "";
        root.progress = 0;
        root.previewIdx = root.moduleIdx;
    }

    function dismissQuiet(): void {
        // Closing the island closes the session: the microphone and the brain
        // are children of this shell and they go with it — nothing stays
        // listening behind a closed capsule.
        if (Velly.active || Velly.lingering)
            Velly.sleep();
        Panels.islandScreen = "";
        root.expanded = false;
        root.progress = 0;
        root.pressed = false;
        root.axis = "";
        root.previewIdx = root.moduleIdx;
        root.hoverPeek = false;
        peekDelay.stop();
    }

    function dismiss(): void {
        if (root.expanded)
            Sfx.close();
        dismissQuiet();
    }

    onActiveChanged: {
        if (root.active) {
            openWatchdog.restart();
            if (Panels.islandWantMap)
                root.openMap();
            else if (Velly.wantIsland)
                root.openVelly();
        } else {
            root.disarm();
            root.expanded = false;
            root.progress = 0;
            root.pressed = false;
            root.axis = "";
            root.previewIdx = root.moduleIdx;
        }
    }

    // Created when it is first needed (shell.qml, Parked): `active` is then
    // already true, so say it once more.
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (root.active)
                root.activeChanged();
        }
    }

    // IPC test hook: `qs -c velvet ipc call island module 1` jumps the active
    // island to a module, one-off; `expand 2` opens it the same way the
    // gesture does (expand 0 hands off to the map), `expand -1` collapses.
    Connections {
        target: Panels

        function onIslandSetModuleChanged(): void {
            if (root.active && Panels.islandSetModule >= 0) {
                root.moduleIdx = Panels.islandSetModule;
                root.touched = true;
                Panels.islandSetModule = -1;
            }
        }

        function onIslandSetExpandChanged(): void {
            // -2 is "nothing asked": the reset below fires this handler once
            // more, and reading it as "collapse" shut every IPC expand again
            // in the same breath
            if (!root.active || Panels.islandSetExpand === -2)
                return;
            if (Panels.islandSetExpand < 0) {
                root.expanded = false;
            } else {
                root.moduleIdx = Panels.islandSetExpand;
                root.openModule();
            }
            Panels.islandSetExpand = -2;
        }
    }

    // ═══════════════════════════════════════════════════════════════ the window
    screen: modelData
    color: "transparent"
    WlrLayershell.namespace: "velvet-island"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.expanded && root.mine ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: -1

    visible: Config.map.enabled && Config.map.island

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    // Input while the island is up, silence while it is closed — the same
    // mask pattern as the map. The EdgeSensor strip hears the hover.
    mask: Region {
        item: root.active ? inputArea : deadZone
    }

    // Also the island's own coordinate frame for the gestures: `root` is the
    // WINDOW here, not an Item, and mapToItem(root, …) threw on every press
    // (v8.49 live: no hold, no click, no Velly — the harness had an Item root).
    Item {
        id: inputArea

        anchors.fill: parent
    }

    Item {
        id: deadZone

        width: 0
        height: 0
    }

    // Clicking anywhere off the capsule dismisses the island. The capsule
    // sits above this area, so its own clicks never reach it.
    MouseArea {
        anchors.fill: parent
        enabled: root.active
        onClicked: root.dismiss()
    }

    // Escape closes the island while a module is open.
    Item {
        id: keyboard

        anchors.fill: parent
        focus: root.expanded && root.mine
        // the open module may want the keys (the map: arrows, Enter, Del …)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.dismiss();
                event.accepted = true;
                return;
            }
            // Ctrl+Tab / Ctrl+Shift+Tab: the next / previous module
            if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && (event.modifiers & Qt.ControlModifier)) {
                const n = root.meta.length;
                const back = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier);
                root.switchTo((root.moduleIdx + (back ? -1 : 1) + n) % n);
                event.accepted = true;
                return;
            }
            if (body.item && typeof body.item.handleKey === "function" && body.item.handleKey(event)) {
                root.poke();
                event.accepted = true;
            }
        }
    }

    // Everything that counts as "still using the island" — the capsule and a
    // generous margin, the same shield trick the map uses.
    Item {
        id: shield

        readonly property int span: Math.max(capsule.width + 220, Math.max(80, Config.map.edgeWidth) + 44)
        // on a side edge: the capsule and its margin, reaching the edge, and
        // at least the whole hot zone that raised it (the pointer may still
        // be up there when the pill slides out)
        readonly property real zone: Math.max(80, Config.map.edgeWidth) + 44
        readonly property real cx: edgeClip.x + capsule.x
        readonly property real cy: edgeClip.y + capsule.y
        readonly property real mid: root.railTop + root.railH / 2
        readonly property real sideTop: Math.min(cy - 44, mid - zone / 2)
        readonly property real sideBottom: Math.max(cy + capsule.height + 44, mid + zone / 2)

        x: root.edge === "left" ? 0 : (root.edge === "right" ? shield.cx - 44 : Math.round(shield.cx + capsule.width / 2 - shield.span / 2))
        y: root.onSide ? shield.sideTop : 0
        width: root.edge === "left" ? shield.cx + capsule.width + 44 : (root.edge === "right" ? root.width - shield.cx + 44 : shield.span)
        height: root.onSide ? shield.sideBottom - shield.sideTop : shield.cy + capsule.height + 44

        z: 50

        HoverHandler {
            id: keepHover

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
        onTriggered: {
            if (keepHover.hovered)
                return;
            if (root.pressed || root.bodyBusy) {
                closeTimer.restart();
                return;
            }
            root.dismissQuiet();
        }
    }

    // Hard watchdog: three quiet minutes close the island, like the map.
    // "Quiet" means no drag AND no hover — a hand resting on the pill while
    // a module is open must not have the island pulled out from under it.
    Timer {
        id: openWatchdog

        interval: 180000
        onTriggered: {
            // A conversation is not "quiet". While she is hearing, thinking or
            // speaking — or the user is mid-sentence — the watchdog waits.
            // Measured: three quiet minutes slept a session in the middle of a
            // talk, and the sentence being recorded was never answered.
            const busy = Velly.active && (Velly.hearing || Velly.talking
                || Velly.phase === "thinking" || Velly.phase === "speaking");
            if (keepHover.hovered || root.pressed || root.bodyBusy || busy) {
                openWatchdog.restart();
                return;
            }
            // Three quiet minutes end an open session first: a microphone must
            // not outlive your attention by more than the time it takes to
            // walk away and come back.
            if (Velly.active)
                console.warn("ISLAND: watchdog slept Velly after three quiet minutes");
            console.warn("ISLAND: watchdog closed the island after three quiet minutes");
            root.dismissQuiet();
        }
    }

    // ═════════════════════════════════════════════════════════════ the capsule
    //  Everything lives inside the line where the desktop starts on the
    //  island's edge (plus the docked lip): rising or sliding out, the island
    //  comes from behind the frame or the taskbar there, never across them.
    Item {
        id: edgeClip

        x: root.edge === "left" ? root.inset - root.lip : 0
        y: root.edge === "top" ? root.inset - root.lip : 0
        width: root.edge === "left" ? root.width - x : (root.edge === "right" ? root.width - root.inset + root.lip : root.width)
        height: root.height - y
        clip: true
        z: 10

        // DOCKED: one shape for the island AND its flared foot, so the curves
        // into the frame have no seam. The ring leaves the foot out.
        Shape {
            id: dockShape

            x: capsule.x
            y: capsule.y
            width: capsule.width
            height: capsule.height
            scale: capsule.scale
            visible: root.docked
            preferredRendererType: Shape.CurveRenderer

            LinearGradient {
                id: sheen

                x1: 0
                y1: 0
                x2: 0
                y2: Math.max(60, dockShape.height * 0.5)

                GradientStop {
                    position: 0
                    color: root.sheenCol
                }
                GradientStop {
                    position: 1
                    color: root.shellCol
                }
            }

            ShapePath {
                fillColor: root.shellCol
                fillGradient: root.glassy ? sheen : null
                strokeColor: "transparent"
                strokeWidth: 0

                PathSvg {
                    path: root.dockPath(capsule.width, capsule.height, false)
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.shellRing
                strokeWidth: root.ringW

                PathSvg {
                    path: root.dockPath(capsule.width, capsule.height, true)
                }
            }
        }

        Item {
            id: capsule

            // the top pill leans into a sideways swipe; the rail stays put
            // (it scrubs — it must not move under the pointer)
            readonly property real wobble: !root.onSide && root.axis === "h" ? Math.max(-30, Math.min(30, root.dragDX * 0.12)) : 0
            // the rail's y inside the capsule: fixed on screen while the
            // capsule grows round it
            readonly property real railY: root.railTop - edgeClip.y - capsule.y

            x: root.capsuleX(capsule.width) + capsule.wobble
            y: root.capsuleY(capsule.height)
            width: root.shellW
            height: root.shellH
            scale: root.expanded ? 1 : (root.pressed && root.axis === "v" && !root.onSide ? 0.985 : 1)
            clip: true

            HoverHandler {
                id: peekHover

                onHoveredChanged: {
                    if (hovered)
                        peekDelay.restart();
                    else {
                        peekDelay.stop();
                        root.hoverPeek = false;
                    }
                }
            }

            // On a side edge x and y follow the width/height spring and the
            // slide exactly (the edge it keeps to must not wobble); on top it
            // settles with its own ease.
            Behavior on x {
                enabled: !root.pressed && !root.onSide
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutExpo
                }
            }
            Behavior on y {
                enabled: !root.pressed && !root.onSide
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutExpo
                }
            }
            Behavior on width {
                enabled: !root.pressed
                // A spring, like the height: the two edges of the capsule
                // settle together instead of one snapping and the other
                // sagging behind.
                SpringAnimation {
                    spring: 2.6
                    damping: 0.74
                    epsilon: 0.01
                }
            }
            Behavior on height {
                enabled: !root.pressed
                SpringAnimation {
                    spring: 2.4
                    damping: 0.72
                    epsilon: 0.01
                }
            }
            // Opening is a small pop, closing a small settle — the same
            // spring language as every button in the shell.
            Behavior on scale {
                enabled: !root.pressed
                SpringAnimation {
                    spring: 2.2
                    damping: 0.7
                    epsilon: 0.01
                }
            }

            // FREE: one surface, a pill when closed, a sheet when open. The
            // radius follows the height, so the capsule never shows a corner
            // seam. (Docked, dockShape above draws the surface.)
            Plate {
                id: shell

                anchors.fill: parent
                visible: !root.docked
                radius: Appearance.r(Math.min(24, Math.min(capsule.width, capsule.height) / 2))
                color: root.shellCol
                clip: true
                border.width: shell.decorated ? 1 : 0
                border.color: root.shellRing

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.normal
                    }
                }

                Halftone {
                    anchors.fill: parent
                    visible: !root.glassy
                    strength: 0.045
                    density: 1.6
                }

                Rectangle {
                    anchors.fill: parent
                    visible: !shell.decorated
                    radius: parent.radius
                    color: "transparent"
                    border.width: 1
                    border.color: root.shellRing
                    antialiasing: true

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Appearance.anim.normal
                        }
                    }
                }

                // GLASS: the sheen — light catching the top edge and falling
                // away down the pane. This plus the frost is what reads as
                // glass.
                Rectangle {
                    anchors.fill: parent
                    visible: root.glassy
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Colours.alpha(Colours.ink, 0.10)
                        }
                        GradientStop {
                            position: Math.min(1, 60 / Math.max(60, shell.height))
                            color: Colours.alpha(Colours.ink, 0.03)
                        }
                        GradientStop {
                            position: 1.0
                            color: "transparent"
                        }
                    }
                    antialiasing: true
                }

                // GLASS: the crisp rim of light along the top edge.
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.leftMargin: parent.radius * 0.7
                    anchors.right: parent.right
                    anchors.rightMargin: parent.radius * 0.7
                    height: 1
                    color: Colours.alpha(Colours.ink, 0.28)
                    visible: root.glassy
                    antialiasing: true
                }
            }

            // ───────────────────────────────────────────────────── the rail
            //  Rows behind the rail's cells (and their lines): the open or
            //  chosen module wears the accent, the one under the pointer a
            //  quiet ink. Open, a row is only as wide as the rail.
            Rectangle {
                id: litRow

                readonly property bool wide: root.sideLabels
                visible: root.onSide && root.shownIdx >= 0
                x: (root.edge === "left" || wide ? 0 : capsule.width - root.railW) + 6
                y: capsule.railY + root.railPad + root.shownIdx * root.cellH + 4
                width: (wide ? capsule.width : root.railW) - 12
                height: root.cellH - 8
                radius: Appearance.r(12)
                color: Colours.alpha(Colours.accent, root.expanded || root.touched ? 0.2 : 0.12)

                Behavior on y {
                    SpringAnimation {
                        spring: 3.2
                        damping: 0.62
                        epsilon: 0.01
                    }
                }
            }

            Rectangle {
                visible: root.onSide && root.railHot >= 0 && root.railHot !== root.shownIdx && !root.pressed
                x: litRow.x
                y: capsule.railY + root.railPad + root.railHot * root.cellH + 4
                width: litRow.width
                height: root.cellH - 8
                radius: Appearance.r(12)
                color: Colours.alpha(Colours.ink, 0.08)
            }

            Item {
                id: rail

                visible: root.onSide
                x: root.edge === "left" ? 0 : capsule.width - root.railW
                y: capsule.railY
                width: root.railW
                height: root.railH
                z: 3

                Repeater {
                    model: root.meta.length

                    Item {
                        id: cell

                        required property int index
                        readonly property bool lit: cell.index === root.shownIdx
                        readonly property bool hot: cell.index === root.railHot
                        // Her cell never goes dark while she is awake: a session
                        // that keeps the microphone open is visible from every
                        // module, not only from her own.
                        readonly property bool awake: Velly.active && cell.index === root.vellyIdx
                        readonly property bool playing: cell.index === 0 && (root.bridge?.playing ?? false)

                        y: root.railPad + cell.index * root.cellH
                        width: root.railW
                        height: root.cellH

                        // the taskbar's language: a bar of accent on the edge side
                        Rectangle {
                            x: root.edge === "left" ? 2 : cell.width - 5
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: cell.lit ? 20 : (cell.hot ? 8 : 0)
                            radius: 1.5
                            color: Colours.accent
                            opacity: cell.lit || cell.hot ? 1 : 0

                            Behavior on height {
                                SpringAnimation {
                                    spring: 3.4
                                    damping: 0.6
                                    epsilon: 0.01
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: root.arming && cell.index === root.vellyIdx ? "auto_awesome" : (cell.playing ? "graphic_eq" : root.pillGlyph(cell.index))
                            color: cell.awake || (root.arming && cell.index === root.vellyIdx) ? Colours.accentHot : (cell.lit ? Colours.accent : Colours.alpha(Colours.ink, cell.hot ? 1 : 0.7))
                            font.pixelSize: 20
                            scale: cell.hot && !root.pressed ? 1.16 : 1

                            Behavior on scale {
                                SpringAnimation {
                                    spring: 3.6
                                    damping: 0.55
                                    epsilon: 0.01
                                }
                            }
                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        // live: music playing, Velly awake
                        Rectangle {
                            visible: cell.playing || cell.awake
                            x: cell.width / 2 + 8
                            y: cell.height / 2 - 13
                            width: 6
                            height: 6
                            radius: 3
                            color: cell.awake ? Colours.accentHot : Colours.accent

                            SequentialAnimation on scale {
                                running: cell.awake || cell.playing
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 1.5
                                    duration: 700
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 1.0
                                    duration: 700
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }
                    }
                }

                // The hold for Velly: a hairline down the rail's open side
                // that fills over exactly the hold time.
                Rectangle {
                    x: root.edge === "left" ? rail.width - 2 : 0
                    width: 2
                    height: rail.height * (root.arming ? 1 : 0)
                    visible: root.arming
                    color: Colours.accent
                    antialiasing: true

                    Behavior on height {
                        NumberAnimation {
                            duration: root.armMs
                            easing.type: Easing.Linear
                        }
                    }
                }
            }

            // Every module's live line, beside its icon — what the top pill
            // says one at a time, the rail says all at once.
            Item {
                id: labels

                visible: opacity > 0
                opacity: root.sideLabels ? 1 : 0
                x: root.edge === "left" ? root.railW : capsule.width - root.railW - root.labelW
                y: capsule.railY
                width: root.labelW
                height: root.railH
                z: 3

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                Repeater {
                    model: root.meta.length

                    P5Text {
                        required property int index

                        x: root.edge === "left" ? 4 : 18
                        y: root.railPad + index * root.cellH
                        width: root.labelW - 26
                        height: root.cellH
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: root.edge === "left" ? Text.AlignLeft : Text.AlignRight
                        text: root.pillText(index)
                        color: index === root.shownIdx ? Colours.ink : Colours.alpha(Colours.ink, index === root.railHot ? 0.95 : 0.62)
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }
                }
            }

            // The rail's hands: point (the lines unfold, the row lights), click
            // (that module opens — or closes), pull an icon out (it opens,
            // following your hand), scrub along (the modules flip), wheel,
            // hold (Velly). While the lines are out, they answer too.
            MouseArea {
                id: railArea

                visible: root.onSide
                x: root.sideOpen ? rail.x : 0
                y: capsule.railY
                width: root.sideOpen ? root.railW : capsule.width
                height: root.railH
                z: 4
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                function at(e): var {
                    return railArea.mapToItem(inputArea, e.x, e.y);
                }

                // Pointing is a passive handler, not hoverEnabled: a MouseArea
                // that takes the hover took it from the island's own keep-alive
                // (keepHover) too, and the island shut under the pointer.
                HoverHandler {
                    id: railHover

                    cursorShape: Qt.PointingHandCursor
                    onPointChanged: root.railHot = railHover.hovered ? root.railIdxAt(railArea.mapToItem(inputArea, railHover.point.position.x, railHover.point.position.y).y) : -1
                    onHoveredChanged: {
                        if (!railHover.hovered)
                            root.railHot = -1;
                    }
                }

                onPositionChanged: e => {
                    const p = railArea.at(e);
                    root.gestureMove(p.x, p.y);
                }
                onPressed: e => {
                    const p = railArea.at(e);
                    root.gesturePress(p.x, p.y, root.railIdxAt(p.y));
                }
                onReleased: {
                    root.disarm();
                    root.commit();
                }
                onCanceled: {
                    root.disarm();
                    root.abort();
                }
                onWheel: e => root.gestureWheel(e.angleDelta.y)
            }

            // ──────────────────────────────────────────────────── the sheet
            //  Top: the whole capsule — the pill row, and the module growing
            //  out under it. Side: the module's own size beside the rail,
            //  fixed on screen, revealed as the capsule grows round it, so it
            //  never reflows while you pull.
            Item {
                id: sheet

                x: !root.onSide ? 0 : (root.edge === "left" ? root.railW : capsule.width - root.railW - sheet.width)
                y: root.onSide ? Math.round((capsule.height - root.sideFullH) / 2) : 0
                width: root.onSide ? root.meta[root.moduleIdx].w : capsule.width
                height: root.onSide ? root.sideFullH : capsule.height
                visible: !root.onSide || root.sideOpen || capsule.width > root.railW + root.labelW + 1
                z: 2

                // The pill row — the drag surface and the text view. On a side
                // edge it is the open module's title: click it to fold it back.
                Item {
                    id: pillRow

                    width: parent.width
                    height: pillH
                    z: 2

                    Icon {
                        id: pillIcon

                        anchors.verticalCenter: parent.verticalCenter
                        x: 20
                        width: 20
                        visible: root.showText
                        name: root.arming ? "auto_awesome" : root.pillGlyph(root.shownIdx)
                        color: root.arming ? Colours.accentHot : Colours.accent
                        font.pixelSize: 18

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    P5Text {
                        id: pillLabel

                        anchors.verticalCenter: parent.verticalCenter
                        x: 48
                        width: Math.max(10, parent.width - 48 - 10 - (root.onSide ? 0 : dots.width + dots.anchors.rightMargin))
                        visible: root.showText
                        text: root.arming ? "VELLY  ·  HALTEN…" : root.pillText(root.shownIdx)
                        color: root.arming ? Colours.accentInk : Colours.alpha(Colours.ink, 0.92)
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }

                    // One dot per module; the accent marks the active one. The
                    // dots are the swipe hint — they move with the preview while
                    // you drag. Open, they grow into TABS: each module's icon,
                    // one click away (the map, the music, Velly …). On a side
                    // edge the rail says all this.
                    Row {
                        id: dots

                        visible: !root.onSide
                        anchors.right: parent.right
                        anchors.rightMargin: root.expanded ? 10 : 20
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.expanded ? 1 : 7
                        opacity: root.arming ? 0 : 1
                        z: 3

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }

                        Repeater {
                            model: root.meta.length

                            Item {
                                id: dot

                                required property int index
                                readonly property bool lit: dot.index === root.shownIdx
                                // Her dot never goes dark while she is awake.
                                readonly property bool awake: Velly.active && dot.index === root.vellyIdx
                                readonly property bool tabbed: root.expanded && !root.arming

                                objectName: `tab-${dot.index}`

                                width: dot.tabbed ? 27 : (dot.awake ? 6 : 5)
                                height: dot.tabbed ? 26 : (dot.awake ? 6 : 5)
                                anchors.verticalCenter: parent.verticalCenter
                                onTabbedChanged: dot.scale = 1

                                Behavior on width {
                                    NumberAnimation {
                                        duration: Appearance.anim.normal
                                        easing.type: Easing.OutCubic
                                    }
                                }
                                Behavior on height {
                                    NumberAnimation {
                                        duration: Appearance.anim.normal
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: dot.tabbed ? Appearance.r(8) : 3
                                    color: dot.tabbed ? (dot.lit ? Colours.alpha(Colours.accent, 0.2) : (tabHover.hovered ? Colours.alpha(Colours.ink, 0.1) : "transparent")) : (dot.awake ? Colours.accentHot : (dot.lit ? Colours.accent : Colours.alpha(Colours.ink, 0.28)))
                                    border.width: dot.tabbed && dot.lit ? 1 : 0
                                    border.color: Colours.alpha(Colours.accent, 0.55)
                                    antialiasing: true

                                    Behavior on color {
                                        ColorAnimation {
                                            duration: Appearance.anim.fast
                                        }
                                    }
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    name: dot.index === 0 && (root.bridge?.playing ?? false) ? "graphic_eq" : root.pillGlyph(dot.index)
                                    color: dot.awake ? Colours.accentHot : (dot.lit ? Colours.accent : Colours.alpha(Colours.ink, tabHover.hovered ? 0.95 : 0.6))
                                    font.pixelSize: 15
                                    opacity: dot.tabbed ? 1 : 0
                                    visible: opacity > 0.01
                                    scale: tabHover.hovered && !dot.lit ? 1.12 : 1

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Appearance.anim.normal
                                        }
                                    }
                                    Behavior on scale {
                                        SpringAnimation {
                                            spring: 3.6
                                            damping: 0.55
                                            epsilon: 0.01
                                        }
                                    }
                                }

                                SequentialAnimation on scale {
                                    running: dot.awake && !dot.tabbed
                                    loops: Animation.Infinite
                                    NumberAnimation {
                                        to: 1.7
                                        duration: 700
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        to: 1.0
                                        duration: 700
                                        easing.type: Easing.InOutSine
                                    }
                                }

                                HoverHandler {
                                    id: tabHover

                                    enabled: dot.tabbed
                                }

                                // A tap picks the module; a drag that starts on a
                                // tab is still the pill's swipe (in a narrow
                                // module the tabs cover half the pill).
                                MouseArea {
                                    id: tabArea

                                    anchors.fill: parent
                                    anchors.margins: -1
                                    enabled: dot.tabbed
                                    cursorShape: Qt.PointingHandCursor

                                    onPressed: e => {
                                        const p = tabArea.mapToItem(inputArea, e.x, e.y);
                                        root.gesturePress(p.x, p.y, -1);
                                        root.disarm();
                                    }
                                    onPositionChanged: e => {
                                        const p = tabArea.mapToItem(inputArea, e.x, e.y);
                                        root.gestureMove(p.x, p.y);
                                    }
                                    onReleased: {
                                        root.disarm();
                                        if (root.axis === "") {
                                            root.abort();
                                            root.switchTo(dot.index);
                                        } else {
                                            root.commit();
                                        }
                                    }
                                    onCanceled: root.abort()
                                }
                            }
                        }
                    }

                    // The charge: a hairline along the bottom of the pill that
                    // fills over exactly the hold time. Nothing counts down
                    // anywhere — the line IS the timer.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        height: 2
                        width: parent.width * (root.arming ? 1 : 0)
                        visible: root.arming && !root.onSide
                        color: Colours.accent
                        antialiasing: true

                        Behavior on width {
                            NumberAnimation {
                                duration: root.armMs
                                easing.type: Easing.Linear
                            }
                        }
                    }

                    // Top: the whole gesture lives here — pull down to expand,
                    // swipe sideways to switch modules, click to toggle, hold
                    // to wake Velly. Side: a click folds the module back.
                    MouseArea {
                        id: gesture

                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor

                        onPressed: e => {
                            const p = gesture.mapToItem(inputArea, e.x, e.y);
                            root.gesturePress(p.x, p.y, -1);
                        }
                        onPositionChanged: e => {
                            const p = gesture.mapToItem(inputArea, e.x, e.y);
                            root.gestureMove(p.x, p.y);
                        }
                        onWheel: e => root.gestureWheel(e.angleDelta.y)
                        onReleased: {
                            root.disarm();
                            root.commit();
                        }
                        onCanceled: {
                            root.disarm();
                            root.abort();
                        }
                    }
                }

                // The module body. The capsule's clip reveals it as the capsule
                // grows, so the content never reflows while you pull.
                // The module's own full size from the first pixel, centred, and
                // the growing capsule only uncovers it: nothing reflows while
                // you pull (the map was drawn squeezed half-way out).
                Loader {
                    id: body

                    readonly property var full: root.meta[root.moduleIdx]

                    x: root.onSide ? 0 : Math.round((parent.width - width) / 2)
                    y: pillH
                    width: root.onSide ? parent.width : body.full.w
                    height: Math.max(0, root.onSide ? parent.height - pillH : body.full.h - pillH)
                    clip: true

                    source: {
                        if (root.moduleIdx === 0)
                            return Qt.resolvedUrl("IslandMusic.qml");
                        if (root.moduleIdx === root.deskIdx)
                            return Qt.resolvedUrl("IslandMap.qml");
                        if (root.moduleIdx === root.tasksIdx)
                            return Qt.resolvedUrl("IslandTasks.qml");
                        if (root.moduleIdx === root.weatherIdx)
                            return Qt.resolvedUrl("IslandWeather.qml");
                        if (root.moduleIdx === root.systemIdx)
                            return Qt.resolvedUrl("IslandSystem.qml");
                        if (root.moduleIdx === root.vellyIdx)
                            return Qt.resolvedUrl("IslandVelly.qml");
                        return "";
                    }

                    onLoaded: {
                        if (root.moduleIdx === 0)
                            body.item.bridge = Qt.binding(() => root.bridge);
                        if (root.moduleIdx === root.deskIdx) {
                            // live while open — and already while you pull it
                            // out, so the pull reveals the real canvas
                            body.item.live = Qt.binding(() => root.active && root.moduleIdx === root.deskIdx && (root.expanded || root.pressed));
                            body.item.keys = Qt.binding(() => root.expanded && root.mine);
                            body.item.ground = Qt.binding(() => root.shellCol);
                            body.item.poked.connect(root.poke);
                        }
                    }
                }
            }
        }
    }
}
