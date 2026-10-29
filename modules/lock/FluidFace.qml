//  VELVET  ·  modules/lock/FluidFace.qml
//  The fluid lock's face — everything the lock shows, as one item.
//  FluidLock.qml puts it on every screen's lock surface; the settings
//  put it in a live PREVIEW (preview: true), so what you pick there is
//  exactly what the lock will look like. See FluidLock.qml for the
//  choreography notes.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import "glyphpaths.js" as GP

Item {
    id: surface

    // PREVIEW: the same face, drawn in the settings (LOCK SCREEN → the live
    // picture) — no keyboard, no PAM, no power buttons, nothing clickable;
    // it plays its entrance whenever it is shown and follows every setting.
    property bool preview: false
    // Locked for real, or showing as a preview.
    readonly property bool live: surface.preview || Locker.locked

    // Never transparent: this colour is the guarantee that something is
    // painted even if every layer above fails to load.
    Rectangle {
        anchors.fill: parent
        color: Colours.paper
    }

    // The fluid lock's own centre scale — its tokens shrink with the screen.
    readonly property real cs: Math.min(1, surface.height / 1440)

    // Its card: 0.7 of the screen tall at 16:9 — LOCK SCREEN → FLUID LOCK →
    // LAYOUT → CARD SIZE and CARD SHAPE make it bigger, smaller, wider.
    readonly property real aspect: {
        switch (Config.lock.fluidShape) {
        case "wider":
            return 2;
        case "ultra":
            return 2.37;
        case "screen":
            return surface.height > 0 ? surface.width / surface.height : 1.778;
        }
        return 1.778;
    }
    readonly property real fullH: Math.min(surface.height * Math.max(0.5, Math.min(0.96, Config.lock.fluidSize)), surface.width * 0.97 / surface.aspect)
    readonly property real fullW: fullH * surface.aspect

    // A new size while the card stands (the settings preview, a changed
    // dial) is taken at once — never in the middle of an entrance or exit.
    readonly property bool moving: initAnim.running || initZoom.running || initDrop.running || initFade.running || initFlip.running || initVortex.running || initGlitch.running || initShutter.running
    function refit(): void {
        if (!surface.entrancePlayed || surface.moving || lockContent.scale !== 1)
            return;
        lockContent.w = surface.fullW;
        lockContent.h = surface.fullH;
    }
    onFullWChanged: surface.refit()
    onFullHChanged: surface.refit()

    // ══════════════════════════════════════════════ MOTION & LIGHT
    // LOCK SCREEN → FLUID LOCK → MOTION & LIGHT. The card leans a little
    // towards the pointer and the side columns float a step in front of it
    // (DEPTH), a soft light follows the pointer across the card (POINTER
    // LIGHT), the module cards arrive one after another, the clock's digits
    // roll, and slow colour drifts behind the card (AURORA). The wallpaper
    // itself never moves: on unlock it hands over to the desktop pixel for
    // pixel.
    readonly property real depth: Math.max(0, Math.min(1, Config.lock.fluidDepth))
    property real pointerX: -1
    property real pointerY: -1
    // a lock appearing under a resting pointer has not been pointed at yet
    property bool pointerMoved: false
    readonly property bool settled: surface.entrancePlayed && !surface.moving && !surface.ambient
    readonly property bool leaning: surface.depth > 0 && surface.pointerMoved && surface.settled
    readonly property bool lit: Config.lock.fluidGlow && surface.pointerMoved && surface.settled

    HoverHandler {
        id: pointerWatch

        onPointChanged: {
            const p = pointerWatch.point.position;
            if (Math.abs(p.x - surface.pointerX) < 0.5 && Math.abs(p.y - surface.pointerY) < 0.5)
                return;
            if (surface.pointerX >= 0)
                surface.pointerMoved = true;
            surface.pointerX = p.x;
            surface.pointerY = p.y;
        }
    }

    // -1 … 1 across the screen, sprung so the card follows like a weight
    Spring {
        id: leanX

        to: surface.leaning ? Math.max(-1, Math.min(1, surface.pointerX / Math.max(1, surface.width) * 2 - 1)) : 0
        spring: 2.2
        damping: 0.42
        epsilon: 0.002
    }
    Spring {
        id: leanY

        to: surface.leaning ? Math.max(-1, Math.min(1, surface.pointerY / Math.max(1, surface.height) * 2 - 1)) : 0
        spring: 2.2
        damping: 0.42
        epsilon: 0.002
    }
    // the light's own spot, in screen pixels — quicker than the lean
    Spring {
        id: lightX

        to: surface.pointerX
        spring: 5
        damping: 0.5
        epsilon: 0.5
    }
    Spring {
        id: lightY

        to: surface.pointerY
        spring: 5
        damping: 0.5
        epsilon: 0.5
    }

    // CARDS ONE BY ONE: hidden the moment an entrance starts, then sent in
    // as soon as the card's inside begins to show (every entrance style
    // gets there at its own time).
    signal cardsReset
    signal cardsIn
    property bool staggerArmed: false

    Connections {
        target: content

        function onOpacityChanged(): void {
            if (surface.staggerArmed && content.opacity > 0.05) {
                surface.staggerArmed = false;
                surface.cardsIn();
            }
        }
    }

    // The small square the card grows from: the lock icon (extraLarge
    // × scale 4 = 112px) plus its padding.large × 4.
    readonly property real startSize: 112 * surface.cs + 64

    // The centre profile picture — a circle that wears your ~/.face
    // photo, masked by the glyph. Smaller than the fluid lock's original
    // so the card keeps air between the clock and the password pill.
    // A dial clock is tall already — the photo steps back a little.
    // LOCK SCREEN → FLUID LOCK → THE CENTRE → PHOTO: large, medium, small.
    readonly property real avatarSize: 240 * surface.cs * (surface.dialClock ? 0.72 : 1) * (({
                medium: 0.7,
                small: 0.47
            })[Config.lock.fluidAvatar] ?? 1)

    // The hour as the clock shows it. Qt only counts to twelve when the
    // SAME format carries the AM/PM marker — "hh" alone is 0–23, which
    // put "23" next to a "PM" pill.
    readonly property string hourText: Config.bar.clock.format24h ? Qt.formatDateTime(clock.date, "HH") : Qt.formatDateTime(clock.date, "hh AP").split(" ")[0]

    // The power buttons' words, and what the lock says once the password
    // was right and the machine is on its way.
    readonly property var actionWords: ({
            poweroff: "power off",
            reboot: "restart",
            logout: "log out"
        })
    readonly property string actionNote: ({
            "POWERING OFF": "Powering off…",
            "RESTARTING": "Restarting…",
            "LOGGING OUT": "Logging out…"
        })[Locker.message] ?? ""

    // How big the inside of the card is drawn. The fluid lock's tokens are made
    // for 1440 px tall screens and never grow past them; AUTO lets the
    // cards, words and buttons grow with a taller screen (1800 → ×1.25),
    // a number fixes it.
    readonly property real ui: {
        const v = parseFloat(Config.lock.scale);
        if (!isNaN(v) && v > 0)
            return Math.max(0.7, Math.min(1.6, v));
        return Math.max(1, Math.min(1.35, surface.height / 1440));
    }

    // ── AMBIENT (LOCK SCREEN → CLOCK & SOUND → AMBIENT AFTER): after a
    // while without a key or a mouse move the lock steps back — the cards,
    // the photo and the password pill fade, the glass lifts, the wallpaper
    // dims, and the clock, the lyric and the visualizer are left. Any key
    // or movement brings everything back at once; typing works right away.
    property bool ambient: false
    readonly property real awake: surface.ambient ? 0 : 1
    readonly property int ambientAfter: Math.max(0, parseInt(Config.lock.ambientAfter) || 0)

    // Counting down only on a real lock with AMBIENT on. The timer is
    // driven by hand (restart on every wake), never by a running binding.
    readonly property bool idleArmed: surface.ambientAfter > 0 && !surface.preview && Locker.locked

    onIdleArmedChanged: {
        if (surface.idleArmed)
            idleTimer.restart();
        else
            idleTimer.stop();
    }

    function wake(): void {
        if (surface.ambient)
            surface.ambient = false;
        if (surface.idleArmed)
            idleTimer.restart();
    }

    Timer {
        id: idleTimer

        interval: Math.max(5, surface.ambientAfter) * 1000
        onTriggered: {
            // Not while you are in the middle of something.
            if (input.text.length === 0 && surface.pendingAction === "" && !Locker.busy)
                surface.ambient = true;
        }
    }

    Connections {
        target: Locker

        function onLockedChanged(): void {
            surface.ambient = false;
        }

        function onFailedChanged(): void {
            surface.wake();
        }

        function onBusyChanged(): void {
            surface.wake();
        }
    }

    // Every move of the pointer counts — over the cards too (a HoverHandler
    // only watches, it takes nothing from the buttons underneath).
    HoverHandler {
        enabled: !surface.preview
        onPointChanged: surface.wake()
    }

    // LOCK SCREEN → CLOCK & SOUND: the clock's size and face.
    readonly property real clockPx: 224 * surface.cs * Math.max(0.5, Math.min(1.4, Config.lock.clockScale))
    // …but the digits never outgrow the centre stage: at a large CLOCK SIZE
    // on a narrow screen they ran into the side columns. Measured at the full
    // size (so the fit cannot feed back into the measurement), then shrunk
    // to the stage — never grown.
    readonly property real clockFit: {
        const natural = hourMetrics.advanceWidth + minuteMetrics.advanceWidth + centerCol.width * 0.02;
        return natural > 0 ? Math.min(1, (centerCol.width - 16 * surface.cs) / natural) : 1;
    }

    TextMetrics {
        id: hourMetrics

        font.family: surface.clockFamily
        font.weight: Config.lock.clockFace === "display" ? Font.Black : Font.Light
        font.pixelSize: surface.clockPx
        text: surface.hourText
    }

    TextMetrics {
        id: minuteMetrics

        font.family: surface.clockFamily
        font.weight: Config.lock.clockFace === "display" ? Font.Black : Font.Light
        font.pixelSize: surface.clockPx * (Config.bar.clock.format24h ? 1 : 0.545)
        text: "00"
    }

    // The card in a column that takes the room left over: the one that can
    // use it (the notification dock, the music, the forecast), else the last.
    // The last card used to stretch whatever it was — four power buttons in a
    // card as tall as the dock.
    // A card that is resting (no song, no notifications, and a SLIM or
    // HIDE idle look) never takes it — the next one does, and a column with
    // none of the three keeps the old way (its last card). FILL THE COLUMNS
    // off: nobody stretches, every card keeps its own height.
    function stretchIndex(zone: string): int {
        if (!Config.lock.fluidFill)
            return -1;
        const list = LockLayout.list(zone);
        let any = false;
        for (const id of ["notifs", "media", "weather"]) {
            const i = list.indexOf(id);
            if (i < 0)
                continue;
            any = true;
            if (!surface.restingMods[id])
                return i;
        }
        return any ? -1 : list.length - 1;
    }

    // Which modules rest right now — told by their tiles (ModuleInTile).
    property var restingMods: ({})
    function setResting(id: string, on: bool): void {
        if (!!surface.restingMods[id] === on)
            return;
        const next = Object.assign({}, surface.restingMods);
        next[id] = on;
        surface.restingMods = next;
    }

    // Where a side column sits when it is shorter than the tallest one: at
    // its top, middle or bottom (LOCK SCREEN → FLUID LOCK → LAYOUT → COLUMNS
    // SIT). A column that fills IS the tallest, so for it all three agree.
    function columnY(h: real): real {
        const top = (tileRow.height - tileRow.colH) / 2;
        if (Config.lock.fluidAlign === "top")
            return top;
        if (Config.lock.fluidAlign === "bottom")
            return top + tileRow.colH - h;
        return (tileRow.height - h) / 2;
    }
    readonly property bool dotClock: Config.lock.clockFace === "dots" && !surface.dialClock
    // CLOCK SHAPE (or the ANALOG face): the clock moves into a dial.
    readonly property bool dialClock: Config.lock.clockFace === "analog" || (Config.lock.clockShape !== "" && Config.lock.clockShape !== "none" && Config.lock.clockShape !== "line")
    readonly property string clockFamily: (Config.lock.clockFont ?? "") !== "" ? Config.lock.clockFont : (Config.lock.clockFace === "mono" ? Appearance.fontFamily.mono : (Config.lock.clockFace === "display" ? Appearance.fontFamily.display : Appearance.fontFamily.body))

    // Which power action the password is currently being asked for.
    // "" = plain unlock, "poweroff" / "reboot" = guarded buttons.
    property string pendingAction: ""

    // The fluid lock's peek: the pill's left icon turns the glyphs into the
    // letters you actually typed.
    property bool showPassword: false

    // The profile picture: probe ~/.face once, so a missing picture
    // never produces a QML warning — the person icon simply stays.
    property bool faceExists: false
    readonly property string faceUrl: `file://${Quickshell.env("HOME") ?? ""}/.face`

    FileView {
        id: faceProbe

        path: surface.faceUrl.replace("file://", "")
        printErrors: false

        onLoaded: surface.faceExists = true
        onLoadFailed: surface.faceExists = false
    }

    // The shape deck: every keystroke plants the next shape of a
    // shuffled pack, so the password never repeats a pattern. The deck
    // is refilled imperatively as you type; the lookup itself never
    // writes, so the dot bindings cannot loop.
    property var _queue: []

    function fillDeck(): void {
        const shapes = [0, 1, 2, 3, 4, 5, 6];
        for (let k = shapes.length - 1; k > 0; k--) {
            const j = Math.floor(Math.random() * (k + 1));
            const t = shapes[k];
            shapes[k] = shapes[j];
            shapes[j] = t;
        }
        surface._queue = surface._queue.concat(shapes);
    }

    function shapeAt(i: int): int {
        if (Config.lock.passwordShapes === "circles")
            return 0;
        return i < surface._queue.length ? surface._queue[i] : 0;
    }

    // A fresh deck for every lock, so no session repeats a pattern.
    Connections {
        target: Locker
        function onLockedChanged(): void {
            if (Locker.locked)
                surface._queue = [];
        }
    }

    // Enter: unlock — or, with a power button armed, prove it is you and
    // THEN power off / restart / log out. The password is checked by PAM
    // either way; an armed button never acts on an empty or wrong one.
    function attempt(): void {
        if (surface.preview)
            return;
        Locker.submit(input.text, surface.pendingAction);
        input.text = "";
        surface.showPassword = false;
    }

    // ═══════════════════════════════ the entrance styles — LOCK SCREEN →
    // ENTRANCE. MORPH is its own choreography (the square spins
    // upright and grows); ZOOM scales the grown card in; DROP lets it
    // fall from above; FADE is a plain crossfade; FLIP turns the card
    // over like a menu door; VORTEX spirals it in on a shockwave ring;
    // GLITCH slams it in with a scanline and chromatic ghosts;
    // SHUTTER opens it from a centre seam like blast doors. Each
    // style gets a matching exit on unlock.
    readonly property real ms: Math.max(0.25, Config.lock.animationScale)

    // The style, normalised — anything this file does not know falls
    // back to the fluid lock's own choreography instead of failing silently.
    readonly property string style: ["morph", "zoom", "drop", "fade", "flip", "vortex", "glitch", "shutter"].indexOf(Config.lock.animation) >= 0 ? Config.lock.animation : "morph"

    // The profile picture wears the lock's own background glyph when
    // hovered — the whole screen speaks one shape language. With the
    // background shape OFF there is nothing to echo, so the avatar
    // falls back to its random face-friendly pool.
    readonly property int avatarHoverKind: {
        const k = GP.kindOfName(Config.lock.backgroundShape);
        return k >= 0 ? k : -2;
    }

    readonly property var ent: {
        switch (surface.style) {
        case "zoom":
            return { grow: false, scale: 0.78, rot: 0, drop: 0, rotY: 0, squash: 1 };
        case "drop":
            return { grow: false, scale: 1, rot: 0, drop: -140 * surface.cs, rotY: 0, squash: 1 };
        case "fade":
            return { grow: false, scale: 1, rot: 0, drop: 0, rotY: 0, squash: 1 };
        case "flip":
            return { grow: false, scale: 0.94, rot: 0, drop: 0, rotY: -95, squash: 1 };
        case "vortex":
            return { grow: false, scale: 0.06, rot: -330, drop: 150 * surface.cs, rotY: 0, squash: 1 };
        case "glitch":
            return { grow: false, scale: 1, rot: 0, drop: 0, rotY: 0, squash: 1 };
        case "shutter":
            return { grow: false, scale: 1, rot: 0, drop: 0, rotY: 0, squash: 0.05 };
        default:
            return { grow: true, scale: 0, rot: 180, drop: 0, rotY: 0, squash: 1 };
        }
    }

    property bool entrancePlayed: false

    // The surface is born per lock at locked=true — the lockedChanged
    // signal has come and gone by then, so the first entrance is
    // picked up when the surface gets its first real size (or, on a
    // re-lock of an already-born surface, right here at birth).
    Component.onCompleted: {
        if (surface.idleArmed)
            idleTimer.restart();
        if (surface.preview)
            Spectrum.lockPreview = true;
        if (surface.width > 0 && surface.height > 0 && surface.live && !surface.entrancePlayed)
            surface.restartEntrance();
    }
    Component.onDestruction: {
        if (surface.preview)
            Spectrum.lockPreview = false;
    }

    // The lock surface hands the face its width and its height one after
    // the other — whichever lands second must start the entrance, or the
    // lock shows nothing but its paper.
    function sized(): void {
        if (surface.width > 0 && surface.height > 0 && surface.live && !surface.entrancePlayed)
            surface.restartEntrance();
    }

    onWidthChanged: surface.sized()
    onHeightChanged: surface.sized()

    // The preview replays the entrance whenever it comes into view and
    // whenever another entrance is picked.
    onVisibleChanged: {
        if (surface.preview && surface.visible)
            surface.restartEntrance();
    }
    onStyleChanged: {
        if (surface.preview)
            surface.restartEntrance();
    }

    // The exits hand the screen back — only a real lock has one to hand.
    function exitDone(): void {
        if (!surface.preview)
            Locker.exitDone();
    }

    // Put every moving part back at the style's start state, THEN run
    // the choreography. The exit left the card invisible — a re-lock
    // must not inherit that.
    function prepareEntrance(): void {
        const a = surface.ent;
        lockContent.opacity = 1;
        lockContent.w = a.grow ? surface.startSize : surface.fullW;
        lockContent.h = a.grow ? surface.startSize : surface.fullH;
        lockContent.radius = a.grow ? surface.startSize / 4 : 42;
        lockContent.scale = a.scale;
        lockContent.rotation = a.rot;
        dropShift.y = a.drop;
        cardRotY.angle = a.rotY;
        shutterScale.xScale = a.squash;
        glitchShift.x = 0;
        glitchShift.y = 0;
        ghostA.flick = 0;
        ghostA.dx = 0;
        ghostB.flick = 0;
        ghostB.dx = 0;
        vortexRing.opacity = 0;
        vortexRing.scale = 0.45;
        seam.opacity = 0;
        scanline.opacity = 0;
        scanline.y = -60 * surface.cs;
        content.opacity = 0;
        content.scale = a.grow ? 0 : 1;
        lockIcon.opacity = 1;
        lockIcon.rotation = a.grow ? 180 : 0;
        backdrop.progress = 1;
        background.opacity = 0;
    }

    function restartEntrance(): void {
        if (surface.width <= 0 || surface.height <= 0)
            return;
        surface.entrancePlayed = true;
        surface.prepareEntrance();
        if (Config.lock.fluidStagger) {
            surface.cardsReset();
            surface.staggerArmed = true;
        }
        switch (surface.style) {
        case "zoom":
            initZoom.restart();
            break;
        case "drop":
            initDrop.restart();
            break;
        case "fade":
            initFade.restart();
            break;
        case "flip":
            initFlip.restart();
            break;
        case "vortex":
            initVortex.restart();
            break;
        case "glitch":
            initGlitch.restart();
            break;
        case "shutter":
            initShutter.restart();
            break;
        default:
            initAnim.restart();
            break;
        }
    }

    function restartExit(): void {
        if (surface.width <= 0 || surface.height <= 0)
            return;
        surface.entrancePlayed = false;
        switch (surface.style) {
        case "zoom":
            unlockZoom.restart();
            break;
        case "drop":
            unlockDrop.restart();
            break;
        case "fade":
            unlockFade.restart();
            break;
        case "flip":
            unlockFlip.restart();
            break;
        case "vortex":
            unlockVortex.restart();
            break;
        case "glitch":
            unlockGlitch.restart();
            break;
        case "shutter":
            unlockShutter.restart();
            break;
        default:
            unlockAnim.restart();
            break;
        }
    }

    // ═══════════════════════════════════════════════════ the background
    // The fluid lock's stage: the whole wallpaper, blurred (blur 1, max 64),
    // fading in with the entrance — and on unlock handing over to the
    // desktop's own wallpaper layer, pixel-identical.
    Item {
        id: background

        anchors.fill: parent
        opacity: 0

        ShapeBackdrop {
            id: backdrop

            anchors.fill: parent
            progress: 1
        }

        // Depth for the card: the glass darkens towards the bottom —
        // so light wallpapers cannot eat the card's edge. The shade
        // lifts with the glyph's opening, so the reveal is the bare
        // wallpaper.
        Rectangle {
            anchors.fill: parent
            opacity: backdrop.progress
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.6
                    color: Colours.alpha(Colours.paper, 0.08)
                }
                GradientStop {
                    position: 1.0
                    color: Colours.alpha(Colours.paper, 0.28)
                }
            }
        }
    }



    // Ambient mode dims the wallpaper a little further, so the clock and
    // the lyric carry the screen on their own.
    Rectangle {
        anchors.fill: parent
        color: Colours.paper
        opacity: surface.ambient ? 0.38 * background.opacity : 0

        Behavior on opacity {
            NumberAnimation {
                duration: surface.ambient ? 1600 : 260
                easing.type: Easing.InOutQuad
            }
        }
    }

    // ═════════════════════════════════════════════════════════ AURORA
    // Three soft lights in the shell's own colours drift behind the card on
    // long, unhurried paths — and shift a little against the pointer, so the
    // card seems to stand in front of them.
    Item {
        id: aurora

        readonly property real blob: Math.min(surface.width, surface.height) * 0.95

        anchors.fill: parent
        opacity: (Config.lock.fluidAurora && !surface.ambient ? 1 : 0) * background.opacity
        visible: aurora.opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: 900
                easing.type: Easing.InOutQuad
            }
        }

        transform: Translate {
            x: -leanX.value * 28 * surface.depth
            y: -leanY.value * 18 * surface.depth
        }

        Repeater {
            model: [
                {
                    tone: 0,
                    fx: 0.18,
                    fy: 0.22,
                    ax: 0.22,
                    ay: 0.16,
                    period: 23000
                },
                {
                    tone: 1,
                    fx: 0.72,
                    fy: 0.68,
                    ax: 0.18,
                    ay: 0.2,
                    period: 31000
                },
                {
                    tone: 2,
                    fx: 0.55,
                    fy: 0.15,
                    ax: 0.24,
                    ay: 0.14,
                    period: 37000
                }
            ]

            GE.RadialGradient {
                id: blob

                required property var modelData
                // 0 → 1 → 0 along the path, its own pace
                property real t: 0

                width: aurora.blob
                height: aurora.blob
                x: surface.width * (blob.modelData.fx + blob.modelData.ax * Math.sin(blob.t * Math.PI * 2)) - width / 2
                y: surface.height * (blob.modelData.fy + blob.modelData.ay * Math.cos(blob.t * Math.PI * 2 * 0.8)) - height / 2
                horizontalRadius: width / 2
                verticalRadius: height / 2
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: [Colours.alpha(Colours.accent, 0.32), Colours.alpha(Colours.accentAlt, 0.28), Colours.alpha(Colours.mix(Colours.accent, Colours.accentAlt, 0.5), 0.22)][blob.modelData.tone]
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }

                NumberAnimation on t {
                    running: aurora.visible
                    loops: Animation.Infinite
                    from: 0
                    to: 1
                    duration: blob.modelData.period
                }
            }
        }
    }

    // ═════════════════════════════════════════ the music along an edge
    // LOCK SCREEN → CLOCK & SOUND → CAVA VISUALIZER: drawn from the
    // shell's own spectrum, standing exactly on the chosen edge, under
    // the card. It comes and goes with the background.
    SpectrumEdge {
        anchors.fill: parent
        running: Config.lock.visualizer && surface.live
        edge: Config.lock.visualizerEdge
        style: Config.lock.visualizerStyle
        reach: (lockVisualizerSide ? surface.width : surface.height) * Math.max(0.03, Config.lock.visualizerReach)
        strength: 0.92 * background.opacity
        barPitch: Config.lock.visualizerDensity === "fine" ? 10 : (Config.lock.visualizerDensity === "wide" ? 24 : 16)

        readonly property bool lockVisualizerSide: edge === "left" || edge === "right"
    }

    // ═══════════════════════════ the styles' props — every choreography
    // needs its own moving part, and all of them live here so the
    // entrance/exit engines can reset them in one place: the DROP
    // slide, the FLIP door (a rotation around the vertical axis),
    // the SHUTTER squash (horizontal, around the centre), the GLITCH
    // jitter, its two chromatic ghosts, the VORTEX shockwave ring, the
    // SHUTTER seam and the GLITCH scanline.
    Rectangle {
        id: vortexRing

        anchors.centerIn: parent
        width: Math.max(surface.fullW, surface.fullH) * 1.12
        height: vortexRing.width
        radius: vortexRing.width / 2
        color: "transparent"
        border.width: 3
        border.color: Colours.alpha(Colours.accent, 0.75)
        opacity: 0
        scale: 0.45
        visible: surface.style === "vortex"
        antialiasing: true
    }

    Rectangle {
        id: ghostA

        anchors.centerIn: lockContent
        width: lockContent.width
        height: lockContent.height
        radius: lockContent.radius
        color: Colours.alpha(Colours.accent, ghostA.flick)
        property real flick: 0
        property real dx: 0
        transform: Translate {
            x: ghostA.dx
        }
        visible: surface.style === "glitch"
        antialiasing: true
    }

    Rectangle {
        id: ghostB

        anchors.centerIn: lockContent
        width: lockContent.width
        height: lockContent.height
        radius: lockContent.radius
        color: Colours.alpha(Colours.danger, ghostB.flick)
        property real flick: 0
        property real dx: 0
        transform: Translate {
            x: ghostB.dx
        }
        visible: surface.style === "glitch"
        antialiasing: true
    }

    Rectangle {
        id: seam

        anchors.centerIn: lockContent
        width: 3
        height: lockContent.height
        color: Colours.accent
        opacity: 0
        visible: surface.style === "shutter"
        antialiasing: true
    }

    Rectangle {
        id: scanline

        anchors.horizontalCenter: parent.horizontalCenter
        y: -60 * surface.cs
        width: surface.width
        height: 3
        color: Colours.accent
        opacity: 0
        visible: surface.style === "glitch"
        antialiasing: true
    }

    // ═══════════════════════════════════════════════ the morphing card
    // The fluid lock's own card: the small square with the lock mark that
    // grows to full size while turning upright — and shrinks back
    // when the password was right.
    Item {
        id: lockContent

        anchors.centerIn: parent
        width: lockContent.w
        height: lockContent.h

        property real w: surface.startSize
        property real h: surface.startSize
        property real radius: surface.startSize / 4
        scale: 0
        rotation: 180
        opacity: 1

        // The DROP entrance falls in from above, FLIP turns the card
        // over, SHUTTER opens it from a centre seam and GLITCH jitters
        // it — four transforms, one list, every other choreography
        // leaves each of them at its neutral value.
        transform: [
            Translate {
                id: dropShift

                y: 0
            },
            Rotation {
                id: cardRotY

                origin.x: lockContent.width / 2
                origin.y: lockContent.height / 2
                axis: Qt.vector3d(0, 1, 0)
                angle: 0
            },
            Scale {
                id: shutterScale

                origin.x: lockContent.width / 2
                origin.y: lockContent.height / 2
                xScale: 1
                yScale: 1
            },
            Translate {
                id: glitchShift

                x: 0
                y: 0
            },
            // DEPTH: the card leans towards the pointer
            Rotation {
                origin.x: lockContent.width / 2
                origin.y: lockContent.height / 2
                axis: Qt.vector3d(0, 1, 0)
                angle: leanX.value * 3.2 * surface.depth
            },
            Rotation {
                origin.x: lockContent.width / 2
                origin.y: lockContent.height / 2
                axis: Qt.vector3d(1, 0, 0)
                angle: -leanY.value * 2.4 * surface.depth
            }
        ]

        Rectangle {
            id: lockBg

            opacity: surface.awake

            Behavior on opacity {
                NumberAnimation {
                    duration: surface.ambient ? 1400 : 260
                    easing.type: Easing.InOutQuad
                }
            }

            anchors.fill: parent
            radius: lockContent.radius
            // LOCK SCREEN → FLUID LOCK → CARDS → BIG CARD: 0 lets the
            // modules float on the wallpaper.
            color: Colours.alpha(Colours.surface, Math.max(0, Math.min(1, Config.lock.fluidPanel)))
            antialiasing: true

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 48
                shadowColor: Qt.rgba(0, 0, 0, 0.55)
                shadowBlur: 0.7
                shadowVerticalOffset: 8
                // Frosted glass: the card blurs whatever the wallpaper
                // shows behind it, so the modules stay readable.
                blurEnabled: true
                blur: 0.65
                blurMultiplier: 1
            }
        }

        // POINTER LIGHT: a soft light under the pointer, inside the card's
        // rounded shape.
        Item {
            id: lightClip

            anchors.fill: parent
            opacity: surface.lit ? 1 : 0
            visible: lightClip.opacity > 0.01
            layer.enabled: lightClip.visible
            layer.effect: GE.OpacityMask {
                maskSource: Rectangle {
                    width: lightClip.width
                    height: lightClip.height
                    radius: lockContent.radius
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.OutQuad
                }
            }

            GE.RadialGradient {
                readonly property real r: Math.max(lockContent.width, lockContent.height) * 0.42

                width: r * 2
                height: r * 2
                x: lightX.value - (surface.width - lockContent.width) / 2 - r
                y: lightY.value - (surface.height - lockContent.height) / 2 - r
                horizontalRadius: r
                verticalRadius: r
                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: Colours.alpha(Colours.accent, 0.26)
                    }
                    GradientStop {
                        position: 0.35
                        color: Colours.alpha(Colours.accent, 0.09)
                    }
                    GradientStop {
                        position: 1
                        color: "transparent"
                    }
                }
            }
        }

        // The lock mark the card grows out of — and returns to.
        Icon {
            id: lockIcon

            anchors.centerIn: parent
            name: "lock"
            color: Colours.accent
            font.pixelSize: 112 * surface.cs
            rotation: 180
            opacity: 1
        }
        // ════════════════════════════════════════════════ the card's inside
        // The fluid lock's content is a CHILD of the growing card, exactly like
        // the lock surface: it keeps its full size, fades in over the square
        // as the card grows, and rides the card's scale and spin through
        // the whole entrance.
        Item {
            id: content

            anchors.centerIn: parent
            width: surface.fullW - 64
            height: surface.fullH - 64
            opacity: 0
            // The fluid lock's content starts collapsed — it settles in at
            // full size inside the grown card, exactly like its own.
            scale: 0

            Row {
                id: tileRow

                // LOCK SCREEN → SIZE: the inside is laid out 1/ui as large
                // and drawn ui times bigger — every card, word and button
                // grows together and the proportions stay its own.
                anchors.centerIn: parent
                width: parent.width / surface.ui
                height: parent.height / surface.ui
                // GAP: between the cards in a column, and twice that
                // between the columns and the centre.
                readonly property real gap: Math.max(4, Math.min(48, Config.lock.fluidGap))
                spacing: tileRow.gap * 2

                // The fluid lock's centerScale: when the columns would outgrow
                // the card (small screens, full modules), the whole inside
                // shrinks uniformly instead of spilling past the frame.
                readonly property real tallest: Math.max(leftCol.height, centerCol.height, rightCol.height)
                // Both side columns share one height — the taller of their
                // contents and the centre stage — so their tops and bottoms
                // line up and each last card stretches into what is left.
                readonly property real colH: Math.max(centerCol.height, leftCol.implicitHeight, rightCol.implicitHeight)
                scale: surface.ui * Math.min(1, tileRow.height / Math.max(1, tileRow.tallest))

                transformOrigin: Item.Center

                // The fluid lock's tiling: the side columns span the full
                // height of the centre stage (its ColumnLayouts fill
                // the row), and the last module of each column
                // stretches into the leftover — media and the
                // notification dock in its own layout.
                ColumnLayout {
                    id: leftCol

                    opacity: surface.awake

                    Behavior on opacity {
                        NumberAnimation {
                            duration: surface.ambient ? 1400 : 260
                            easing.type: Easing.InOutQuad
                        }
                    }

                    width: (tileRow.width - centerCol.width - tileRow.spacing * 2) / 2
                    // a column with a card that stretches is as tall as the
                    // row's tallest; one without keeps its own height
                    height: surface.stretchIndex("left") >= 0 ? tileRow.colH : leftCol.implicitHeight
                    y: surface.columnY(leftCol.height)
                    spacing: tileRow.gap
                    // DEPTH: the columns float a step in front of the card
                    transform: Translate {
                        x: leanX.value * 12 * surface.depth
                        y: leanY.value * 7 * surface.depth
                    }

                    Repeater {
                        model: LockLayout.list("left")

                        ModuleInTile {
                            required property var modelData

                            modId: modelData
                            face: surface
                            zone: "left"
                            zoneW: leftCol.width
                            Layout.fillWidth: true
                            Layout.fillHeight: index === surface.stretchIndex("left")
                        }
                    }
                }

                // ── the centre: the fluid lock's fixed stage, not a module
                // zone — clock, date, profile, password, state.
                Column {
                    id: centerCol

                    // CENTRE WIDTH (LOCK SCREEN → FLUID LOCK → LAYOUT)
                    width: Math.min(600 * surface.cs, tileRow.width * 0.4) * Math.max(0.7, Math.min(1.3, Config.lock.fluidCentre))
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 20

                    // ── the clock: hours in the primary, minutes in the
                    // secondary, its scale-7 headline (224px); in twelve-
                    // hour mode the minutes shrink and AM/PM rides a pill
                    // underneath.
                    SystemClock {
                        id: clock
                        precision: SystemClock.Seconds
                    }

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Ambient mode: the clock steps forward a little.
                        scale: surface.ambient ? 1.12 : 1
                        transformOrigin: Item.Bottom

                        Behavior on scale {
                            NumberAnimation {
                                duration: 900
                                easing.type: Easing.InOutQuad
                            }
                        }
                        // Type carries its own air below the digits; drawn
                        // faces do not, so the AM/PM pill gets some.
                        spacing: surface.dotClock || surface.dialClock ? 16 * surface.cs : 0

                        // CLOCK SHAPE / ANALOG: the dial.
                        ClockDial {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: surface.dialClock
                            now: clock.date
                            size: surface.clockPx * 1.5
                            shape: Config.lock.clockShape === "none" ? "circle" : Config.lock.clockShape
                            analog: Config.lock.clockFace === "analog"
                            h24: Config.bar.clock.format24h
                            face: Config.lock.clockFace
                            family: surface.clockFamily
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !surface.dialClock
                            spacing: centerCol.width * 0.02

                            RollText {
                                visible: !surface.dotClock
                                text: surface.hourText
                                color: Colours.accent
                                px: surface.clockPx * surface.clockFit
                                family: surface.clockFamily
                                heavy: Config.lock.clockFace === "display"
                            }

                            RollText {
                                visible: !surface.dotClock
                                text: Qt.formatDateTime(clock.date, "mm")
                                color: Colours.accentAlt
                                px: surface.clockPx * surface.clockFit * (Config.bar.clock.format24h ? 1 : 0.545)
                                family: surface.clockFamily
                                heavy: Config.lock.clockFace === "display"
                            }

                            // CLOCK FACE → DOTS: the same two colours,
                            // drawn as a dot matrix.
                            DotText {
                                visible: surface.dotClock
                                text: surface.hourText
                                color: Colours.accent
                                pixelSize: surface.clockPx * surface.clockFit * 0.62
                            }

                            DotText {
                                anchors.bottom: parent.bottom
                                // a digit's width of air, so 07 28 never reads as 0728
                                leftPadding: pitch * 2
                                visible: surface.dotClock
                                text: Qt.formatDateTime(clock.date, "mm")
                                color: Colours.accentAlt
                                pixelSize: surface.clockPx * surface.clockFit * 0.62 * (Config.bar.clock.format24h ? 1 : 0.545)
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !Config.bar.clock.format24h && Config.lock.clockFace !== "analog" && Config.lock.fluidAmPm
                            width: amPm.implicitWidth + 32
                            height: amPm.implicitHeight + 28
                            radius: 16
                            color: Colours.alpha(Colours.surfaceHigh, 0.85)
                            antialiasing: true

                            P5Text {
                                id: amPm

                                anchors.centerIn: parent
                                text: Qt.formatDateTime(clock.date, "AP").toUpperCase()
                                color: Colours.ink
                                font.pixelSize: 48 * surface.cs
                                font.weight: Font.Medium
                            }
                        }
                    }

                    // DATE (LOCK SCREEN → FLUID LOCK → THE CENTRE)
                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: Config.lock.fluidDate !== "off"
                        text: Qt.formatDateTime(clock.date, ({
                                full: "dddd, d MMMM yyyy",
                                short: "ddd • dd.MM"
                            })[Config.lock.fluidDate] ?? "dddd • d MMM").toUpperCase()
                        color: Colours.ink
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    // ── what the song is singing right now (LOCK SCREEN →
                    // CLOCK & SOUND → LYRICS), one line that slides in as
                    // the next one starts. In ambient mode it takes the stage.
                    Item {
                        id: lyric

                        readonly property bool shown: Config.lock.lyrics && (Lyrics.active || surface.preview) && Lyrics.hasSynced && Lyrics.current !== ""

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: centerCol.width
                        height: lyric.shown ? lyricText.implicitHeight * lyric.scale : 0
                        visible: lyric.height > 0.5
                        scale: surface.ambient ? 1.25 : 1
                        transformOrigin: Item.Top

                        Behavior on height {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: 900
                                easing.type: Easing.InOutQuad
                            }
                        }

                        P5Text {
                            id: lyricText

                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: `♪  ${Lyrics.current}`
                            color: Colours.accent
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            transform: Translate {
                                id: lyricShift
                            }

                            onTextChanged: lyricSwap.restart()
                        }

                        ParallelAnimation {
                            id: lyricSwap

                            NumberAnimation {
                                target: lyricText
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 320
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: lyricShift
                                property: "y"
                                from: 10
                                to: 0
                                duration: 380
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // ── the profile picture: a circle wearing your
                    // ~/.face photo when it exists, the person icon
                    // otherwise. On hover it morphs into the SAME glyph
                    // the lock's background wears (LOCK SCREEN →
                    // BACKGROUND SHAPE) — the whole screen speaks one
                    // shape language. With the background shape OFF it
                    // falls back to its random face-friendly pool,
                    // diamond and rect.
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: surface.avatarSize
                        height: surface.avatarSize
                        visible: Config.lock.fluidAvatar !== "off"

                        opacity: surface.awake

                        Behavior on opacity {
                            NumberAnimation {
                                duration: surface.ambient ? 1400 : 260
                                easing.type: Easing.InOutQuad
                            }
                        }

                        ShapeBadge {
                            anchors.centerIn: parent
                            size: surface.avatarSize
                            kind: 0
                            hoverKind: surface.avatarHoverKind
                            hoverSet: [4, 8]
                            col: Colours.surfaceHigh
                            icon: "person"
                            iconCol: Colours.alpha(Colours.inkDim, 0.9)
                            iconSize: Math.round(surface.avatarSize * 0.357)
                            text: ""
                            image: Config.lock.avatarFace && surface.faceExists ? surface.faceUrl : ""
                        }
                    }

                    // ── the password pill: its full-radius field with the
                    // state icon on the left, the living shapes in the
                    // middle and the enter button on the right.
                    Rectangle {
                        id: pill

                        opacity: surface.awake

                        Behavior on opacity {
                            NumberAnimation {
                                duration: surface.ambient ? 1400 : 260
                                easing.type: Easing.InOutQuad
                            }
                        }

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 480 * surface.cs
                        height: 52 * surface.cs
                        radius: height / 2
                        color: Colours.alpha(Colours.surfaceHigh, 0.95)
                        antialiasing: true

                        Row {
                            id: mainRow

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            spacing: 8

                            // The fluid lock's state icon: lock in rest,
                            // visibility while peeking, a timer while
                            // checking — and it IS the peek toggle.
                            ShapeBadge {
                                anchors.verticalCenter: parent.verticalCenter
                                size: 34 * surface.cs
                                kind: 0
                                hoverKind: -2
                                col: surface.showPassword ? Colours.alpha(Colours.accent, 0.85) : Colours.alpha(Colours.ink, 0.06)
                                icon: Locker.busy ? "timer" : (surface.showPassword ? "visibility" : "lock")
                                iconCol: surface.showPassword ? Colours.on(Colours.accent) : (Locker.busy ? Colours.warning : Colours.inkDim)
                                iconSize: 17 * surface.cs
                                onClicked: {
                                    if (Config.lock.passwordPeek && input.text.length > 0)
                                        surface.showPassword = !surface.showPassword;
                                }
                            }

                            // ── the field: the fluid lock centres it between
                            // the state icon and the enter button —
                            // placeholder, shapes and the peeked letters
                            // all sit in its middle.
                            Item {
                                id: field

                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.max(60 * surface.cs, mainRow.width - 34 * surface.cs - 36 * surface.cs - 32 * surface.cs)
                                height: 21 * surface.cs
                                clip: true

                                // The placeholder.
                                P5Text {
                                    id: placeholder

                                    anchors.centerIn: parent
                                    visible: input.text.length === 0
                                    width: Math.min(320 * surface.cs, field.width - 8)
                                    text: {
                                        if (surface.actionNote !== "")
                                            return surface.actionNote;
                                        if (surface.pendingAction !== "")
                                            return `Enter password to ${surface.actionWords[surface.pendingAction] ?? "continue"}`;
                                        if (Locker.busy)
                                            return "Checking…";
                                        return "Enter your password";
                                    }
                                    color: surface.pendingAction !== "" ? Colours.warning : (Locker.busy ? Colours.warning : Colours.alpha(Colours.inkDim, 0.8))
                                    font.pixelSize: 14 * Math.max(0.8, surface.cs)
                                    elide: Text.ElideRight
                                }

                                // The material shapes, one per keystroke —
                                // its 1.5× body size, its move: each
                                // planted shape settles into a circle a
                                // beat later. The newest char holds the
                                // right edge; the row clips like its
                                // field does.
                                Item {
                                    id: charSlot

                                    anchors.centerIn: parent
                                    width: Math.min(320 * surface.cs, field.width - 8)
                                    height: 21 * surface.cs
                                    clip: true
                                    visible: input.text.length > 0 && !surface.showPassword

                                    Row {
                                        id: charRow

                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4 * surface.cs

                                        Repeater {
                                            // A fixed deck of slots. The model
                                            // used to be the text length, which
                                            // rebuilt every dot on each
                                            // keystroke: every dot re-popped
                                            // AND every planted shape re-rolled,
                                            // defeating the "never repeat a
                                            // pattern" deck. The slots stay put
                                            // now; each dot captures its shape
                                            // exactly once, when it lights.
                                            model: 24

                                            delegate: Item {
                                                id: g

                                                required property int index

                                                readonly property bool lit: g.index < input.text.length

                                                width: 21 * surface.cs
                                                height: 21 * surface.cs
                                                visible: g.lit
                                                scale: 0
                                                opacity: 0
                                                property color col: Colours.ink
                                                property int dotKind: 0

                                                LockGlyph {
                                                    anchors.centerIn: parent
                                                    kind: g.dotKind
                                                    col: g.col
                                                }

                                                onLitChanged: {
                                                    if (g.lit) {
                                                        // The deck is refilled on text growth,
                                                        // before bindings re-evaluate — safe to
                                                        // read exactly here, once per keystroke.
                                                        g.dotKind = surface.shapeAt(g.index);
                                                        pop.start();
                                                        fade.start();
                                                        circleTimer.start();
                                                    } else {
                                                        pop.stop();
                                                        fade.stop();
                                                        circleTimer.stop();
                                                        g.scale = 0;
                                                        g.opacity = 0;
                                                    }
                                                }

                                                NumberAnimation {
                                                    id: pop

                                                    target: g
                                                    property: "scale"
                                                    to: 1
                                                    duration: 150
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: [0.42, 1.67, 0.21, 0.90]
                                                }
                                                NumberAnimation {
                                                    id: fade

                                                    target: g
                                                    property: "opacity"
                                                    to: 1
                                                    duration: 200
                                                }
                                                Timer {
                                                    id: circleTimer
                                                    interval: 180
                                                    onTriggered: {
                                                        g.dotKind = 0;
                                                        shrink.start();
                                                    }
                                                }
                                                NumberAnimation {
                                                    id: shrink

                                                    target: g
                                                    property: "scale"
                                                    to: 2 / 3
                                                    duration: 150
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: [0.42, 1.67, 0.21, 0.90]
                                                }
                                            }
                                        }

                                        // The caret — right after the newest
                                        // shape.
                                        Rectangle {
                                            id: caret

                                            width: 2
                                            height: 18 * surface.cs
                                            radius: 1
                                            color: Colours.accent
                                            opacity: caret.blinkOn ? 1 : 0

                                            property bool blinkOn: true

                                            Timer {
                                                interval: 500
                                                repeat: true
                                                running: input.activeFocus
                                                onTriggered: caret.blinkOn = !caret.blinkOn
                                            }
                                        }
                                    }
                                }

                                // The fluid lock's peek: with the eye on, the
                                // glyphs give way to the letters
                                // themselves, still centred in the field.
                                P5Text {
                                    anchors.centerIn: parent
                                    visible: surface.showPassword
                                    width: Math.min(320 * surface.cs, field.width - 8)
                                    text: input.text
                                    color: Colours.ink
                                    font.family: Appearance.fontFamily.mono
                                    font.pixelSize: 14 * Math.max(0.8, surface.cs)
                                    tracking: 2
                                    elide: Text.ElideRight
                                }
                            }

                            // The enter button — its living glyph: a quiet
                            // circle in rest, it becomes the arrow the
                            // moment you have typed.
                            ShapeBadge {
                                anchors.verticalCenter: parent.verticalCenter
                                size: 36 * surface.cs
                                // Armed, it is a calm circle wearing the action's icon;
                                // otherwise its arrow the moment you have typed.
                                kind: surface.pendingAction !== "" ? 0 : (input.text.length > 0 ? 1 : 0)
                                hoverKind: -2
                                col: (input.text.length > 0 || surface.pendingAction !== "") ? (surface.pendingAction !== "" ? Colours.warning : Colours.accent) : Colours.alpha(Colours.ink, 0.07)
                                icon: surface.pendingAction === "poweroff" ? "power_settings_new" : (surface.pendingAction === "reboot" ? "restart_alt" : (surface.pendingAction === "logout" ? "logout" : (input.text.length > 0 ? "" : "arrow_forward")))
                                iconCol: surface.pendingAction !== "" ? Colours.paper : Colours.inkDim
                                iconSize: 17 * surface.cs
                                onClicked: surface.attempt()
                            }
                        }

                        TextInput {
                            id: input
                            objectName: "lockInput"

                            anchors.fill: parent
                            opacity: 0
                            focus: !surface.preview
                            enabled: !Locker.busy && !surface.preview
                            echoMode: TextInput.Password

                            onTextChanged: {
                                // Keep the deck ahead of the keystrokes —
                                // outside any binding, so the dots never
                                // write their own source.
                                if (input.text.length > surface._queue.length)
                                    surface.fillDeck();
                            }

                            onAccepted: surface.attempt()

                            // Any key wakes the lock (and still types).
                            Keys.onPressed: event => {
                                surface.wake();
                                event.accepted = false;
                            }

                            Keys.onEscapePressed: {
                                input.text = "";
                                surface.pendingAction = "";
                                surface.showPassword = false;
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: input.forceActiveFocus()
                        }
                    }

                    // ── the state messages: errors flash below the pill
                    // (its appear → double flash → exit), and the
                    // caps/num/layout line sits under it.
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(centerCol.width, 480 * surface.cs)
                        height: Math.max(errorLine.implicitHeight, hintRow.implicitHeight)

                        opacity: surface.awake

                        Behavior on opacity {
                            NumberAnimation {
                                duration: surface.ambient ? 1400 : 260
                                easing.type: Easing.InOutQuad
                            }
                        }

                        P5Text {
                            id: errorLine

                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            text: Locker.failed ? "Incorrect password. Please try again." : ""
                            color: Colours.danger
                            font.pixelSize: 12 * Math.max(0.8, surface.cs)
                            scale: 0.7
                            opacity: 0

                        onTextChanged: {
                            // QML's textChanged() carries no argument —
                            // read the property itself (the fluid lock's
                            // StateMessage does the same dance).
                            if (errorLine.text !== "") {
                                exitAnim.stop();
                                if (errorLine.opacity > 0)
                                    flashAnim.restart();
                                else
                                    appearAnim.restart();
                            } else {
                                appearAnim.stop();
                                flashAnim.stop();
                                exitAnim.start();
                            }
                        }

                            ParallelAnimation {
                                id: appearAnim

                                NumberAnimation {
                                    target: errorLine
                                    property: "scale"
                                    to: 1
                                    duration: 200
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2
                                }
                                NumberAnimation {
                                    target: errorLine
                                    property: "opacity"
                                    to: 1
                                    duration: 200
                                }
                            }
                            SequentialAnimation {
                                id: flashAnim

                                loops: 2

                                NumberAnimation {
                                    target: errorLine
                                    property: "opacity"
                                    to: 0.3
                                    duration: 110
                                    easing.type: Easing.Linear
                                }
                                NumberAnimation {
                                    target: errorLine
                                    property: "opacity"
                                    to: 1
                                    duration: 110
                                    easing.type: Easing.Linear
                                }
                            }
                            ParallelAnimation {
                                id: exitAnim

                                NumberAnimation {
                                    target: errorLine
                                    property: "scale"
                                    to: 0.7
                                    duration: 300
                                }
                                NumberAnimation {
                                    target: errorLine
                                    property: "opacity"
                                    to: 0
                                    duration: 300
                                }
                            }
                        }

                        Row {
                            id: hintRow

                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            spacing: 8
                            // Fades both ways: opacity carries the state and
                            // visibility follows it (visible alone cut it off).
                            readonly property bool wanted: Config.lock.stateHints && !Locker.failed && (Kbd.capsLock || Kbd.numLock || Kbd.layoutShort !== "")

                            visible: hintRow.opacity > 0.01
                            opacity: hintRow.wanted ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutQuad
                                }
                            }

                            P5Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    const parts = [];
                                    if (Kbd.capsLock)
                                        parts.push("Caps lock is ON");
                                    if (Kbd.numLock)
                                        parts.push("Num lock is ON");
                                    if (Kbd.layoutShort !== "")
                                        parts.push(`Keyboard layout: ${Kbd.layoutShort.toUpperCase()}`);
                                    return parts.join("  ·  ");
                                }
                                color: Colours.alpha(Colours.inkDim, 0.9)
                                font.pixelSize: 12 * Math.max(0.8, surface.cs)
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: rightCol

                    opacity: surface.awake

                    Behavior on opacity {
                        NumberAnimation {
                            duration: surface.ambient ? 1400 : 260
                            easing.type: Easing.InOutQuad
                        }
                    }

                    width: (tileRow.width - centerCol.width - tileRow.spacing * 2) / 2
                    height: surface.stretchIndex("right") >= 0 ? tileRow.colH : rightCol.implicitHeight
                    y: surface.columnY(rightCol.height)
                    spacing: tileRow.gap
                    transform: Translate {
                        x: leanX.value * 12 * surface.depth
                        y: leanY.value * 7 * surface.depth
                    }

                    Repeater {
                        model: LockLayout.list("right")

                        ModuleInTile {
                            required property var modelData

                            modId: modelData
                            face: surface
                            zone: "right"
                            zoneW: rightCol.width
                            Layout.fillWidth: true
                            Layout.fillHeight: index === surface.stretchIndex("right")
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════ The fluid lock's entrance — its initAnim
    // The wallpaper fades in; the square snaps upright while spinning
    // 180°→360°; then it grows to the full card as the icon leaves
    // and the content settles in. Start state and trigger come from
    // prepareEntrance()/restartEntrance() above.
    SequentialAnimation {
        id: initAnim

        ParallelAnimation {
            NumberAnimation {
                target: background
                property: "opacity"
                to: 1
                duration: 400
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation {
                        target: lockContent
                        property: "scale"
                        to: 1
                        duration: 150
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90]
                    }
                    NumberAnimation {
                        target: lockContent
                        property: "rotation"
                        to: 360
                        duration: 350
                        easing.type: Easing.OutQuad
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: lockIcon
                        property: "rotation"
                        to: 360
                        duration: 350
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: lockIcon
                        property: "opacity"
                        to: 0
                        duration: 200
                    }
                    NumberAnimation {
                        target: content
                        property: "opacity"
                        to: 1
                        duration: 200
                    }
                    NumberAnimation {
                        target: content
                        property: "scale"
                        to: 1
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: lockContent
                        property: "radius"
                        to: 42
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: lockContent
                        property: "w"
                        to: surface.fullW
                        duration: 500
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90]
                    }
                    NumberAnimation {
                        target: lockContent
                        property: "h"
                        to: surface.fullH
                        duration: 500
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: [0.42, 1.67, 0.21, 0.90]
                    }
                }
            }
        }
    }

    // ═════════════════════════════ The fluid lock's exit — its unlockAnim
    // Everything runs back: the card shrinks to the lock square, the
    // icon returns, and the background hands over — the glyph dissolves
    // while the bare wallpaper rises to fill the whole screen, exactly
    // as the desktop renders it. The desktop receives the frame the
    // lock leaves behind.
    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            NumberAnimation {
                target: backdrop
                property: "progress"
                to: 0
                duration: 560
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: lockContent
                property: "w"
                to: surface.startSize
                duration: 500
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.42, 1.67, 0.21, 0.90]
            }
            NumberAnimation {
                target: lockContent
                property: "h"
                to: surface.startSize
                duration: 500
                easing.type: Easing.BezierSpline
                easing.bezierCurve: [0.42, 1.67, 0.21, 0.90]
            }
            NumberAnimation {
                target: lockContent
                property: "radius"
                to: surface.startSize / 4
                duration: 500
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: content
                property: "scale"
                to: 0
                duration: 200
            }
            NumberAnimation {
                target: content
                property: "opacity"
                to: 0
                duration: 200
            }
            NumberAnimation {
                target: lockIcon
                property: "opacity"
                to: 1
                duration: 650
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 200
                }
                NumberAnimation {
                    target: lockContent
                    property: "opacity"
                    to: 0
                    duration: 300
                }
            }
        }

        onFinished: surface.exitDone()
    }

    // ═══════════════════════════ the other entrance choreographies
    // ZOOM — the grown card scales in over the fading background.
    SequentialAnimation {
        id: initZoom

        ParallelAnimation {
            NumberAnimation {
                target: background
                property: "opacity"
                to: 1
                duration: 320 * surface.ms
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: lockContent
                property: "scale"
                to: 1
                duration: 420 * surface.ms
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 120 * surface.ms
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: lockIcon
                        property: "opacity"
                        to: 0
                        duration: 160 * surface.ms
                    }
                    NumberAnimation {
                        target: content
                        property: "opacity"
                        to: 1
                        duration: 200 * surface.ms
                    }
                }
            }
        }
    }

    // DROP — the card falls in from above and bounces on the baseline.
    SequentialAnimation {
        id: initDrop

        ParallelAnimation {
            NumberAnimation {
                target: background
                property: "opacity"
                to: 1
                duration: 280 * surface.ms
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: dropShift
                property: "y"
                to: 0
                duration: 460 * surface.ms
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 140 * surface.ms
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: lockIcon
                        property: "opacity"
                        to: 0
                        duration: 160 * surface.ms
                    }
                    NumberAnimation {
                        target: content
                        property: "opacity"
                        to: 1
                        duration: 200 * surface.ms
                    }
                }
            }
        }
    }

    // FADE — nothing moves, everything crossfades.
    SequentialAnimation {
        id: initFade

        ParallelAnimation {
            NumberAnimation {
                target: background
                property: "opacity"
                to: 1
                duration: 420 * surface.ms
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: lockIcon
                property: "opacity"
                to: 0
                duration: 200 * surface.ms
            }
            NumberAnimation {
                target: content
                property: "opacity"
                to: 1
                duration: 220 * surface.ms
            }
        }
    }

    // ════════════════════════════════ the matching exits — unlock side
    SequentialAnimation {
        id: unlockZoom

        ParallelAnimation {
            NumberAnimation {
                target: backdrop
                property: "progress"
                to: 0
                duration: 520 * surface.ms
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: lockContent
                property: "scale"
                to: 0.78
                duration: 300 * surface.ms
                easing.type: Easing.InQuad
            }
            // The card also drops away slightly as it shrinks — the
            // screen is letting it go, and it falls.
            NumberAnimation {
                target: dropShift
                property: "y"
                to: 48 * surface.cs
                duration: 300 * surface.ms
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: lockIcon
                property: "opacity"
                to: 1
                duration: 160 * surface.ms
            }
            NumberAnimation {
                target: content
                property: "opacity"
                to: 0
                duration: 160 * surface.ms
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 140 * surface.ms
                }
                NumberAnimation {
                    target: lockContent
                    property: "opacity"
                    to: 0
                    duration: 220 * surface.ms
                }
            }
        }

        onFinished: surface.exitDone()
    }

    SequentialAnimation {
        id: unlockDrop

        ParallelAnimation {
            NumberAnimation {
                target: backdrop
                property: "progress"
                to: 0
                duration: 520 * surface.ms
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: dropShift
                property: "y"
                to: -140 * surface.cs
                duration: 320 * surface.ms
                easing.type: Easing.InCubic
            }
            // A little heel as the card falls away — it leaves the way
            // it came, only this time it lets go.
            NumberAnimation {
                target: lockContent
                property: "rotation"
                to: -7
                duration: 320 * surface.ms
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: lockIcon
                property: "opacity"
                to: 1
                duration: 160 * surface.ms
            }
            NumberAnimation {
                target: content
                property: "opacity"
                to: 0
                duration: 160 * surface.ms
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 140 * surface.ms
                }
                NumberAnimation {
                    target: lockContent
                    property: "opacity"
                    to: 0
                    duration: 220 * surface.ms
                }
            }
        }

        onFinished: surface.exitDone()
    }

    SequentialAnimation {
        id: unlockFade

        ParallelAnimation {
            NumberAnimation {
                target: backdrop
                property: "progress"
                to: 0
                duration: 520 * surface.ms
                easing.type: Easing.OutCubic
            }
            // The card blooms out slightly as it dissolves — a quiet
            // "everything is fine" instead of a hard cut.
            NumberAnimation {
                target: lockContent
                property: "scale"
                to: 1.045
                duration: 420 * surface.ms
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: lockIcon
                property: "opacity"
                to: 1
                duration: 180 * surface.ms
            }
            NumberAnimation {
                target: content
                property: "opacity"
                to: 0
                duration: 180 * surface.ms
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 160 * surface.ms
                }
                NumberAnimation {
                    target: lockContent
                    property: "opacity"
                    to: 0
                    duration: 260 * surface.ms
                }
            }
        }

        onFinished: surface.exitDone()
    }

    // ═════════════════════ the new choreographies — each one is its own
    // little show, entrance AND exit, on the shared stage props above.
    // Every duration honours the ENTRANCE SPEED dial.

    // FLIP — the card turns over like a menu door: it starts 95° past
    // edge-on and swings flat, the lock mark riding its back.
    SequentialAnimation {
        id: initFlip

        ParallelAnimation {
            NumberAnimation {
                target: background
                property: "opacity"
                to: 1
                duration: 380 * surface.ms
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: cardRotY
                property: "angle"
                to: 0
                duration: 520 * surface.ms
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: lockContent
                property: "scale"
                to: 1
                duration: 520 * surface.ms
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 220 * surface.ms
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: lockIcon
                        property: "opacity"
                        to: 0
                        duration: 160 * surface.ms
                    }
                    NumberAnimation {
                        target: content
                        property: "opacity"
                        to: 1
                        duration: 220 * surface.ms
                    }
                }
            }
        }
    }

    // FLIP out: the card swings away past edge-on and the lock mark
    // takes its back again.
    SequentialAnimation {
        id: unlockFlip

        ParallelAnimation {
            NumberAnimation {
                target: backdrop
                property: "progress"
                to: 0
                duration: 520 * surface.ms
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: content
                property: "opacity"
                to: 0
                duration: 140 * surface.ms
            }
            NumberAnimation {
                target: lockIcon
                property: "opacity"
                to: 1
                duration: 140 * surface.ms
            }
            NumberAnimation {
                target: cardRotY
                property: "angle"
                to: 95
                duration: 480 * surface.ms
                easing.type: Easing.InBack
            }
            NumberAnimation {
                target: lockContent
                property: "scale"
                to: 0.92
                duration: 480 * surface.ms
                easing.type: Easing.InQuad
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 320 * surface.ms
                }
                NumberAnimation {
                    target: lockContent
                    property: "opacity"
                    to: 0
                    duration: 260 * surface.ms
                }
            }
        }

        onFinished: surface.exitDone()
    }

    // VORTEX — the card spirals up out of a point, riding the
    // shockwave ring that blooms behind it.
    SequentialAnimation {
        id: initVortex

        ParallelAnimation {
            NumberAnimation {
                target: background
                property: "opacity"
                to: 1
                duration: 400 * surface.ms
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: lockContent
                property: "scale"
                to: 1
                duration: 640 * surface.ms
                easing.type: Easing.OutBack
                easing.overshoot: 1.35
            }
            NumberAnimation {
                target: lockContent
                property: "rotation"
                to: 0
                duration: 640 * surface.ms
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: dropShift
                property: "y"
                to: 0
                duration: 640 * surface.ms
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation {
                        target: vortexRing
                        property: "opacity"
                        to: 0.55
                        duration: 220 * surface.ms
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: vortexRing
                        property: "scale"
                        to: 1.5
                        duration: 620 * surface.ms
                        easing.type: Easing.OutCubic
                    }
                }
                NumberAnimation {
                    target: vortexRing
                    property: "opacity"
                    to: 0
                    duration: 300 * surface.ms
                }
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 280 * surface.ms
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: lockIcon
                        property: "opacity"
                        to: 0
                        duration: 180 * surface.ms
                    }
                    NumberAnimation {
                        target: content
                        property: "opacity"
                        to: 1
                        duration: 240 * surface.ms
                    }
                }
            }
        }
    }

    // VORTEX out: the spiral runs backwards and the card is pulled
    // back into the point it came from.
    SequentialAnimation {
        id: unlockVortex

        ParallelAnimation {
            NumberAnimation {
                target: backdrop
                property: "progress"
                to: 0
                duration: 520 * surface.ms
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: content
                property: "opacity"
                to: 0
                duration: 120 * surface.ms
            }
            NumberAnimation {
                target: lockIcon
                property: "opacity"
                to: 1
                duration: 160 * surface.ms
            }
            NumberAnimation {
                target: lockContent
                property: "scale"
                to: 0.06
                duration: 620 * surface.ms
                easing.type: Easing.InBack
            }
            NumberAnimation {
                target: lockContent
                property: "rotation"
                to: 330
                duration: 620 * surface.ms
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: dropShift
                property: "y"
                to: -130 * surface.cs
                duration: 620 * surface.ms
                easing.type: Easing.InCubic
            }
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation {
                        target: vortexRing
                        property: "opacity"
                        to: 0.5
                        duration: 200 * surface.ms
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: vortexRing
                        property: "scale"
                        to: 1.5
                        duration: 600 * surface.ms
                        easing.type: Easing.OutCubic
                    }
                }
                NumberAnimation {
                    target: vortexRing
                    property: "opacity"
                    to: 0
                    duration: 280 * surface.ms
                }
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 420 * surface.ms
                }
                NumberAnimation {
                    target: lockContent
                    property: "opacity"
                    to: 0
                    duration: 260 * surface.ms
                }
            }
        }

        onFinished: surface.exitDone()
    }

    // GLITCH — the card slams in sideways with three jitter ticks, its
    // accent and danger ghosts flickering around it while a scanline
    // sweeps the screen; then it snaps into focus.
    SequentialAnimation {
        id: initGlitch

        ParallelAnimation {
            NumberAnimation {
                target: background
                property: "opacity"
                to: 1
                duration: 320 * surface.ms
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation {
                        target: glitchShift
                        property: "x"
                        to: -16
                        duration: 50 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostA
                        property: "flick"
                        to: 0.22
                        duration: 50 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostA
                        property: "dx"
                        to: -18
                        duration: 50 * surface.ms
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: glitchShift
                        property: "x"
                        to: 12
                        duration: 60 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostA
                        property: "flick"
                        to: 0
                        duration: 60 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostB
                        property: "flick"
                        to: 0.24
                        duration: 60 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostB
                        property: "dx"
                        to: 14
                        duration: 60 * surface.ms
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: glitchShift
                        property: "x"
                        to: -7
                        duration: 45 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostA
                        property: "flick"
                        to: 0.18
                        duration: 45 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostA
                        property: "dx"
                        to: -9
                        duration: 45 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostB
                        property: "flick"
                        to: 0
                        duration: 45 * surface.ms
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: glitchShift
                        property: "x"
                        to: 0
                        duration: 70 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostA
                        property: "flick"
                        to: 0
                        duration: 70 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostA
                        property: "dx"
                        to: 0
                        duration: 70 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostB
                        property: "dx"
                        to: 0
                        duration: 70 * surface.ms
                    }
                }
            }
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation {
                        target: scanline
                        property: "opacity"
                        to: 0.8
                        duration: 60 * surface.ms
                    }
                    NumberAnimation {
                        target: scanline
                        property: "y"
                        to: surface.height
                        duration: 420 * surface.ms
                        easing.type: Easing.InQuad
                    }
                }
                NumberAnimation {
                    target: scanline
                    property: "opacity"
                    to: 0
                    duration: 120 * surface.ms
                }
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 240 * surface.ms
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: lockIcon
                        property: "opacity"
                        to: 0
                        duration: 90 * surface.ms
                    }
                    NumberAnimation {
                        target: content
                        property: "opacity"
                        to: 1
                        duration: 110 * surface.ms
                    }
                }
            }
        }
    }

    // GLITCH out: the content cuts, the ghosts tear the card sideways
    // and the screen drops in a flicker.
    SequentialAnimation {
        id: unlockGlitch

        ParallelAnimation {
            NumberAnimation {
                target: backdrop
                property: "progress"
                to: 0
                duration: 520 * surface.ms
                easing.type: Easing.OutCubic
            }                NumberAnimation {
                target: content
                property: "opacity"
                to: 0
                duration: 60 * surface.ms
            }
            SequentialAnimation {
                ParallelAnimation {
                    NumberAnimation {
                        target: glitchShift
                        property: "x"
                        to: 14
                        duration: 55 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostB
                        property: "flick"
                        to: 0.24
                        duration: 55 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostB
                        property: "dx"
                        to: 16
                        duration: 55 * surface.ms
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: glitchShift
                        property: "x"
                        to: -10
                        duration: 60 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostA
                        property: "flick"
                        to: 0.22
                        duration: 60 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostA
                        property: "dx"
                        to: -14
                        duration: 60 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostB
                        property: "flick"
                        to: 0
                        duration: 60 * surface.ms
                    }
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: glitchShift
                        property: "x"
                        to: 0
                        duration: 70 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostA
                        property: "flick"
                        to: 0
                        duration: 70 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostA
                        property: "dx"
                        to: 0
                        duration: 70 * surface.ms
                    }
                    NumberAnimation {
                        target: ghostB
                        property: "dx"
                        to: 0
                        duration: 70 * surface.ms
                    }
                }
            }
            NumberAnimation {
                target: lockIcon
                property: "opacity"
                to: 1
                duration: 120 * surface.ms
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 330 * surface.ms
                }
                NumberAnimation {
                    target: lockContent
                    property: "opacity"
                    to: 0
                    duration: 240 * surface.ms
                }
            }
        }

        onFinished: surface.exitDone()
    }

    // SHUTTER — blast doors: the card stands as a hairline seam and
    // opens sideways around the centre line.
    SequentialAnimation {
        id: initShutter

        ParallelAnimation {
            NumberAnimation {
                target: background
                property: "opacity"
                to: 1
                duration: 360 * surface.ms
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: shutterScale
                property: "xScale"
                to: 1
                duration: 560 * surface.ms
                easing.type: Easing.OutBack
                easing.overshoot: 1.4
            }
            NumberAnimation {
                target: seam
                property: "opacity"
                to: 0.9
                duration: 120 * surface.ms
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 320 * surface.ms
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: seam
                        property: "opacity"
                        to: 0
                        duration: 220 * surface.ms
                    }
                    NumberAnimation {
                        target: lockIcon
                        property: "opacity"
                        to: 0
                        duration: 160 * surface.ms
                    }
                    NumberAnimation {
                        target: content
                        property: "opacity"
                        to: 1
                        duration: 200 * surface.ms
                    }
                }
            }
        }
    }

    // SHUTTER out: the seam flashes back and the doors close on the
    // screen.
    SequentialAnimation {
        id: unlockShutter

        ParallelAnimation {
            NumberAnimation {
                target: backdrop
                property: "progress"
                to: 0
                duration: 520 * surface.ms
                easing.type: Easing.OutCubic
            }                NumberAnimation {
                target: content
                property: "opacity"
                to: 0
                duration: 120 * surface.ms
            }
            NumberAnimation {
                target: lockIcon
                property: "opacity"
                to: 1
                duration: 140 * surface.ms
            }
            NumberAnimation {
                target: seam
                property: "opacity"
                to: 0.9
                duration: 140 * surface.ms
            }
            NumberAnimation {
                target: shutterScale
                property: "xScale"
                to: 0.05
                duration: 520 * surface.ms
                easing.type: Easing.InBack
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 440 * surface.ms
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: lockContent
                        property: "opacity"
                        to: 0
                        duration: 220 * surface.ms
                    }
                    NumberAnimation {
                        target: seam
                        property: "opacity"
                        to: 0
                        duration: 220 * surface.ms
                    }
                }
            }
        }

        onFinished: surface.exitDone()
    }

    Connections {
        target: Locker
        enabled: !surface.preview

        function onLockedChanged(): void {
            if (Locker.locked)
                surface.restartEntrance();
        }

        function onReleasingChanged(): void {
            if (Locker.releasing)
                surface.restartExit();
        }
    }

    // Nothing else can hold focus on a lock surface, but a stray click on
    // the background should not leave you typing into nowhere either —
    // and the fluid lock's stage answers a neutral click with its thump.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            input.forceActiveFocus();
            if (backdrop.useShape)
                backdrop.thump();
        }
    }

    // Scroll over the lock swaps the background shape, Material-style
    // (SETTINGS → LOCK SCREEN → SHAPES CYCLE ON SCROLL turns it off;
    // the cooldown lives in ShapeBackdrop).
    WheelHandler {
        enabled: !surface.preview
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => backdrop.cycle(event.angleDelta.y > 0 ? 1 : -1)
    }

    // ═══════════════════════════════════════════════════════════ test mode
    Slash {
        anchors.horizontalCenter: parent.horizontalCenter
        y: surface.height * 0.03
        width: 460
        height: 52
        shear: Appearance.skew
        color: Colours.warning
        visible: Locker.testing && !surface.preview

        P5Text {
            anchors.centerIn: parent
            display: true
            text: "TEST — RELEASES ITSELF IN 20 SECONDS"
            color: Colours.paper
            font.pixelSize: Appearance.font.size.normal
        }
    }

    // The way out, spelled out once you have clearly got stuck.
    P5Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: surface.height * 0.94
        visible: !surface.preview && (Locker.attempts >= 3 || Locker.pamErrors > 0)
        text: `${Locker.pamConfig ? "PAM: " + Locker.pamConfig + "   ·   " : ""}STUCK?  CTRL+ALT+F2  ·  LOG IN  ·  loginctl unlock-session`
        color: Colours.alpha(Colours.inkDim, 0.75)
        font.family: Appearance.fontFamily.mono
        font.pixelSize: Appearance.font.size.small
    }

    // The preview is a picture: nothing under it may be clicked, typed
    // into or scrolled — the power module's buttons are real buttons.
    MouseArea {
        anchors.fill: parent
        z: 1000
        visible: surface.preview
        enabled: surface.preview
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }

    // One card module in its column — the fluid lock's cards fill the column
    // and arrive one after another (MOTION & LIGHT → CARDS ONE BY ONE), or
    // with the rest of the inside when that is off. A module with nothing
    // to show (no song, no notifications) rests in its idle look: SLIM is
    // its own low card, HIDE takes the tile out until there is something.
    // With RESPOND TO THE POINTER the card lifts a little under the mouse.
    component ModuleInTile: Item {
        id: tileRoot

        readonly property string idle: tileRoot.modId === "media" ? Config.lock.mediaIdle : (tileRoot.modId === "notifs" ? Config.lock.notifsIdle : "card")
        readonly property bool resting: hostChip.quiet && tileRoot.idle !== "card"

        visible: !(hostChip.quiet && tileRoot.idle === "hide")
        onRestingChanged: tileRoot.tell()
        Component.onCompleted: tileRoot.tell()

        function tell(): void {
            if (tileRoot.face)
                tileRoot.face.setResting(tileRoot.modId, tileRoot.resting);
        }

        scale: lift.hovered ? 1.015 : 1

        // CARDS ONE BY ONE: left and right take turns, top to bottom
        property real rise: 1
        readonly property int order: tileRoot.zone === "left" ? tileRoot.index * 2 : tileRoot.index * 2 + 1

        opacity: tileRoot.rise
        transform: Translate {
            y: (1 - tileRoot.rise) * 30
        }

        Connections {
            target: tileRoot.face
            ignoreUnknownSignals: true

            function onCardsReset(): void {
                riseIn.stop();
                tileRoot.rise = 0;
                riseGuard.restart();
            }

            function onCardsIn(): void {
                riseIn.restart();
            }
        }

        SequentialAnimation {
            id: riseIn

            PauseAnimation {
                duration: 80 + tileRoot.order * 75
            }
            NumberAnimation {
                target: tileRoot
                property: "rise"
                to: 1
                duration: 640
                easing.type: Easing.OutBack
                easing.overshoot: 1.1
            }
        }

        // never left hidden: an entrance cut short still brings the card in
        Timer {
            id: riseGuard

            interval: 3000
            onTriggered: {
                if (tileRoot.rise < 1 && !riseIn.running)
                    riseIn.restart();
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: lift

            enabled: Config.lock.fluidHover && Config.lock.tileCards
        }

        required property string modId
        required property string zone
        required property int index
        // NOT required: the column width must stay a live binding — the
        // surface is 0×0 when the Repeater first creates the tiles, and a
        // required property would freeze that moment's (negative) width
        // forever, collapsing every module card to nothing.
        property real zoneW: 0
        // The face the power buttons ask for a password on.
        property var face: null

        implicitWidth: hostChip.implicitWidth
        implicitHeight: hostChip.implicitHeight

        ModuleHost {
            id: hostChip

            anchors.fill: parent
            wid: modId
            host: tileRoot.face
            maxWidth: zoneW
            fillWidth: true
            fillHeight: tileRoot.Layout.fillHeight
            carded: Config.lock.tileCards
        }
    }
}
