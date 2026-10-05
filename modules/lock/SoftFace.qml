//  VELVET  ·  modules/lock/SoftFace.qml
//  The SOFT lock (LOCK SCREEN → LOCK STYLE → SOFT) — the round, quiet
//  Material look: no card, just the blurred wallpaper, a big clock, a few
//  small pills and the music along an edge.
//
//    VERTICAL    the clock, and under it the pills: LOG OUT · RESTART ·
//                SHUT DOWN beside the bell and the weather, the password
//                pill with its pencil, and what is playing
//    HORIZONTAL  the clock on the left, the same pills on the right
//    GREETING    a column of shapes (the time, the date, the weather), a
//                big hello in a cloud, the password under it and the
//                music card in the corner
//
//  The pencil beside the password customises the lock ON the lock: arrows
//  beside the clock cycle its style (vertical, line, gear, cookie, flower,
//  clover, scallop, pentagon, circle), a panel on the left sets its size,
//  its digits and its font, one on the right the layout, the blur and the
//  visualizer. Everything it writes is a normal setting — the same rows
//  live in SETTINGS → LOCK SCREEN.
//
//  The bell opens the notifications in place of the pills; the song pill
//  opens a music card with the cover in a wavy frame. Guarded power
//  buttons work like the fluid lock's: they arm the password, and act
//  only once PAM has accepted it.
//
//  Point at a shape and it morphs into its hover shape (SHAPES CHANGE ON
//  HOVER): the element's own pick, or a partner of its own.
//
//  PREVIEW mode is the same face in the settings — no keyboard, no PAM,
//  nothing clickable.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects as GE

Item {
    id: face

    property bool preview: false
    readonly property bool live: face.preview || Locker.locked

    // Everything is measured at 1080 px tall and grows with the screen.
    readonly property real u: Math.max(0.55, Math.min(2.2, face.height / 1080))

    // ── the palette: the accent's own deep tone carries every pill, so a
    // pink accent gives plum pills and a peach one warm brown ones.
    readonly property color accent: Colours.accent
    readonly property color tone: Colours.tone
    readonly property color toneHigh: Colours.toneHigh
    readonly property color onAccent: Colours.on(Colours.accent)
    readonly property string family: Appearance.fontFamily.soft
    // CLOCK COLOURS: two-tone (hours in the accent), all accent, all ink.
    // On a clock filled with the accent, accent digits would vanish into it:
    // they turn to ink there, and the clock's own HIGHLIGHT can pick either.
    readonly property bool clockOnAccent: `${(Config.lock.softStyle ?? {}).clock?.fill ?? ""}` === "accent"
    readonly property string clockHi: `${(Config.lock.softStyle ?? {}).clock?.hi ?? ""}`
    readonly property color hourInk: face.clockHi === "ink" ? Colours.ink : face.clockHi === "accent" ? Colours.accent : (Config.lock.clockColours === "ink" || face.clockOnAccent ? Colours.ink : Colours.accent)
    readonly property color minuteInk: Config.lock.clockColours === "accent" && !face.clockOnAccent ? Colours.accent : Colours.ink

    Rectangle {
        anchors.fill: parent
        color: Colours.paper
    }

    // ════════════════════════════════════════════════════════════ state
    property date now: new Date()

    Timer {
        interval: 1000
        repeat: true
        running: face.live && face.visible
        triggeredOnStart: true
        onTriggered: face.now = new Date()
    }

    readonly property string layout: ["vertical", "horizontal", "greeting", "custom"].indexOf(Config.lock.layout) >= 0 ? Config.lock.layout : "vertical"

    property bool editing: false
    property bool mediaOpen: false
    property bool notifsOpen: false
    property string pendingAction: ""
    property bool showPassword: false

    readonly property var actionWords: ({
            poweroff: "shut down",
            reboot: "restart",
            logout: "log out"
        })
    readonly property string actionNote: ({
            "POWERING OFF": "Shutting down…",
            "RESTARTING": "Restarting…",
            "LOGGING OUT": "Logging out…"
        })[Locker.message] ?? ""

    // ── the clock's styles, in the order the arrows walk them: bare, one
    // line, every shape (Appearance.shapeKinds), then the analog dial.
    readonly property var styles: [
        {
            name: "Vertical",
            shape: "none"
        },
        {
            name: "Line",
            shape: "line"
        }
    ].concat(Appearance.shapeKinds.map(k => ({
                name: k.t,
                shape: k.v
            }))).concat([
        {
            name: "Analog",
            shape: "circle",
            analog: true
        }
    ])

    readonly property bool analog: Config.lock.clockFace === "analog"
    readonly property bool dots: Config.lock.clockFace === "dots"
    readonly property int styleIndex: {
        if (face.analog)
            return face.styles.length - 1;
        for (let i = 0; i < face.styles.length - 1; i++)
            if (face.styles[i].shape === Config.lock.clockShape)
                return i;
        return 0;
    }
    // Whatever shape is set — also one the arrows do not list — so a shape
    // picked in the editor or the settings is never swapped for VERTICAL.
    readonly property string clockShape: face.analog ? "circle" : face.styles[face.styleIndex].shape
    readonly property bool dialClock: face.analog || (face.clockShape !== "none" && face.clockShape !== "line")
    readonly property string clockFamily: (Config.lock.clockFont ?? "") !== "" ? Config.lock.clockFont : face.family
    readonly property real clockScale: Math.max(0.5, Math.min(1.4, Config.lock.clockScale))

    function setKey(key: string, value: var): void {
        const batch = {};
        batch[key] = value;
        face.setMany(batch);
    }

    function stepStyle(dir: int): void {
        if (face.preview && !face.arranging)
            return;
        const n = face.styles.length;
        const next = face.styles[(face.styleIndex + dir + n) % n];
        if (next.analog)
            Config.setMany({
                "lock.clockFace": "analog"
            });
        else
            Config.setMany({
                "lock.clockFace": face.analog ? "" : Config.lock.clockFace,
                "lock.clockShape": next.shape
            });
        Sfx.cursor();
    }

    // The fonts the panel offers: the soft house face, the inspo's own
    // families when they are installed, and the drawn dots.
    readonly property var fontChoices: {
        const wanted = ["Google Sans", "Google Sans Flex", "DM Sans", "Plus Jakarta Sans", "Outfit", "Poppins", "Inter", "Adwaita Sans", "Open Sans", "Cantarell", "Noto Sans"];
        const have = Qt.fontFamilies();
        const out = [];
        for (let i = 0; i < wanted.length && out.length < 4; i++)
            if (have.indexOf(wanted[i]) !== -1 && wanted[i] !== face.family)
                out.push(wanted[i]);
        return out;
    }

    // ── AMBIENT: after a while without input only the clock and the music
    // are left; any key or movement brings everything back.
    property bool ambient: false
    property real awake: face.ambient ? 0 : 1
    readonly property int ambientAfter: Math.max(0, parseInt(Config.lock.ambientAfter) || 0)
    readonly property bool idleArmed: face.ambientAfter > 0 && !face.preview && Locker.locked

    Behavior on awake {
        NumberAnimation {
            duration: face.ambient ? 1400 : 260
            easing.type: Easing.InOutQuad
        }
    }

    onIdleArmedChanged: {
        if (face.idleArmed)
            idleTimer.restart();
        else
            idleTimer.stop();
    }

    function wake(): void {
        if (face.ambient)
            face.ambient = false;
        if (face.idleArmed)
            idleTimer.restart();
    }

    Timer {
        id: idleTimer

        interval: Math.max(5, face.ambientAfter) * 1000
        onTriggered: {
            if (input.text.length === 0 && face.pendingAction === "" && !Locker.busy && !face.editing)
                face.ambient = true;
        }
    }

    Connections {
        target: Locker

        function onLockedChanged(): void {
            face.ambient = false;
            face.editing = false;
            face.mediaOpen = false;
            face.notifsOpen = false;
            if (Locker.locked)
                face._queue = [];
        }

        function onFailedChanged(): void {
            face.wake();
        }

        function onBusyChanged(): void {
            face.wake();
        }
    }

    HoverHandler {
        enabled: !face.preview
        onPointChanged: face.wake()
    }

    // ── the password's shapes: a shuffled deck, one shape per keystroke
    property var _queue: []

    function fillDeck(): void {
        const shapes = [0, 1, 2, 3, 4, 5, 6];
        for (let k = shapes.length - 1; k > 0; k--) {
            const j = Math.floor(Math.random() * (k + 1));
            const t = shapes[k];
            shapes[k] = shapes[j];
            shapes[j] = t;
        }
        face._queue = face._queue.concat(shapes);
    }

    function shapeAt(i: int): int {
        if (Config.lock.passwordShapes === "circles")
            return 0;
        return i < face._queue.length ? face._queue[i] : 0;
    }

    function attempt(): void {
        if (face.preview)
            return;
        Locker.submit(input.text, face.pendingAction);
        input.text = "";
        face.showPassword = false;
    }

    function arm(what: string): void {
        if (face.preview)
            return;
        Sfx.toggle();
        face.pendingAction = face.pendingAction === what ? "" : what;
        input.forceActiveFocus();
    }

    // The greeting's words.
    readonly property string hello: {
        if ((Config.lock.greeting ?? "") !== "")
            return Config.lock.greeting;
        const h = face.now.getHours();
        if (h < 5)
            return "Good night,";
        if (h < 12)
            return "Good morning,";
        if (h < 18)
            return "Good afternoon,";
        if (h < 22)
            return "Good evening,";
        return "Good night,";
    }
    readonly property string who: (Config.home.displayName ?? "") !== "" ? Config.home.displayName : SysInfo.user

    // ── the music
    readonly property var mp: Lyrics.bridge
    readonly property bool hasMusic: (face.mp?.has ?? false) && (face.mp?.title ?? "") !== ""
    // ═══════════════════════════════════════ entrance and exit — one dial
    // t runs 0 → 1 on the way in and back 1 → 0 on the way out; every part
    // reads its own slice of it, so the exit is the entrance played back.
    property real t: 0
    property bool leaving: false
    property bool entrancePlayed: false
    readonly property real ms: Math.max(0.25, Config.lock.animationScale)

    function slice(from: real, len: real): real {
        return Math.max(0, Math.min(1, (face.t - from) / len));
    }
    function outCubic(x: real): real {
        return 1 - Math.pow(1 - x, 3);
    }
    function outBack(x: real): real {
        const c1 = 1.4;
        const c3 = c1 + 1;
        return 1 + c3 * Math.pow(x - 1, 3) + c1 * Math.pow(x - 1, 2);
    }

    readonly property real bgIn: face.leaving ? 1 : face.outCubic(face.slice(0, 0.35))
    readonly property real clockIn: face.slice(0.08, 0.55)
    function partIn(i: int): real {
        return face.outCubic(face.slice(0.3 + i * 0.08, 0.42));
    }

    function restartEntrance(): void {
        if (face.width <= 0 || face.height <= 0)
            return;
        face.entrancePlayed = true;
        face.leaving = false;
        face.settled = false;
        exitAnim.stop();
        backdrop.progress = 1;
        face.t = 0;
        enterAnim.restart();
    }

    function restartExit(): void {
        face.entrancePlayed = false;
        face.settled = false;
        enterAnim.stop();
        face.leaving = true;
        face.editing = false;
        exitAnim.restart();
    }

    function exitDone(): void {
        if (!face.preview)
            Locker.exitDone();
    }

    NumberAnimation {
        id: enterAnim

        target: face
        property: "t"
        to: 1
        duration: 1100 * face.ms

        onFinished: face.settled = true
    }

    ParallelAnimation {
        id: exitAnim

        NumberAnimation {
            target: face
            property: "t"
            to: 0
            duration: 560 * face.ms
        }
        NumberAnimation {
            target: backdrop
            property: "progress"
            to: 0
            duration: 620 * face.ms
            easing.type: Easing.InOutCubic
        }

        onFinished: face.exitDone()
    }

    Component.onCompleted: {
        if (face.idleArmed)
            idleTimer.restart();
        if (face.preview)
            Spectrum.lockPreview = true;
        face.sized();
    }
    Component.onDestruction: {
        if (face.preview)
            Spectrum.lockPreview = false;
    }

    // The lock surface sets its width, then its height — whichever lands
    // second starts the entrance.
    function sized(): void {
        if (face.width > 0 && face.height > 0 && face.live && !face.entrancePlayed)
            face.restartEntrance();
    }

    onWidthChanged: face.sized()
    onHeightChanged: face.sized()
    onVisibleChanged: {
        if (face.preview && face.visible)
            face.restartEntrance();
    }
    // A new layout in the settings' picture: glide there, or replay the
    // entrance when gliding is off.
    onLayoutChanged: {
        if (face.preview && !face.arranging && !Config.lock.softGlide)
            face.restartEntrance();
    }

    Connections {
        target: Locker
        enabled: !face.preview

        function onLockedChanged(): void {
            if (Locker.locked)
                face.restartEntrance();
        }

        function onReleasingChanged(): void {
            if (Locker.releasing)
                face.restartExit();
        }
    }

    // ═══════════════════════════════════════════════════ the background
    Item {
        id: background

        anchors.fill: parent
        opacity: face.bgIn

        ShapeBackdrop {
            id: backdrop

            anchors.fill: parent
            plain: true
            progress: 1
        }
    }

    // Ambient dims the picture a little further.
    Rectangle {
        anchors.fill: parent
        color: Colours.paper
        opacity: (1 - face.awake) * 0.34 * background.opacity
    }

    // The music along the chosen edge — thin rounded bars or a soft wave.
    SpectrumEdge {
        anchors.fill: parent
        running: Config.lock.visualizer && face.live
        edge: Config.lock.visualizerEdge
        style: Config.lock.visualizerStyle
        reach: (side ? face.width : face.height) * Math.max(0.03, Config.lock.visualizerReach)
        strength: 0.95 * background.opacity * (face.leaving ? face.t : 1)
        barPitch: (Config.lock.visualizerDensity === "fine" ? 9 : (Config.lock.visualizerDensity === "wide" ? 20 : 13)) * face.u
        barFill: 0.62
        // In the settings' picture a calm swell stands in for the music,
        // so the look can be judged in silence.
        demo: face.preview
    }

    // The clock's sizes: a bare clock by digit height, a dial by diameter.
    readonly property real clockBare: 200 * face.u * face.clockScale
    readonly property real clockDial: 460 * face.u * face.clockScale

    // Your photo, probed once so a missing ~/.face never warns.
    property bool faceExists: false
    readonly property string faceUrl: `file://${Quickshell.env("HOME") ?? ""}/.face`

    FileView {
        path: face.faceUrl.replace("file://", "")
        printErrors: false

        onLoaded: face.faceExists = true
        onLoadFailed: face.faceExists = false
    }

    // ═══════════════════════════════════════════ the stage — its elements
    //  Every piece of the soft lock is an ELEMENT: the clock, the greeting,
    //  the date, the weather, your photo, the lyric line, the power pills,
    //  the bell, the password and the music. Each has a place, a size, a
    //  shape (or corners), a form and a switch.
    //
    //  VERTICAL · HORIZONTAL · GREETING work the places out from the
    //  elements' own sizes, so they always stack cleanly. Drag anything and
    //  the arrangement becomes CUSTOM: every element's place is kept, as a
    //  share of the screen, in lock.softPlace. The look of each element
    //  (shape, size, corners, form, shown) lives in lock.softStyle and
    //  applies in every layout.
    readonly property var elementIds: ["clock", "greeting", "date", "weather", "avatar", "lyric", "power", "status", "password", "media"]
    readonly property var elementNames: ({
            clock: "Clock",
            greeting: "Greeting",
            date: "Date",
            weather: "Weather",
            avatar: "Photo",
            lyric: "Lyric line",
            power: "Power pills",
            status: "Bell & weather",
            password: "Password",
            media: "Music"
        })
    // What can wear a shape, and what has corners instead.
    readonly property var shapeable: ["clock", "greeting", "date", "weather", "avatar", "media"]
    readonly property var cornered: ["power", "status", "password", "media"]
    readonly property var shapeDefaults: ({
            greeting: "scallop",
            date: "penta",
            weather: "diamond",
            avatar: "circle",
            media: "wavy"
        })
    // Which elements each layout shows by itself.
    readonly property var layoutShows: ({
            vertical: ["clock", "power", "status", "password", "media"],
            horizontal: ["clock", "power", "status", "password", "media"],
            greeting: ["clock", "greeting", "date", "weather", "password", "media", "power"],
            custom: ["clock", "power", "status", "password", "media"]
        })
    // The switches that already had rows of their own before elements.
    readonly property var toggleKeys: ({
            power: "lock.softPower",
            status: "lock.softStatus",
            media: "lock.softMedia"
        })
    // The order they arrive in.
    readonly property var enterOrder: ({
            clock: 0,
            greeting: 0,
            avatar: 1,
            date: 1,
            weather: 2,
            power: 2,
            status: 2,
            password: 3,
            media: 4,
            lyric: 5
        })

    readonly property var place: Config.lock.softPlace ?? ({})
    readonly property var styleMap: Config.lock.softStyle ?? ({})

    // Editing: on the lock (the pencil) or in the settings' ARRANGE BY HAND.
    property bool arranging: false
    readonly property bool editMode: face.editing || face.arranging
    property string selectedId: "clock"
    property string dragId: ""
    property point dragPoint: Qt.point(0, 0)
    property bool snapX: false
    property bool snapY: false

    function copy(v: var): var {
        return JSON.parse(JSON.stringify(v ?? {}));
    }

    function st(id: string): var {
        return face.styleMap[id] ?? ({});
    }

    function layoutDefault(id: string): bool {
        return (face.layoutShows[face.layout] ?? []).indexOf(id) >= 0;
    }

    function shown(id: string): bool {
        const key = face.toggleKeys[id];
        if (key && Config.get(key) === false)
            return false;
        const s = face.st(id).show;
        return s !== undefined ? s : face.layoutDefault(id);
    }

    function scaleOf(id: string): real {
        return Math.max(0.3, Math.min(2.5, face.st(id).scale ?? 1));
    }

    function shapeOf(id: string): string {
        if (id === "clock")
            return face.analog ? "circle" : face.clockShape;
        return face.st(id).shape ?? (face.shapeDefaults[id] ?? "circle");
    }

    // ── the morph under the pointer (SHAPES CHANGE ON HOVER)
    // The element the pointer is on, and what its shape turns into there:
    // the one picked for it, "none" to stay, or its partner by default.
    property string hoverId: ""

    function hoverShapeOf(id: string): string {
        const own = face.shapeOf(id);
        const want = face.st(id).hover ?? "";
        if (want === "none")
            return own;
        return want !== "" && want !== own ? want : Appearance.hoverPartner(own);
    }

    function shapeNow(id: string): string {
        if (Config.lock.softHoverMorph && face.hoverId === id && face.dragId === "")
            return face.hoverShapeOf(id);
        return face.shapeOf(id);
    }

    // The clock's own shape right now: its style, or the hover shape while
    // the pointer is on a clock that has a dial.
    readonly property string clockShapeNow: Config.lock.softHoverMorph && face.hoverId === "clock" && face.dialClock && face.dragId === "" ? face.hoverShapeOf("clock") : face.clockShape

    function cornersOf(id: string): string {
        return face.st(id).corners ?? "round";
    }

    // ── each element's colours (lock.softStyle[id].fill / .hi) ────────────
    //  FILL: tone (the SOFT TONE, the default) · tint (tone leaning into the
    //  accent) · accent (the accent, deepened so white text stays readable)
    //  · glass (the tone, see-through) · black. HIGHLIGHT — the icons and the
    //  accent words on it: auto (the accent, white on an accent fill) ·
    //  accent · ink. MODULE OPACITY (lock.softOpacity) lays over all of them.
    readonly property real moduleOpacity: Math.max(0.15, Math.min(1, Number(Config.lock.softOpacity ?? 1)))

    function fillKind(id: string): string {
        return `${face.st(id).fill ?? ""}`;
    }

    function fillOf(id: string): color {
        const c = face.fillFor(face.fillKind(id));
        return Colours.alpha(c, c.a * face.moduleOpacity);
    }

    // A fill by its name, before MODULE OPACITY — the inspector's swatches.
    function fillFor(kind: string): color {
        let c = face.tone;
        switch (kind) {
        case "tint":
            c = Colours.mix(face.tone, face.accent, 0.34);
            break;
        case "accent":
            c = Colours.mix(face.accent, Qt.rgba(0, 0, 0, 1), 0.32);
            break;
        case "glass":
            c = Colours.alpha(face.tone, 0.5);
            break;
        case "black":
            c = Qt.rgba(0.035, 0.035, 0.045, 1);
            break;
        }
        return c;
    }

    // One colour for every element at once (the inspector's FOR ALL).
    function setStyleAll(key: string, value: var): void {
        const all = face.copy(face.styleMap);
        for (let i = 0; i < face.elementIds.length; i++) {
            const id = face.elementIds[i];
            all[id] = Object.assign({}, all[id] ?? {});
            all[id][key] = value;
        }
        face.setMany({
            "lock.softStyle": all
        });
    }

    // The same fill, a step lighter — under the pointer.
    function fillHighOf(id: string): color {
        const c = face.fillOf(id);
        return Colours.alpha(Colours.mix(c, Colours.ink, 0.1), Math.min(1, c.a + 0.04));
    }

    function hiOf(id: string): color {
        switch (`${face.st(id).hi ?? ""}`) {
        case "accent":
            return face.fillKind(id) === "accent" ? Colours.mix(face.accent, Colours.ink, 0.55) : face.accent;
        case "ink":
            return Colours.ink;
        default:
            return face.fillKind(id) === "accent" ? Colours.ink : face.accent;
        }
    }

    function radiusFor(id: string, h: real): real {
        switch (face.cornersOf(id)) {
        case "square":
            return 6 * face.u;
        case "soft":
            return Math.min(h / 2, 16 * face.u);
        default:
            return h / 2;
        }
    }

    readonly property string clockForm: face.st("clock").form ?? (face.layout === "greeting" ? "hands" : "full")
    readonly property string mediaForm: face.st("media").form ?? (face.layout === "greeting" ? "card" : "pill")
    readonly property real cell: face.height * 0.215
    readonly property real handsSize: face.cell * face.clockScale
    // The hands-only dial needs a shape; a bare or one-line clock lends the gear.
    readonly property string handsShape: face.analog || face.clockShape === "none" || face.clockShape === "line" ? "sun" : face.clockShape

    // ── writing: only the real lock and the arranging editor may
    function setMany(map: var): void {
        if (face.preview && !face.arranging)
            return;
        Config.setMany(map);
    }

    function setStyle(id: string, key: string, value: var): void {
        const all = face.copy(face.styleMap);
        all[id] = Object.assign({}, all[id] ?? {});
        all[id][key] = value;
        face.setMany({
            "lock.softStyle": all
        });
    }

    function setShown(id: string, on: bool): void {
        const all = face.copy(face.styleMap);
        all[id] = Object.assign({}, all[id] ?? {});
        all[id].show = on;
        const batch = {
            "lock.softStyle": all
        };
        const key = face.toggleKeys[id];
        if (key && on)
            batch[key] = true;
        face.setMany(batch);
        Sfx.toggle();
    }

    function setShape(id: string, kind: string): void {
        if (id === "clock") {
            // The clock's shape IS its style: a shape turns it into a dial.
            const batch = {
                "lock.clockShape": kind === "circle" ? "circle" : kind
            };
            if (face.analog)
                batch["lock.clockFace"] = "";
            face.setMany(batch);
            return;
        }
        face.setStyle(id, "shape", kind);
    }

    // Where an element's centre is right now, in pixels.
    function pos(id: string): point {
        if (face.dragId === id)
            return face.dragPoint;
        if (face.layout === "custom") {
            const p = face.place[id];
            if (p && p.x !== undefined)
                return Qt.point(p.x * face.width, p.y * face.height);
        }
        return face.preset[id] ?? Qt.point(face.width / 2, face.height / 2);
    }

    // The elements as the preset layouts place them — worked out from their
    // real sizes, so a bigger clock pushes the pills down instead of into them.
    readonly property var preset: face.computePreset(face.layout === "custom" ? "vertical" : face.layout)

    function computePreset(L: string): var {
        const W = face.width;
        const H = face.height;
        const u = face.u;
        const sz = it => ({
                w: it.width * it.size,
                h: it.height * it.size
            });
        const on = id => face.shown(id);
        const clk = sz(pClock);
        const pow = sz(pPower);
        const sta = sz(pStatus);
        const pw = sz(pPassword);
        const med = sz(pMedia);
        const out = {};

        // The column of pills: power beside the bell (or the bell's panel
        // alone), then the password, then the music.
        const column = (cx, top, withClock) => {
            let y = top;
            if (withClock) {
                out.clock = Qt.point(cx, y + clk.h / 2);
                y += clk.h + 44 * u;
            }
            const showPow = on("power") && !face.notifsOpen;
            const showSta = on("status");
            if (showPow || showSta) {
                const rowW = (showPow ? pow.w : 0) + (showPow && showSta ? 4 * u : 0) + (showSta ? sta.w : 0);
                const rowH = Math.max(showPow ? pow.h : 0, showSta ? sta.h : 0);
                out.power = Qt.point(cx - rowW / 2 + pow.w / 2, y + rowH / 2);
                out.status = Qt.point(showPow ? cx + rowW / 2 - sta.w / 2 : cx, y + rowH / 2);
                y += rowH + 14 * u;
            } else {
                out.power = Qt.point(cx, y);
                out.status = Qt.point(cx, y);
            }
            out.password = Qt.point(cx, y + pw.h / 2);
            y += pw.h + 14 * u;
            out.media = Qt.point(cx, y + med.h / 2);
            return y + (pMedia.on ? med.h : 0);
        };
        const heightOf = withClock => {
            let h = 0;
            if (withClock)
                h += clk.h + 44 * u;
            if ((on("power") && !face.notifsOpen) || on("status"))
                h += Math.max(on("power") && !face.notifsOpen ? pow.h : 0, on("status") ? sta.h : 0) + 14 * u;
            h += pw.h;
            if (pMedia.on)
                h += 14 * u + med.h;
            return h;
        };

        if (L === "horizontal") {
            out.clock = Qt.point(W * 0.32, H / 2);
            column(W * 0.68, (H - heightOf(false)) / 2, false);
            out.date = Qt.point(W * 0.1, H * 0.13);
            out.weather = Qt.point(W * 0.9, H * 0.13);
            out.greeting = Qt.point(W * 0.32, H * 0.5);
            out.avatar = Qt.point(W * 0.68, H * 0.2);
            out.lyric = Qt.point(W * 0.5, H * 0.93);
        } else if (L === "greeting") {
            const col = W * 0.117;
            out.clock = Qt.point(col, H * 0.19);
            out.date = Qt.point(col, H * 0.49);
            out.weather = Qt.point(col, H * 0.795);
            out.greeting = Qt.point(W / 2, H * 0.47);
            out.password = Qt.point(W / 2, H * 0.87 + pw.h / 2);
            const powH = on("power") ? pow.h + 8 * u : 0;
            out.media = Qt.point(W - W * 0.028 - med.w / 2, H - H * 0.028 - powH - med.h / 2);
            out.power = Qt.point(W - W * 0.028 - pow.w / 2, H - H * 0.028 - pow.h / 2);
            out.status = Qt.point(W - W * 0.028 - sta.w / 2, H * 0.05 + sta.h / 2);
            out.avatar = Qt.point(W - col, H * 0.24);
            out.lyric = Qt.point(W / 2, H * 0.8);
        } else {
            column(W / 2, Math.max(24 * u, (H - heightOf(true)) / 2 + 12 * u), true);
            out.date = Qt.point(W * 0.1, H * 0.13);
            out.weather = Qt.point(W * 0.9, H * 0.13);
            out.greeting = Qt.point(W * 0.17, H * 0.5);
            out.avatar = Qt.point(W * 0.83, H * 0.5);
            out.lyric = Qt.point(W / 2, H * 0.955);
        }
        return out;
    }

    // ── arranging
    // The first drag in a preset turns it into CUSTOM: every element keeps
    // the place and the look it has right now, then the dragged one moves.
    function commitPlace(id: string, x: real, y: real): void {
        const W = Math.max(1, face.width);
        const H = Math.max(1, face.height);
        let place = face.layout === "custom" ? face.copy(face.place) : {};
        const style = face.copy(face.styleMap);
        if (face.layout !== "custom") {
            for (const e of face.elementIds) {
                const c = face.pos(e);
                place[e] = {
                    x: c.x / W,
                    y: c.y / H
                };
                style[e] = Object.assign({}, style[e] ?? {});
                if (style[e].show === undefined)
                    style[e].show = face.layoutDefault(e);
            }
            style.clock.form = style.clock.form ?? face.clockForm;
            style.media.form = style.media.form ?? face.mediaForm;
        }
        place[id] = {
            x: Math.max(0, Math.min(1, x / W)),
            y: Math.max(0, Math.min(1, y / H))
        };
        face.setMany({
            "lock.layout": "custom",
            "lock.softPlace": place,
            "lock.softStyle": style
        });
    }

    // The arrow keys while customising: nudge the picked element (Shift: more).
    function keyNudge(event: var): bool {
        if (!face.editMode || face.selectedId === "")
            return false;
        const keys = [Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down];
        if (keys.indexOf(event.key) < 0)
            return false;
        const st = (event.modifiers & Qt.ShiftModifier) ? 0.02 : 0.004;
        face.nudge(face.selectedId, event.key === Qt.Key_Left ? -st : (event.key === Qt.Key_Right ? st : 0), event.key === Qt.Key_Up ? -st : (event.key === Qt.Key_Down ? st : 0));
        return true;
    }

    // The settings' editor takes the arrow keys itself.
    Keys.onPressed: event => event.accepted = face.arranging && face.keyNudge(event)

    function nudge(id: string, dx: real, dy: real): void {
        const c = face.pos(id);
        face.commitPlace(id, c.x + dx * face.width, c.y + dy * face.height);
    }

    function centre(id: string): void {
        face.commitPlace(id, face.width / 2, face.pos(id).y);
    }

    // One element back to its layout's own place and look.
    function resetElement(id: string): void {
        const style = face.copy(face.styleMap);
        const keep = style[id]?.show;
        delete style[id];
        // In CUSTOM an element must keep being shown or hidden as it was.
        if (face.layout === "custom" && keep !== undefined)
            style[id] = {
                show: keep
            };
        const place = face.copy(face.place);
        delete place[id];
        face.setMany({
            "lock.softStyle": style,
            "lock.softPlace": place
        });
    }

    function resetAll(): void {
        face.setMany({
            "lock.softStyle": {},
            "lock.softPlace": {},
            "lock.layout": face.layout === "custom" ? "vertical" : face.layout
        });
        face.selectedId = "clock";
    }

    function replay(): void {
        face.restartEntrance();
    }

    // ── motion
    // How an element arrives (lock.softAnimation), from its share of the dial.
    function enterOf(id: string): real {
        const s = Math.max(0, Math.min(0.14, Config.lock.softStagger));
        return face.slice(0.1 + (face.enterOrder[id] ?? 0) * s, 0.9 - 5 * s);
    }

    function fx(p: real, id: string): var {
        const e = face.outCubic(p);
        const u = face.u;
        switch (Config.lock.softAnimation) {
        case "fade":
            return {
                o: e,
                s: 1,
                r: 0,
                dx: 0,
                dy: 0
            };
        case "zoom":
            return {
                o: e,
                s: 0.78 + 0.22 * e,
                r: 0,
                dx: 0,
                dy: 0
            };
        case "drop":
            return {
                o: Math.min(1, p * 2.5),
                s: 1,
                r: 0,
                dx: 0,
                dy: -(1 - face.outBack(p)) * 150 * u
            };
        case "pop":
            return {
                o: Math.min(1, p * 3),
                s: Math.max(0.01, face.outBack(p)),
                r: 0,
                dx: 0,
                dy: 0
            };
        case "spin":
            return {
                o: e,
                s: 0.55 + 0.45 * e,
                r: (1 - e) * -140,
                dx: 0,
                dy: 0
            };
        case "slide":
            return {
                o: e,
                s: 1,
                r: 0,
                dx: (face.pos(id).x < face.width / 2 ? -1 : 1) * (1 - e) * 260 * u,
                dy: 0
            };
        default:
            return {
                o: e,
                s: 0.96 + 0.04 * e,
                r: 0,
                dx: 0,
                dy: (1 - e) * 26 * u
            };
        }
    }

    // Elements glide to a new place once they have arrived.
    property bool settled: false
    readonly property bool glide: Config.lock.softGlide && face.settled

    // The slow turn of every shape (SHAPES TURN SLOWLY).
    property real idleSpin: 0

    NumberAnimation on idleSpin {
        running: Config.lock.softShapeSpin && face.live && face.visible && !face.leaving
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 90000
    }

    // Snap guides while dragging.
    Rectangle {
        x: face.width / 2 - 1
        width: 2
        height: face.height
        color: Colours.alpha(face.accent, 0.6)
        visible: face.dragId !== "" && face.snapX
        z: 90
    }
    Rectangle {
        y: face.height / 2 - 1
        width: face.width
        height: 2
        color: Colours.alpha(face.accent, 0.6)
        visible: face.dragId !== "" && face.snapY
        z: 90
    }

    // ═══════════════════════════════════════════════════════ the elements
    Placed {
        id: pGreeting

        eid: "greeting"
        fadesInAmbient: false

        Item {
            id: cloud

            width: face.height * 0.52
            height: width

            M3Shape {
                anchors.fill: parent
                kind: face.shapeNow("greeting")
                color: face.fillOf("greeting")
                intro: false
                spin: face.idleSpin
            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: parent.height * Appearance.shapeCentre(face.shapeOf("greeting"))
                spacing: 10 * face.u

                SoftText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: face.hello
                    color: Colours.alpha(Colours.ink, 0.5)
                    font.pixelSize: 44 * face.u
                    font.weight: Font.Light
                }
                SoftText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, cloud.width * 0.72)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: face.who
                    color: face.hiOf("greeting")
                    font.family: face.clockFamily
                    font.pixelSize: 84 * face.u * Math.max(0.6, Math.min(1.6, Config.lock.clockFontScale))
                    font.weight: Font.Bold
                }
                SoftText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, cloud.width * 0.6)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: Config.lock.lyrics && Lyrics.hasSynced && Lyrics.current !== "" ? Lyrics.current : Qt.formatDateTime(face.now, Config.bar.clock.format24h ? "HH:mm" : "h:mm AP")
                    color: Colours.alpha(Colours.ink, 0.5)
                    font.pixelSize: 15 * face.u
                    font.italic: true
                }
            }
        }
    }

    Placed {
        id: pDate

        eid: "date"
        fadesInAmbient: false

        Item {
            width: face.cell * 0.92
            height: width

            M3Shape {
                anchors.fill: parent
                kind: face.shapeNow("date")
                color: face.fillOf("date")
                intro: false
                spin: face.idleSpin
            }

            Column {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: parent.height * Appearance.shapeCentre(face.shapeOf("date"))
                spacing: 4 * face.u

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "calendar_today"
                    color: face.hiOf("date")
                    font.pixelSize: 28 * face.u
                }
                SoftText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(face.now, "ddd d MMM").toLowerCase()
                    font.pixelSize: 17 * face.u
                    font.weight: Font.Medium
                }
                SoftText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(face.now, "yyyy")
                    color: Colours.alpha(Colours.ink, 0.72)
                    font.pixelSize: 14 * face.u
                }
            }
        }
    }

    Placed {
        id: pWeather

        eid: "weather"
        fadesInAmbient: false

        Item {
            width: face.cell * 1.05
            height: width

            M3Shape {
                anchors.fill: parent
                kind: face.shapeNow("weather")
                color: face.fillOf("weather")
                intro: false
                spin: face.idleSpin
            }

            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: parent.height * Appearance.shapeCentre(face.shapeOf("weather"))
                spacing: 6 * face.u

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Weather.ready ? Weather.icon : "cloud"
                    color: face.hiOf("weather")
                    font.pixelSize: 46 * face.u
                    filled: true
                }
                SoftText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.ready ? Weather.short : "—"
                    font.pixelSize: 44 * face.u
                    font.weight: Font.Normal
                }
            }
        }
    }

    Placed {
        id: pAvatar

        eid: "avatar"
        fadesInAmbient: false

        Item {
            id: avatar

            width: face.cell
            height: width

            M3Shape {
                anchors.fill: parent
                kind: face.shapeNow("avatar")
                color: face.fillOf("avatar")
                intro: false
                spin: face.idleSpin
            }

            Icon {
                anchors.centerIn: parent
                visible: !face.faceExists
                name: "person"
                color: face.hiOf("avatar")
                font.pixelSize: parent.width * 0.45
            }

            Item {
                id: photo

                anchors.fill: parent
                visible: face.faceExists
                layer.enabled: true
                layer.effect: GE.OpacityMask {
                    maskSource: M3Shape {
                        width: photo.width
                        height: photo.height
                        kind: face.shapeNow("avatar")
                        color: "white"
                        intro: false
                        spin: face.idleSpin
                    }
                }

                Image {
                    anchors.fill: parent
                    source: face.faceExists ? face.faceUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    sourceSize.width: 512
                    sourceSize.height: 512
                }
            }
        }
    }

    Placed {
        id: pLyric

        eid: "lyric"
        fadesInAmbient: false
        live: face.editMode || (Lyrics.hasSynced && Lyrics.current !== "")

        SoftText {
            width: Math.min(implicitWidth, face.width * 0.6)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: Lyrics.current !== "" ? Lyrics.current : "♪  the lyric line"
            color: Colours.alpha(Colours.ink, 0.85)
            font.pixelSize: 24 * face.u
            font.italic: true
        }
    }

    Placed {
        id: pClock

        eid: "clock"
        fadesInAmbient: false

        Item {
            id: clockBox

            width: face.clockForm === "hands" ? face.handsSize : clock.implicitWidth
            height: face.clockForm === "hands" ? face.handsSize : clock.implicitHeight

            SoftClock {
                id: clock

                anchors.centerIn: parent
                visible: face.clockForm !== "hands"
                now: face.now
                shape: face.clockShapeNow
                analog: face.analog
                dots: face.dots
                family: face.clockFamily
                h24: Config.bar.clock.format24h
                size: face.dialClock ? face.clockDial : face.clockBare
                digitScale: Math.max(0.6, Math.min(1.6, Config.lock.clockFontScale))
                hourColour: face.hourInk
                minuteColour: face.minuteInk
                fill: face.fillOf("clock")
                spin: face.idleSpin
                motion: Config.lock.softDigitMotion
            }

            ClockDial {
                anchors.fill: parent
                visible: face.clockForm === "hands"
                size: face.handsSize
                now: face.now
                shape: Config.lock.softHoverMorph && face.hoverId === "clock" && face.dragId === "" ? Appearance.hoverPartner(face.handsShape) : face.handsShape
                digits: false
                numerals: false
                h24: Config.bar.clock.format24h
                fill: face.fillOf("clock")
                hourColour: face.hourInk
                spin: face.idleSpin
            }

            // The arrows that walk the clock's styles — while customising
            // on the lock.
            Repeater {
                model: [-1, 1]

                RoundButton {
                    required property var modelData

                    // Where it would land on the screen: shown only if it fits.
                    readonly property real reach: (clockBox.width / 2 + 34 * face.u + width) * pClock.size
                    readonly property bool fits: modelData < 0 ? pClock.c.x - reach > 8 * face.u : pClock.c.x + reach < face.width - 8 * face.u

                    x: modelData < 0 ? -width - 34 * face.u : clockBox.width + 34 * face.u
                    anchors.verticalCenter: parent.verticalCenter
                    icon: modelData < 0 ? "chevron_left" : "chevron_right"
                    shown: face.editing && !face.arranging && face.selectedId === "clock" && fits && face.dragId === ""
                    z: 200
                    onClicked: face.stepStyle(modelData)
                }
            }
        }
    }

    Placed {
        id: pPower

        eid: "power"
        // In a preset the bell's panel takes the power pills' row.
        live: !(face.notifsOpen && face.layout !== "custom" && face.layout !== "greeting")

        PowerPill {
            corners: face.cornersOf("power")
        }
    }

    Placed {
        id: pStatus

        eid: "status"

        Item {
            width: face.notifsOpen ? notifPanel.width : statusPill.width
            height: face.notifsOpen ? notifPanel.height : statusPill.height

            Pill {
                id: statusPill

                eid: "status"
                corners: face.cornersOf("status")
                padding: 14 * face.u
                visible: opacity > 0.01
                opacity: face.notifsOpen ? 0 : 1
                onClicked: {
                    face.notifsOpen = true;
                    Sfx.select();
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * face.u

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "notifications"
                        color: Colours.ink
                        font.pixelSize: 15 * face.u
                    }
                    SoftText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Notifs.total}`
                    }
                    Item {
                        width: 4 * face.u
                        height: 1
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Weather.ready
                        name: Weather.icon
                        color: Colours.ink
                        font.pixelSize: 15 * face.u
                    }
                    SoftText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Weather.ready
                        text: Weather.short
                    }
                }
            }

            NotifPanel {
                id: notifPanel

                width: 556 * face.u
                radius: ({
                        square: 8,
                        soft: 16
                    })[face.cornersOf("status")] * face.u || 26 * face.u
                visible: opacity > 0.01
                opacity: face.notifsOpen ? 1 : 0
                scale: face.notifsOpen ? 1 : 0.94

                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
    }

    Placed {
        id: pPassword

        eid: "password"

        Column {
            spacing: 10 * face.u

            PasswordPill {
                id: password

                width: 556 * face.u
                corners: face.cornersOf("password")
            }

            // The state line: errors, caps lock, num lock.
            SoftText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: face.stateLine
                color: Locker.failed ? Colours.danger : Colours.alpha(Colours.ink, 0.75)
                font.pixelSize: 13 * face.u
            }
        }
    }

    Placed {
        id: pMedia

        eid: "media"
        live: face.hasMusic || face.editMode

        Item {
            readonly property bool card: face.mediaForm === "card" || face.mediaOpen

            width: card ? mediaCard.width : mediaPill.width
            height: card ? mediaCard.height : mediaPill.height

            Pill {
                id: mediaPill

                eid: "media"
                corners: face.cornersOf("media")
                visible: opacity > 0.01
                opacity: parent.card ? 0 : 1
                padding: 16 * face.u
                onClicked: {
                    face.mediaOpen = true;
                    Sfx.select();
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * face.u

                    EqBars {
                        anchors.verticalCenter: parent.verticalCenter
                        playing: face.mp?.playing ?? false
                    }
                    SoftText {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, 300 * face.u)
                        elide: Text.ElideRight
                        text: face.hasMusic ? ((face.mp?.artist ?? "") !== "" ? `${face.mp.title} - ${face.mp.artist}` : (face.mp?.title ?? "")) : "Nothing playing"
                    }
                }
            }

            SoftMediaCard {
                id: mediaCard

                width: face.mediaForm === "card" ? 384 * face.u : 556 * face.u
                compact: face.mediaForm === "card"
                u: face.u
                tone: face.fillOf("media")
                toneHigh: face.fillHighOf("media")
                accent: face.accent
                onAccent: face.onAccent
                family: face.family
                coverShape: face.shapeNow("media")
                coverSpin: face.idleSpin
                radius: ({
                        square: 8,
                        soft: 16
                    })[face.cornersOf("media")] * face.u || 26 * face.u
                interactive: !face.preview && !face.editMode
                collapsible: face.mediaForm !== "card"
                onCollapse: face.mediaOpen = false
                visible: opacity > 0.01
                opacity: parent.card ? 1 : 0
                scale: parent.card ? 1 : 0.94

                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 280
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
    }

    readonly property string stateLine: {
        if (Locker.failed)
            return "Incorrect password. Please try again.";
        if (!Config.lock.stateHints)
            return "";
        const parts = [];
        if (Kbd.capsLock)
            parts.push("Caps lock is on");
        if (Kbd.numLock)
            parts.push("Num lock is on");
        return parts.join("  ·  ");
    }

    // ═══════════════════════════════════════ customise — the two panels
    //  On the lock the pencil shows them; the settings' editor has its own.
    Panel {
        x: 24 * face.u
        y: 24 * face.u
        title: "Element"

        SoftInspector {
            width: parent.width
            face: face
            u: face.u
            section: "element"
        }
    }

    Panel {
        x: face.width - width - 24 * face.u
        y: 24 * face.u
        title: "Everything"

        SoftInspector {
            width: parent.width
            face: face
            u: face.u
            section: "global"
        }
    }

    // ═══════════════════════════════════════════════════ the hidden input
    TextInput {
        id: input

        objectName: "lockInput"
        width: 1
        height: 1
        opacity: 0
        focus: !face.preview
        enabled: !Locker.busy && !face.preview
        echoMode: TextInput.Password

        onTextChanged: {
            if (input.text.length > face._queue.length)
                face.fillDeck();
        }

        onAccepted: face.attempt()

        Keys.onPressed: event => {
            face.wake();
            // Customising: the arrows nudge the picked element.
            event.accepted = face.keyNudge(event);
        }

        Keys.onEscapePressed: {
            if (face.editing) {
                face.editing = false;
                return;
            }
            if (face.notifsOpen || face.mediaOpen) {
                face.notifsOpen = false;
                face.mediaOpen = false;
                return;
            }
            input.text = "";
            face.pendingAction = "";
            face.showPassword = false;
        }
    }

    // A stray click anywhere gives the keyboard back to the password.
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !face.preview
        onClicked: {
            input.forceActiveFocus();
            face.notifsOpen = false;
        }
    }

    // ══════════════════════════════════════════════ test mode · way out
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: face.height * 0.03
        width: testText.implicitWidth + 40 * face.u
        height: 40 * face.u
        radius: height / 2
        color: Colours.warning
        visible: Locker.testing && !face.preview

        SoftText {
            id: testText

            anchors.centerIn: parent
            text: "Test lock — releases itself in 20 seconds"
            color: Colours.paper
            font.weight: Font.DemiBold
        }
    }

    SoftText {
        anchors.horizontalCenter: parent.horizontalCenter
        y: face.height * 0.955
        visible: !face.preview && (Locker.attempts >= 3 || Locker.pamErrors > 0)
        text: `${Locker.pamConfig ? "PAM: " + Locker.pamConfig + "   ·   " : ""}Stuck?  Ctrl+Alt+F2  ·  log in  ·  loginctl unlock-session`
        color: Colours.alpha(Colours.ink, 0.6)
        font.family: Appearance.fontFamily.mono
        font.pixelSize: 12 * face.u
    }

    // The preview is a picture: nothing in it may be clicked or typed into.
    MouseArea {
        anchors.fill: parent
        z: 1000
        visible: face.preview && !face.arranging
        enabled: face.preview && !face.arranging
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    // ═══════════════════════════════════════════════════════ the parts
    component SoftText: Text {
        color: Colours.ink
        font.family: face.family
        font.pixelSize: 14 * face.u
        font.weight: Font.Medium
        antialiasing: true
        renderType: Text.QtRendering
    }

    // A small rounded pill in the deep tone, sized by what it holds.
    component Pill: Rectangle {
        id: pill

        default property alias content: holder.data
        property real padding: 12 * face.u
        property string corners: "round"
        // Whose colours it wears (lock.softStyle[eid].fill).
        property string eid: ""

        signal clicked

        implicitWidth: holder.childrenRect.width + pill.padding * 2
        implicitHeight: 38 * face.u
        width: implicitWidth
        height: implicitHeight
        radius: pill.corners === "square" ? 6 * face.u : (pill.corners === "soft" ? Math.min(height / 2, 12 * face.u) : height / 2)
        color: pillHover.hovered ? face.fillHighOf(pill.eid) : face.fillOf(pill.eid)
        antialiasing: true
        scale: pillTap.pressed ? 0.96 : 1

        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 110
            }
        }

        // What the pill holds centres itself on the pill's height.
        Item {
            id: holder

            x: pill.padding
            width: childrenRect.width
            height: parent.height
        }

        HoverHandler {
            id: pillHover

            enabled: !face.preview
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: pillTap

            enabled: !face.preview
            onTapped: pill.clicked()
        }
    }

    // LOG OUT · RESTART · SHUT DOWN — each one arms the password.
    component PowerPill: Rectangle {
        id: pp

        property string corners: "round"

        width: ppRow.width + 12 * face.u
        height: 38 * face.u
        radius: pp.corners === "square" ? 6 * face.u : (pp.corners === "soft" ? 12 * face.u : height / 2)
        color: face.fillOf("power")
        antialiasing: true

        Row {
            id: ppRow

            anchors.centerIn: parent
            spacing: 2 * face.u

            Repeater {
                model: [["logout", "logout", "Logout"], ["reboot", "restart_alt", "Restart"], ["poweroff", "power_settings_new", "Shutdown"]]

                Rectangle {
                    id: pb

                    required property var modelData

                    readonly property bool armed: face.pendingAction === pb.modelData[0]

                    width: pbRow.width + 20 * face.u
                    height: 30 * face.u
                    radius: pp.corners === "square" ? 4 * face.u : (pp.corners === "soft" ? 9 * face.u : height / 2)
                    color: pb.armed ? Colours.warning : (pbHover.hovered ? Colours.alpha(Colours.ink, 0.1) : "transparent")
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }

                    Row {
                        id: pbRow

                        anchors.centerIn: parent
                        spacing: 5 * face.u

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: pb.modelData[1]
                            color: pb.armed ? Colours.paper : Colours.ink
                            font.pixelSize: 15 * face.u
                        }
                        SoftText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: pb.modelData[2]
                            color: pb.armed ? Colours.paper : Colours.ink
                        }
                    }

                    HoverHandler {
                        id: pbHover

                        enabled: !face.preview
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        enabled: !face.preview
                        onTapped: face.arm(pb.modelData[0])
                    }
                }
            }
        }
    }

    // The password: a pill with its label, the shapes as you type, and the
    // pencil (customise) — which gives the field its room back as soon as
    // you type, and turns into the tick while you customise.
    component PasswordPill: Item {
        id: pw

        readonly property bool typing: input.text.length > 0
        readonly property bool button: (Config.lock.softEdit && !pw.typing) || face.editing
        property string corners: "round"
        readonly property real r: pw.corners === "square" ? 8 * face.u : (pw.corners === "soft" ? 22 * face.u : pw.height / 2)

        height: 88 * face.u

        Rectangle {
            id: field

            width: pw.button ? pw.width - 112 * face.u : pw.width
            height: parent.height
            radius: pw.r
            // The right side meets the button with a tight corner.
            topRightRadius: pw.button ? Math.min(pw.r, 8 * face.u) : pw.r
            bottomRightRadius: pw.button ? Math.min(pw.r, 8 * face.u) : pw.r
            // Armed (a power pill asked for the password): warm with warning.
            color: face.pendingAction !== "" ? Colours.mix(face.fillOf("password"), Colours.warning, 0.16) : face.fillOf("password")
            antialiasing: true

            Behavior on width {
                NumberAnimation {
                    duration: 240
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 180
                }
            }

            Row {
                x: 26 * face.u
                y: 14 * face.u
                spacing: 5 * face.u
                opacity: 0.7

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Locker.busy ? "timer" : "lock"
                    color: Colours.ink
                    font.pixelSize: 12 * face.u
                }
                SoftText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: face.pendingAction !== "" ? `Password to ${face.actionWords[face.pendingAction]}` : "Password"
                    font.pixelSize: 12 * face.u
                }
            }

            SoftText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 6 * face.u
                visible: !pw.typing
                width: Math.min(implicitWidth, field.width - 60 * face.u)
                elide: Text.ElideRight
                text: {
                    if (face.actionNote !== "")
                        return face.actionNote;
                    if (Locker.busy)
                        return "Checking…";
                    if (face.pendingAction !== "")
                        return `Type your password to ${face.actionWords[face.pendingAction]}…`;
                    return "Type your password...";
                }
                color: face.pendingAction !== "" || Locker.busy ? Colours.warning : Colours.alpha(Colours.ink, 0.78)
                font.pixelSize: 14 * face.u
            }

            // The shapes, one per keystroke, centred.
            Item {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 6 * face.u
                width: field.width - 70 * face.u
                height: 28 * face.u
                clip: true
                visible: pw.typing

                Row {
                    anchors.centerIn: parent
                    spacing: 6 * face.u
                    visible: !face.showPassword

                    Repeater {
                        model: 24

                        Item {
                            id: g

                            required property int index
                            readonly property bool lit: g.index < input.text.length

                            width: 22 * face.u
                            height: 22 * face.u
                            visible: g.lit
                            scale: 0
                            property int dotKind: 0
                            property color col: face.accent

                            LockGlyph {
                                anchors.fill: parent
                                anchors.margins: 1 * face.u
                                kind: g.dotKind
                                col: g.col
                            }

                            onLitChanged: {
                                if (g.lit) {
                                    g.dotKind = face.shapeAt(g.index);
                                    g.col = face.accent;
                                    pop.restart();
                                    settle.restart();
                                } else {
                                    pop.stop();
                                    settle.stop();
                                    g.scale = 0;
                                }
                            }

                            NumberAnimation {
                                id: pop

                                target: g
                                property: "scale"
                                from: 0
                                to: 1
                                duration: 180
                                easing.type: Easing.OutBack
                                easing.overshoot: 2.2
                            }
                            // The newest shape glows in the accent, then
                            // cools to ink — SETTLE also rounds it off.
                            Timer {
                                id: settle

                                interval: 260
                                onTriggered: {
                                    g.col = Colours.ink;
                                    if (Config.lock.passwordShapes === "settle")
                                        g.dotKind = 0;
                                }
                            }
                            Behavior on col {
                                ColorAnimation {
                                    duration: 300
                                }
                            }
                        }
                    }
                }

                SoftText {
                    anchors.centerIn: parent
                    visible: face.showPassword
                    text: input.text
                    font.family: Appearance.fontFamily.mono
                }
            }

            // Peek at what you typed.
            Icon {
                anchors.right: parent.right
                anchors.rightMargin: 24 * face.u
                anchors.verticalCenter: parent.verticalCenter
                visible: pw.typing && Config.lock.passwordPeek
                name: face.showPassword ? "visibility_off" : "visibility"
                color: Colours.alpha(Colours.ink, 0.6)
                font.pixelSize: 18 * face.u

                TapHandler {
                    enabled: !face.preview
                    onTapped: face.showPassword = !face.showPassword
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                enabled: !face.preview
                onClicked: input.forceActiveFocus()
            }
        }

        // The pencil — or the tick while customising.
        Rectangle {
            anchors.right: parent.right
            width: 108 * face.u
            height: parent.height
            radius: pw.r
            visible: opacity > 0.01
            opacity: pw.button ? 1 : 0
            topLeftRadius: Math.min(pw.r, 8 * face.u)
            bottomLeftRadius: Math.min(pw.r, 8 * face.u)
            color: face.editing ? face.accent : (penHover.hovered ? face.toneHigh : face.tone)
            antialiasing: true
            scale: penTap.pressed ? 0.95 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }

            Icon {
                anchors.centerIn: parent
                name: face.editing ? "check" : "edit"
                color: face.editing ? face.onAccent : Colours.ink
                font.pixelSize: 22 * face.u
            }

            HoverHandler {
                id: penHover

                enabled: !face.preview
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                id: penTap

                enabled: !face.preview
                onTapped: {
                    face.editing = !face.editing;
                    Sfx.toggle();
                    input.forceActiveFocus();
                }
            }
        }
    }

    // The bell's panel: the newest notifications, or a calm "nothing here".
    component NotifPanel: Rectangle {
        id: np

        readonly property var items: Notifs.history.slice(0, Math.max(1, Config.lock.notifsCount))

        height: Math.max(180 * face.u, npCol.implicitHeight + 32 * face.u)
        radius: 26 * face.u
        color: face.fillOf("status")
        antialiasing: true

        Column {
            id: npCol

            x: 20 * face.u
            y: 16 * face.u
            width: parent.width - 40 * face.u
            spacing: 10 * face.u

            Item {
                width: parent.width
                height: 24 * face.u

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * face.u

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "notifications"
                        color: Colours.ink
                        font.pixelSize: 16 * face.u
                    }
                    SoftText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Notifications"
                        font.weight: Font.DemiBold
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * face.u

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Weather.ready
                        name: Weather.icon
                        color: Colours.ink
                        font.pixelSize: 15 * face.u
                    }
                    SoftText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Weather.ready
                        text: Weather.short
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "expand_more"
                        color: Colours.ink
                        font.pixelSize: 20 * face.u

                        TapHandler {
                            enabled: !face.preview
                            onTapped: face.notifsOpen = false
                        }
                    }
                }
            }

            // Nothing waiting — or, behind the lock, nothing to show.
            Column {
                width: parent.width
                visible: np.items.length === 0 || Config.lock.hideNotifs
                spacing: 6 * face.u
                topPadding: 18 * face.u

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: Config.lock.hideNotifs && np.items.length > 0 ? "visibility_off" : "notifications_off"
                    color: Colours.alpha(Colours.ink, 0.5)
                    font.pixelSize: 24 * face.u
                }
                SoftText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Config.lock.hideNotifs && np.items.length > 0 ? `${Notifs.total} hidden while locked` : "nothing here"
                    color: Colours.alpha(Colours.ink, 0.55)
                    font.pixelSize: 13 * face.u
                }
            }

            Repeater {
                model: Config.lock.hideNotifs ? [] : np.items

                Row {
                    required property var modelData

                    width: npCol.width
                    spacing: 12 * face.u

                    Rectangle {
                        width: 34 * face.u
                        height: width
                        radius: width / 2
                        color: Colours.alpha(face.accent, 0.22)

                        SoftText {
                            anchors.centerIn: parent
                            text: (modelData.appName || modelData.summary || "?").charAt(0).toUpperCase()
                            color: face.accent
                            font.weight: Font.Bold
                        }
                    }

                    Column {
                        width: parent.width - 46 * face.u
                        spacing: 2 * face.u

                        SoftText {
                            width: parent.width
                            elide: Text.ElideRight
                            text: modelData.summary || modelData.appName
                            font.weight: Font.DemiBold
                        }
                        SoftText {
                            width: parent.width
                            elide: Text.ElideRight
                            visible: text !== ""
                            text: (modelData.body || "").replace(/\s+/g, " ")
                            color: Colours.alpha(Colours.ink, 0.65)
                            font.pixelSize: 12 * face.u
                        }
                    }
                }
            }
        }
    }

    // Three little bars that dance while something plays.
    component EqBars: Row {
        id: eq

        property bool playing: false

        spacing: 2 * face.u
        height: 14 * face.u

        Repeater {
            model: 3

            Rectangle {
                id: bar

                required property int index

                anchors.bottom: parent.bottom
                width: 3 * face.u
                height: eq.height * 0.5
                radius: width / 2
                color: Colours.ink

                SequentialAnimation on height {
                    running: eq.playing && face.live && face.visible
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: eq.height * (0.9 - bar.index * 0.15)
                        duration: 260 + bar.index * 90
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: eq.height * (0.3 + bar.index * 0.1)
                        duration: 300 + bar.index * 70
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    // A customise panel: a title and its rows, in the deep tone. It
    // scrolls when the screen is short; the settings' editor has its own.
    component Panel: Rectangle {
        id: panel

        default property alias content: body.data
        property string title: ""
        property bool folded: false

        width: 330 * face.u
        height: panel.folded ? 50 * face.u : Math.min(body.childrenRect.height + 62 * face.u, face.height - 48 * face.u)
        clip: true
        radius: 20 * face.u
        color: Colours.alpha(face.tone, 0.97)
        antialiasing: true
        z: 300
        visible: opacity > 0.01
        opacity: face.editing && !face.arranging ? 1 : 0
        scale: face.editing && !face.arranging ? 1 : 0.94
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutBack
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        // Clicks on the panel stay on the panel.
        MouseArea {
            anchors.fill: parent
        }

        // The title bar: drag it to move the panel out of the way, click
        // the chevron to fold it down to its title.
        Item {
            width: panel.width
            height: 50 * face.u

            DragHandler {
                target: panel
                xAxis.minimum: 0
                xAxis.maximum: face.width - panel.width
                yAxis.minimum: 0
                yAxis.maximum: face.height - 50 * face.u
                cursorShape: Qt.ClosedHandCursor
            }
            HoverHandler {
                cursorShape: Qt.OpenHandCursor
            }

            Icon {
                x: 16 * face.u
                anchors.verticalCenter: parent.verticalCenter
                name: "drag_indicator"
                color: Colours.alpha(Colours.ink, 0.45)
                font.pixelSize: 16 * face.u
            }
            SoftText {
                x: 38 * face.u
                anchors.verticalCenter: parent.verticalCenter
                text: panel.title
                font.pixelSize: 15 * face.u
                font.weight: Font.DemiBold
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 12 * face.u
                anchors.verticalCenter: parent.verticalCenter
                width: 30 * face.u
                height: width
                radius: width / 2
                color: foldHover.hovered ? Colours.alpha(Colours.ink, 0.1) : "transparent"

                Icon {
                    anchors.centerIn: parent
                    name: panel.folded ? "expand_more" : "expand_less"
                    color: Colours.ink
                    font.pixelSize: 20 * face.u
                }
                HoverHandler {
                    id: foldHover

                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: {
                        panel.folded = !panel.folded;
                        Sfx.toggle();
                    }
                }
            }
        }

        Flickable {
            id: panelFlick

            x: 18 * face.u
            y: 48 * face.u
            width: panel.width - 36 * face.u
            height: Math.max(0, panel.height - 62 * face.u)
            visible: !panel.folded || panel.height > 60 * face.u
            contentHeight: body.childrenRect.height
            clip: true
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds

            Item {
                id: body

                width: panelFlick.width
                height: childrenRect.height
            }
        }
    }

    // An element on the stage: what it holds, centred on its place, with its
    // size, its entrance and its show/hide. While customising it gets a
    // dashed outline and its name, and dragging it moves it — snapping to
    // the middle of the screen (hold Alt to place it freely).
    component Placed: Item {
        id: pl

        property string eid: ""
        default property alias content: plHolder.data
        property bool fadesInAmbient: true
        property bool live: true
        readonly property bool on: face.shown(pl.eid) && pl.live
        readonly property real size: face.scaleOf(pl.eid)
        readonly property point c: face.pos(pl.eid)
        readonly property var f: face.fx(face.enterOf(pl.eid), pl.eid)
        readonly property bool picked: face.editMode && face.selectedId === pl.eid
        // The pointer is on it: the lock lifts it a little (and its shape
        // morphs, see shapeNow). Not in the settings' still picture.
        readonly property bool pointed: face.hoverId === pl.eid
        // A hidden element the editor has picked stays as a ghost, so it can
        // still be found, moved and shown again.
        readonly property real want: pl.on ? 1 : (pl.picked && pl.live ? 0.3 : 0)
        property real shownK: pl.want

        Behavior on shownK {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        width: plHolder.childrenRect.width
        height: plHolder.childrenRect.height
        x: Math.round(pl.c.x - pl.width / 2)
        y: Math.round(pl.c.y - pl.height / 2)
        z: face.dragId === pl.eid ? 60 : (pl.picked ? 50 : 0)
        visible: pl.shownK > 0.005
        opacity: pl.f.o * pl.shownK * (pl.fadesInAmbient ? face.awake : 1)
        scale: pl.size * pl.f.s * (0.9 + 0.1 * Math.min(1, pl.shownK)) * (pl.pointed && !face.editMode && face.dragId === "" ? 1.035 : 1)
        rotation: pl.f.r
        transform: Translate {
            x: pl.f.dx
            y: pl.f.dy
        }

        // Moving (a new layout, a nudge, a reset) glides once it has arrived.
        Behavior on x {
            enabled: face.glide && face.dragId !== pl.eid
            NumberAnimation {
                duration: 460
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            enabled: face.glide && face.dragId !== pl.eid
            NumberAnimation {
                duration: 460
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            enabled: face.settled
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: plHolder

            width: childrenRect.width
            height: childrenRect.height
        }

        HoverHandler {
            enabled: (!face.preview || face.arranging) && pl.on
            onHoveredChanged: {
                if (hovered)
                    face.hoverId = pl.eid;
                else if (face.hoverId === pl.eid)
                    face.hoverId = "";
            }
        }

        // ── customising: the outline, the name, the grip
        Shape {
            readonly property real m: 10 * face.u / Math.max(0.3, pl.scale)

            x: -m
            y: -m
            width: pl.width + m * 2
            height: pl.height + m * 2
            visible: face.editMode
            opacity: pl.picked || grip.containsMouse ? 1 : 0.45
            preferredRendererType: Shape.CurveRenderer

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                }
            }

            ShapePath {
                fillColor: pl.picked ? Colours.alpha(face.accent, 0.06) : "transparent"
                strokeColor: pl.picked ? face.accent : Colours.alpha(Colours.ink, 0.7)
                strokeWidth: 2 * face.u / Math.max(0.3, pl.scale)
                strokeStyle: ShapePath.DashLine
                dashPattern: [4, 3]

                PathRectangle {
                    width: pl.width + 20 * face.u / Math.max(0.3, pl.scale)
                    height: pl.height + 20 * face.u / Math.max(0.3, pl.scale)
                    radius: 14 * face.u / Math.max(0.3, pl.scale)
                }
            }
        }

        // The name rides above — or below, when the element sits so high
        // that above would be off the screen.
        Rectangle {
            readonly property real k: 1 / Math.max(0.3, pl.scale)
            readonly property bool below: pl.c.y - pl.height * pl.scale / 2 < 52 * face.u

            anchors.horizontalCenter: parent.horizontalCenter
            y: below ? pl.height + 16 * face.u * k : -height - 16 * face.u * k
            width: tagText.implicitWidth + 20 * face.u
            height: 26 * face.u
            radius: height / 2
            scale: k
            transformOrigin: below ? Item.Top : Item.Bottom
            color: pl.picked ? face.accent : Colours.alpha(face.tone, 0.96)
            visible: face.editMode && (pl.picked || grip.containsMouse)
            z: 101

            SoftText {
                id: tagText

                anchors.centerIn: parent
                text: (face.elementNames[pl.eid] ?? pl.eid) + (pl.on ? "" : "  ·  hidden")
                color: pl.picked ? face.onAccent : Colours.ink
                font.pixelSize: 12 * face.u
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: grip

            property point grab: Qt.point(0, 0)
            property point start: Qt.point(0, 0)
            property bool moved: false

            anchors.fill: parent
            anchors.margins: -10 * face.u / Math.max(0.3, pl.scale)
            z: 100
            visible: face.editMode
            enabled: face.editMode && !face.leaving
            hoverEnabled: true
            preventStealing: true
            cursorShape: grip.moved ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onPressed: mouse => {
                face.selectedId = pl.eid;
                const p = grip.mapToItem(face, mouse.x, mouse.y);
                grip.start = p;
                grip.grab = Qt.point(p.x - pl.c.x, p.y - pl.c.y);
                grip.moved = false;
                if (face.arranging)
                    face.forceActiveFocus();
                else
                    input.forceActiveFocus();
            }
            onPositionChanged: mouse => {
                if (!grip.pressed)
                    return;
                const p = grip.mapToItem(face, mouse.x, mouse.y);
                if (!grip.moved) {
                    if (Math.abs(p.x - grip.start.x) + Math.abs(p.y - grip.start.y) < 5)
                        return;
                    grip.moved = true;
                    face.dragPoint = pl.c;
                    face.dragId = pl.eid;
                }
                let x = Math.max(0, Math.min(face.width, p.x - grip.grab.x));
                let y = Math.max(0, Math.min(face.height, p.y - grip.grab.y));
                const free = (mouse.modifiers & Qt.AltModifier) !== 0;
                const tol = 12 * face.u;
                face.snapX = !free && Math.abs(x - face.width / 2) < tol;
                face.snapY = !free && Math.abs(y - face.height / 2) < tol;
                if (face.snapX)
                    x = face.width / 2;
                if (face.snapY)
                    y = face.height / 2;
                face.dragPoint = Qt.point(x, y);
            }
            onReleased: {
                if (grip.moved) {
                    face.commitPlace(pl.eid, face.dragPoint.x, face.dragPoint.y);
                    Sfx.select();
                }
                grip.moved = false;
                face.dragId = "";
                face.snapX = false;
                face.snapY = false;
            }
            onCanceled: {
                grip.moved = false;
                face.dragId = "";
                face.snapX = false;
                face.snapY = false;
            }
        }
    }

    // A round button in the deep tone (the style arrows).
    component RoundButton: Rectangle {
        id: rb

        property string icon: ""
        property bool shown: true

        signal clicked

        width: 44 * face.u
        height: width
        radius: width / 2
        color: rbHover.hovered ? face.toneHigh : Colours.alpha(face.tone, 0.96)
        visible: opacity > 0.01
        opacity: rb.shown ? 1 : 0
        scale: rbTap.pressed ? 0.9 : (rb.shown ? 1 : 0.6)
        antialiasing: true

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 220
                easing.type: Easing.OutBack
            }
        }

        Icon {
            anchors.centerIn: parent
            name: rb.icon
            color: Colours.ink
            font.pixelSize: 24 * face.u
        }

        HoverHandler {
            id: rbHover

            enabled: !face.preview
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: rbTap

            enabled: !face.preview
            onTapped: rb.clicked()
        }
    }
}
