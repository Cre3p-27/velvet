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
//  Like the map, this window eats nothing while closed: the input mask is
//  dead until the island is active on this screen. Hearing the hover is the
//  EdgeSensor strip's job, exactly as before.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen modelData

    // The optional chain guards a startup instant: the binding can be
    // evaluated once before the Variants model hands over the screen.
    readonly property bool active: Panels.islandScreen === (root.modelData?.name ?? "") && !Panels.windowMap && Config.map.island
    readonly property bool mine: root.modelData === Hypr.focusedScreen

    // A bar on the top edge is in the island's way: the pill stands under it
    // (the bar may slide away, but it comes back the moment the pointer
    // touches the edge — the same touch that raises the pill).
    readonly property real barClear: Config.map.islandPlace === "below" && Config.bar.enabled && Config.bar.position === "top" ? Config.bar.thickness + Config.bar.margin * 2 : 0

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

    function capsuleX(w: real): real {
        if (root.edge === "left")
            return Math.round(16 + Config.map.islandGap + Appearance.barRoom("left") - (1 - root.slide) * (w + 40));
        if (root.edge === "right")
            return Math.round(root.width - w - 16 - Config.map.islandGap - Appearance.barRoom("right") + (1 - root.slide) * (w + 40));
        const x = (root.width - w) / 2 + Config.map.islandShift;
        return Math.round(Math.max(4, Math.min(root.width - w - 4, x)));
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
            { w: 340, h: 170, glyph: "apps" }
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
        if (i === root.deskIdx)
            return `MAP  ·  DESKTOP ${Desk.homeCell?.ws ?? 1}`;
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

    readonly property bool showText: root.touched || root.pressed || root.expanded || root.hoverPeek

    // Hover-peek: resting the mouse on the untouched pill grows it into the
    // text view after a beat — a tooltip that never needed a click. The
    // delay keeps a passing cursor from making the pill twitch.
    property bool hoverPeek: false

    Timer {
        id: peekDelay

        interval: 180
        onTriggered: root.hoverPeek = !root.touched && !root.pressed
    }

    function ease(t: real): real {
        const p = Math.max(0, Math.min(1, t));
        return p * p * (3 - 2 * p);
    }

    readonly property real textW: Math.min(480, Math.max(restW, 48 + Math.min(320, pillLabel.implicitWidth) + 10 + 41 + 20))

    readonly property real shellW: {
        const m = root.meta[root.moduleIdx];
        if (root.expanded)
            return m.w;
        if (root.pressed && root.axis === "v") {
            const from = root.showText ? root.textW : root.restW;
            return from + (m.w - from) * root.ease(root.progress);
        }
        return root.showText ? root.textW : root.restW;
    }

    readonly property real shellH: {
        if (root.expanded)
            return root.meta[root.moduleIdx].h;
        if (root.pressed && root.axis === "v")
            return root.pillH + (root.meta[root.moduleIdx].h - root.pillH) * root.ease(root.progress);
        return root.pillH;
    }

    // ── the island's face — MODULES → DYNAMIC ISLAND. INK BLACK is the
    // classic solid pill. GLASS is a dark-tinted frost: Hyprland blurs the
    // desktop behind it (layerrule), the tint keeps the ink legible, and
    // the specular does the rest — light catching the top edge, a soft
    // grounding at the bottom. WALLPAPER wears a prominence-weighted mix of
    // the picture's own colours, so the pill IS the picture. All three
    // honour the ISLAND OPACITY dial.
    readonly property color shellCol: {
        switch (Config.map.islandTheme) {
        case "glass":
            // Near-black frost — the blur glows through the tint, and the
            // tint keeps ink text readable over bright wallpapers too.
            return Colours.light ? Colours.alpha(Colours.surface, Math.max(0.4, 0.7 * Config.map.islandOpacity)) : Qt.rgba(0.014, 0.016, 0.020, Math.max(0.4, 0.62 * Config.map.islandOpacity));
        case "wallpaper":
            return Colours.alpha(Colours.wallpaperTint, 0.97 * Config.map.islandOpacity);
        default:
            // A light ground gives the island a light face, so its ink stays ink.
            return Colours.light ? Colours.alpha(Colours.surfaceHigh, Config.map.islandOpacity) : Qt.rgba(0.019, 0.019, 0.021, Config.map.islandOpacity);
        }
    }

    // The capsule's ring: a quiet ink line on black, a brighter rim on glass
    // (glass catches light at its edge), the accent glowing on wallpaper.
    readonly property color shellRing: {
        if (Config.map.islandTheme === "dark")
            return Colours.alpha(Config.map.islandAccent ? Colours.accent : Colours.ink, Config.map.islandAccent ? 0.26 : 0.18);
        if (Config.map.islandTheme === "glass")
            return Colours.alpha(Config.map.islandAccent ? Colours.accent : Colours.ink, Config.map.islandAccent ? 0.55 : 0.34);
        return Colours.alpha(Config.map.islandAccent ? Colours.accent : Colours.ink, 0.5);
    }

    function poke(): void {
        openWatchdog.restart();
    }

    function openModule(): void {
        root.touched = true;
        if (root.moduleIdx === root.deskIdx) {
            // The desk module hands off to the real map: it slides in where
            // the pill was, and this island gets out of the way.
            Panels.islandScreen = "";
            Panels.windowMap = true;
            return;
        }
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

    Connections {
        target: Velly

        function onWantIslandChanged(): void {
            if (Velly.wantIsland && root.active)
                root.openVelly();
        }
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
        root.pressed = false;
        if (ax === "h") {
            if (Math.abs(dx) >= 70) {
                root.moduleIdx = root.previewIdx;
                root.touched = true;
                Sfx.cursor();
            }
            root.previewIdx = root.moduleIdx;
            // The map never has an expanded state: swiping onto it from an
            // open module folds the capsule back into the pill.
            if (root.moduleIdx === root.deskIdx)
                root.expanded = false;
        } else if (ax === "v") {
            if (root.progress >= 0.5)
                root.openModule();
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
            if (Velly.wantIsland)
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
                if (root.moduleIdx === 1)
                    root.expanded = false;
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
        Keys.onEscapePressed: root.dismiss()
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
        readonly property real sideTop: Math.min(capsule.y - 44, capsule.y + root.pillH / 2 - zone / 2)
        readonly property real sideBottom: Math.max(capsule.y + capsule.height + 44, capsule.y + root.pillH / 2 + zone / 2)

        x: root.edge === "left" ? 0 : (root.edge === "right" ? capsule.x - 44 : Math.round(capsule.x + capsule.width / 2 - shield.span / 2))
        y: root.onSide ? shield.sideTop : 0
        width: root.edge === "left" ? capsule.x + capsule.width + 44 : (root.edge === "right" ? root.width - capsule.x + 44 : shield.span)
        height: root.onSide ? shield.sideBottom - shield.sideTop : capsule.y + capsule.height + 44

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
            if (root.pressed) {
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
            if (keepHover.hovered || root.pressed || busy) {
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
    Item {
        id: capsule

        x: root.capsuleX(capsule.width) + (root.axis === "h" ? Math.max(-30, Math.min(30, root.dragDX * 0.12)) : 0)
        y: root.onSide ? Appearance.edgeY(root.height, capsule.height, root.pillH) : (root.active ? 10 + root.barClear + Config.map.islandGap : -capsule.height - 14)
        width: root.shellW
        height: root.shellH
        scale: root.expanded ? 1 : (root.pressed && root.axis === "v" ? 0.985 : 1)
        clip: true
        z: 10

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

        // On a side edge x and y follow the width/height spring and the slide
        // exactly (the edge it keeps to must not wobble); on top it settles
        // with its own ease.
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
            // A spring, like the height: the two edges of the capsule settle
            // together instead of one snapping and the other sagging behind.
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
        // Opening is a small pop, closing a small settle — the same spring
        // language as every button in the shell.
        Behavior on scale {
            enabled: !root.pressed
            SpringAnimation {
                spring: 2.2
                damping: 0.7
                epsilon: 0.01
            }
        }

        // One surface: a pill when closed, a sheet when open. The radius
        // follows the height, so the capsule never shows a corner seam.
        Plate {
            id: shell

            anchors.fill: parent
            radius: Appearance.r(Math.min(24, capsule.height / 2))
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
                strength: Config.map.islandTheme === "glass" ? 0.03 : 0.045
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

            // GLASS: the specular — light catching the top edge and falling
            // away down the pane. This plus the frost is what reads as glass.
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: Math.max(60, parent.height * 0.42)
                visible: Config.map.islandTheme === "glass"
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Colours.alpha(Colours.ink, 0.22)
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
                antialiasing: true
            }

            // GLASS: a soft grounding at the bottom — the glass resting on
            // the desk instead of floating.
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height * 0.3
                visible: Config.map.islandTheme === "glass"
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(0, 0, 0, 0.26)
                    }
                }
                antialiasing: true
            }

            // GLASS: the crisp rim of light along the top edge.
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: 1
                anchors.right: parent.right
                anchors.rightMargin: 1
                height: 1
                color: Colours.alpha(Colours.ink, 0.3)
                visible: Config.map.islandTheme === "glass"
                antialiasing: true
            }
        }

        // The pill row — the drag surface and the text view.
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
                name: root.arming ? "auto_awesome" : root.pillGlyph(root.pressed && root.axis === "h" ? root.previewIdx : root.moduleIdx)
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
                width: Math.max(10, parent.width - 48 - 10 - 41 - 20)
                visible: root.showText
                text: root.arming ? "VELLY  ·  HALTEN…" : root.pillText(root.pressed && root.axis === "h" ? root.previewIdx : root.moduleIdx)
                color: root.arming ? Colours.accentInk : Colours.alpha(Colours.ink, 0.92)
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            // One dot per module; the accent marks the active one. The dots
            // are the swipe hint — they move with the preview while you drag.
            Row {
                id: dots

                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                opacity: root.arming ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                Repeater {
                    model: root.meta.length

                    Rectangle {
                        id: dot

                        required property int index
                        readonly property bool lit: dot.index === (root.pressed && root.axis === "h" ? root.previewIdx : root.moduleIdx)
                        // Her dot never goes dark while she is awake: a session
                        // that keeps the microphone open has to be visible
                        // from every module, not only from her own.
                        readonly property bool awake: Velly.active && dot.index === root.vellyIdx

                        width: awake ? 6 : 5
                        height: awake ? 6 : 5
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter
                        color: awake ? Colours.accentHot : (lit ? Colours.accent : Colours.alpha(Colours.ink, 0.28))

                        SequentialAnimation on scale {
                            running: dot.awake
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

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                }
            }

            // The charge: a hairline along the bottom of the pill that fills
            // over exactly the hold time. Nothing counts down anywhere — the
            // line IS the timer, and it reads from the corner of your eye.
            Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                height: 2
                width: parent.width * (root.arming ? 1 : 0)
                visible: root.arming
                color: Colours.accent
                antialiasing: true

                Behavior on width {
                    NumberAnimation {
                        duration: root.armMs
                        easing.type: Easing.Linear
                    }
                }
            }

            // The whole gesture lives here: pull down to expand, swipe
            // sideways to switch modules, click to toggle, hold to wake Velly.
            MouseArea {
                id: gesture

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor

                property real startX: 0
                property real startY: 0

                onPressed: event => {
                    root.poke();
                    startX = event.x;
                    startY = event.y;
                    root.pressed = true;
                    root.axis = "";
                    root.dragDX = 0;
                    root.dragDY = 0;
                    root.awaitIntent();
                }

                onPositionChanged: event => {
                    if (!pressed)
                        return;
                    root.dragDX = event.x - startX;
                    root.dragDY = event.y - startY;
                    if (root.axis === "") {
                        if (Math.abs(root.dragDX) > 14) {
                            root.axis = "h";
                            Sfx.cursor();
                        } else if (root.dragDY > 12) {
                            root.axis = "v";
                        }
                        if (root.axis !== "")
                            root.disarm();
                    }
                    if (root.axis === "v") {
                        root.progress = root.ease((root.dragDY - 12) / root.travel);
                    } else if (root.axis === "h") {
                        root.previewIdx = (root.moduleIdx + (root.dragDX > 0 ? 1 : -1) + root.meta.length) % root.meta.length;
                    }
                }

                // The wheel is the third way to browse: scroll over the
                // resting pill and the modules cycle like a carousel. While
                // expanded the wheel belongs to the module's own content.
                // Trackpads emit a burst of wheel events per gesture — a
                // short gate keeps one flick from spinning through every
                // module.
                property real lastWheel: 0

                onWheel: event => {
                    if (root.expanded || root.pressed)
                        return;
                    const t = Date.now();
                    if (t - lastWheel < 140)
                        return;
                    lastWheel = t;
                    root.poke();
                    root.moduleIdx = (root.moduleIdx + (event.angleDelta.y < 0 ? 1 : -1) + root.meta.length) % root.meta.length;
                    root.previewIdx = root.moduleIdx;
                    root.touched = true;
                    Sfx.cursor();
                }

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
        Loader {
            id: body

            y: pillH
            width: parent.width
            height: Math.max(0, parent.height - pillH)
            clip: true

            source: {
                if (root.moduleIdx === 0)
                    return Qt.resolvedUrl("IslandMusic.qml");
                if (root.moduleIdx === root.deskIdx)
                    return "";
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
            }
        }

        // Desk's own teaser: the map itself is not drawn here, so the pull
        // shows a quiet promise instead. Only while the pull is actually
        // happening — released, it disappears with the capsule, never
        // during the hide animation.
        Item {
            id: deskTeaser

            y: pillH
            width: parent.width
            height: Math.max(0, parent.height - pillH)
            visible: root.moduleIdx === root.deskIdx && root.pressed

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 16
                width: 30
                name: "apps"
                color: Colours.alpha(Colours.ink, 0.5)
                font.pixelSize: 28
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 56
                display: true
                text: "DESKTOP MAP"
                color: Colours.ink
                font.pixelSize: Appearance.font.size.large
                tracking: 1.4
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 86
                text: "RELEASE TO OPEN  ·  PULL DOWN ANYTIME"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }
        }
    }
}
