//  VELVET  ·  modules/launcher/Launcher.qml
//  Type to run. Apps, maths, and shell commands behind ">".
//
//  v7 — the living room. The quiet solar system grows up: a glass sun at
//  the heart, planets with real weight and their names riding beneath
//  them, and a sky of slow stars that slides with the ring so the room
//  reads as deep. The whole system leans toward your pointer like a game
//  camera. Launching sends a planet off with a double shockwave and a
//  room-wide blink. Navigation snaps with a fighting-game tick; typing
//  glides. Alt+P pins, Escape clears first and quits second, > runs shell,
//  = does maths. Alt+1…9 fires a planet by its number.
//  The dials are the user's (MODULES → PILL LAUNCHER, Config.launcher): how
//  the planets arrive, drift and lean, the orbit line, the lock-on ring, the
//  stars, the size, the backdrop, the glow and the launch.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Shapes

PanelWindow {
    id: root

    property bool rendered: false
    property bool entered: false
    property bool closing: false
    property bool launching: false
    property int index: 0
    // The orbit shows at most 8 slots; for longer result lists the window
    // slides along. winBase is the result that owns slot 0.
    property int winBase: 0
    // ringTarget is where the ring is *supposed* to point — the selected
    // slot at twelve o'clock. It animates with a snap; the slow idle drift
    // is idleAngle, so the two never fight.
    property real ringTarget: 0
    property real idleAngle: 0
    property real holdUntil: 0
    property real lastTurn: 0
    property real dip: 1
    property int launchTick: 0
    property var launchItem: null
    // v7: two moods of turning — typing glides, navigation snaps.
    property bool softSnap: false
    property bool typing: input.text !== ""
    // The room leans toward the pointer (game-camera parallax).
    property real tiltX: 0
    property real tiltY: 0
    property real mouseX: -999
    property real mouseY: -999
    property bool overOrb: false
    property bool overPill: false
    property real flash: 0
    property bool altHeld: false

    // ── the user's dials
    readonly property real spd: Math.max(0.25, Config.launcher.speed || 1)
    function ms(v: real): int {
        return Math.max(0, Math.round(v * Config.appearance.animationScale * Appearance.motionK / root.spd));
    }
    readonly property real k: Math.max(0.8, Math.min(1.3, Config.launcher.scale || 1))
    readonly property string ent: root.ms(100) === 0 ? "none" : Config.launcher.orbitEntrance
    readonly property string fxKind: Config.launcher.launchFx
    // PLANETS SHOWN: 3 … 8 (the ring has room for eight)
    readonly property int maxSlots: Math.max(3, Math.min(8, Config.launcher.maxShown))
    // A deterministic star field — same sky every time you open it.
    readonly property var stars: {
        const out = [];
        let s = 0x2e7d;
        const rnd = () => {
            s = (s * 16807) % 2147483647;
            return s / 2147483647;
        };
        for (let i = 0; i < 46; i++)
            out.push({ x: rnd(), y: 0.08 + rnd() * 0.74, d: rnd(), size: 1 + rnd() * 1.8, a: 0.10 + rnd() * 0.30, dur: 1600 + rnd() * 2400, c: rnd() });
        return out;
    }

    // ------------------------------------------------------- orbit geometry
    readonly property real boxSize: 840        // orbit box
    readonly property real orbC: boxSize / 2   // orbit centre
    readonly property real rx: 340             // ellipse x radius
    readonly property real ry: 215             // ellipse y radius
    readonly property int slotCount: Math.min(root.maxSlots, root.results.length)
    readonly property real step: 360 / Math.max(1, root.slotCount)
    readonly property int selSlot: Math.max(0, root.index - root.winBase)
    // The selected slot's angle in world coordinates.
    // ringTarget and idleAngle are DEGREES (step, ±180 wrap, % 360) — they
    // were added to radians raw, which spun the ring ~57× too fast.
    readonly property real selAng: ((-90 + root.selSlot * root.step + root.ringTarget + root.idleAngle) * Math.PI / 180)

    readonly property var results: {
        Apps.usage;   // re-run when frecency changes
        return Apps.search(input.text);
    }

    onResultsChanged: {
        root.index = 0;
        root.winBase = 0;
        root.softSnap = true;
        let target = -root.idleAngle;
        while (target - root.ringTarget > 180)
            target -= 360;
        while (target - root.ringTarget < -180)
            target += 360;
        root.ringTarget = target;
        // Results can settle before the glide ends; never leave the slow
        // easing armed for navigation.
        softSnapTimer.restart();
        // Typing pauses the drift so the fresh results stay readable.
        root.holdUntil = Date.now() + 2600;
    }

    readonly property var orbitList: {
        const out = [];
        for (let i = 0; i < root.slotCount; i++)
            out.push(root.results[root.winBase + i] ?? null);
        return out;
    }
    readonly property var selected: root.results.length > 0
        ? root.results[Math.max(0, Math.min(root.results.length - 1, root.index))]
        : null

    readonly property real panelW: Math.min(Config.launcher.width * root.k, root.width * 0.92)
    readonly property real orbitScale: Math.min(root.k, (root.height * 0.86) / 850, (root.panelW * 0.94) / root.boxSize)

    // The ring turns the shortest way (a ±360° correction is invisible).
    // One behaviour, two moods — its parameters flip when typing starts,
    // so results glide while navigation snaps.
    Behavior on ringTarget {
        NumberAnimation {
            duration: root.ms(root.softSnap ? 300 : 340)
            easing.type: root.softSnap ? Easing.OutCubic : Easing.OutBack
            easing.overshoot: root.softSnap ? 0 : 1.25
        }
    }

    Timer {
        id: softSnapTimer

        interval: 340
        onTriggered: root.softSnap = false
    }

    // The room leans toward the pointer — a game-camera tilt, subtle
    // enough to feel rather than see. Behaviors do the smoothing.
    Behavior on tiltX {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Behavior on tiltY {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    screen: Hypr.focusedScreen
    visible: rendered
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-launcher"
    WlrLayershell.keyboardFocus: root.entered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // ------------------------------------------------------------ launching
    function run(item: var): void {
        if (!item || root.launching)
            return;
        root.launching = true;
        root.launchItem = item;
        root.holdUntil = Date.now() + 900;
        // Apps get the "GO" chirp; settings, maths and commands the plain
        // confirm — the sound itself tells you what you fired.
        if (item.kind === "app")
            Sfx.launch();
        else
            Sfx.select();
        // LAUNCHER → WHEN YOU OPEN SOMETHING: JUST CLOSE fires at once
        if (root.fxKind === "none" || root.ms(100) === 0) {
            root.doLaunch();
            return;
        }
        root.launchTick += 1;
        // The sun itself fires: a muzzle blink and a soft kick of recoil,
        // exactly on the beat the planet leaves.
        if (root.fxKind === "burst") {
            fieldMuzzle.restart();
            fieldRecoil.restart();
        }
        launchTimer.interval = root.ms(item.kind === "app" ? 340 : 240);
        launchTimer.restart();
    }

    Timer {
        id: launchTimer

        onTriggered: root.doLaunch()
    }

    // The flourish plays first, then the app fires.
    function doLaunch(): void {
        const it = root.launchItem;
        if (!it)
            return;
        root.launchItem = null;
        root.launching = false;
        Apps.launch(it);
        // Settings open their own window (openSettingsAt has already closed
        // the panels); closing again here would slam that door on them.
        if (it.kind !== "setting")
            Panels.closeAll();
    }

    // The one shared steering: wrap-around like a fighting-game select, the
    // window slides when you step past it, and the ring sweeps the chosen
    // slot to twelve o'clock.
    function gotoIndex(i: int): void {
        const n = root.results.length;
        if (n === 0) {
            root.index = 0;
            return;
        }
        const next = Math.max(0, Math.min(n - 1, i));
        if (next === root.index)
            return;
        root.softSnap = false;
        root.index = next;
        const slots = Math.min(root.maxSlots, n);
        const oldBase = root.winBase;
        if (root.index < root.winBase)
            root.winBase = root.index;
        else if (root.index >= root.winBase + slots)
            root.winBase = root.index - slots + 1;
        // ringTarget makes up for where the idle drift has carried the ring
        // since the last snap, so the selection lands exactly at the top.
        let target = -(root.index - root.winBase) * root.step - root.idleAngle;
        while (target - root.ringTarget > 180)
            target -= 360;
        while (target - root.ringTarget < -180)
            target += 360;
        root.ringTarget = target;
        // Hold the drift through the snap, then give the chosen planet a
        // beat at the top before the ring goes back to circling.
        root.holdUntil = Date.now() + 340 + 2400;
        if (root.winBase !== oldBase) {
            root.dip = 0.85;
            if (root.ms(100) > 0)
                dipBack.restart();
            else
                root.dip = 1;
        }
        const t = Date.now();
        if (t - root.lastTurn > 60) {
            root.lastTurn = t;
            Sfx.whoosh();
        }
        root.punch();
    }

    // The pill flinches when the lock jumps — the same tick a fighting-game
    // select screen gives you.
    function punch(): void {
        pillPunch.restart();
        pulse.restart();
        namePop.restart();
        haloPulse.restart();
    }

    NumberAnimation {
        id: dipBack

        target: root
        property: "dip"
        from: 0.85
        to: 1
        duration: root.ms(240)
        easing.type: Easing.OutBack
        easing.overshoot: 1.5
    }

    function moveCursor(delta: int): void {
        const n = root.results.length;
        if (n === 0) {
            root.index = 0;
            return;
        }
        root.gotoIndex((root.index + delta + n) % n);
    }

    // Opens or closes as Panels.launcher says — and also when this window is created BY
    // that flag: panels are loaded on demand (shell.qml, Parked), so the flag is
    // often already true by the time the window exists.
    function present(): void {
        root.altHeld = false;
        if (Panels.launcher) {
            root.closing = false;
            root.rendered = true;
            enterTimer.restart();
            fieldSettle.restart();
            Sfx.open();
        } else {
            if (root.entered)
                Sfx.close();
            root.entered = false;
            root.closing = true;
            exitTimer.restart();
        }
    }

    Connections {
        target: Panels

        function onLauncherChanged(): void {
            root.present();
        }
    }

    // (a PanelWindow has no Component.onCompleted — a one-shot timer does the same)
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (Panels.launcher)
                root.present();
        }
    }

    Timer {
        id: enterTimer

        interval: 1
        onTriggered: {
            root.entered = true;
            input.text = "";
            input.forceActiveFocus();
            pulse.restart();
            root.holdUntil = Date.now() + 2600;
        }
    }

    Timer {
        id: exitTimer

        interval: Math.max(root.ms(260), Appearance.anim.normal) + 20
        onTriggered: root.rendered = false
    }

    // The idle drift: one revolution every ~80 seconds, frozen while
    // something is being read (hold) and while the shell is away.
    Timer {
        id: driftTimer

        interval: 16
        repeat: true
        running: root.entered && Config.launcher.orbitSpin > 0
        onTriggered: {
            if (Date.now() >= root.holdUntil && Config.launcher.orbitSpin > 0)
                root.idleAngle = (root.idleAngle + 0.07 * Config.launcher.orbitSpin) % 360;
        }
    }

    // ------------------------------------------------------------------ scrim
    Rectangle {
        anchors.fill: parent
        color: Colours.alpha(Colours.paper, Math.min(0.97, 0.82 * Math.max(0, Config.launcher.dim)))
        opacity: root.entered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }

        // A soft vignette — the room darkens toward its edges, so the eye
        // falls on the middle without being told to.
        Shape {
            anchors.fill: parent
            asynchronous: false

            ShapePath {
                fillColor: "transparent"
                strokeColor: "transparent"
                strokeWidth: 0

                fillGradient: RadialGradient {
                    centerX: root.width / 2
                    centerY: root.height / 2
                    focalX: root.width / 2
                    focalY: root.height / 2
                    centerRadius: root.width * 0.62
                    focalRadius: 0

                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 0.62
                        color: "transparent"
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(0, 0, 0, 0.5)
                    }
                }

                PathPolyline {
                    path: [
                        Qt.point(0, 0),
                        Qt.point(root.width, 0),
                        Qt.point(root.width, root.height),
                        Qt.point(0, root.height),
                        Qt.point(0, 0)
                    ]
                }
            }
        }

        // The sky: a scatter of dim stars, each breathing on its own slow
        // phase. They slide a little with the ring — parallax is how the
        // eye reads depth without any lines being drawn.
        Repeater {
            model: Config.launcher.stars ? root.stars : []

            Item {
                id: starHost

                required property var modelData

                readonly property real drift: Math.sin((root.idleAngle + root.ringTarget) * Math.PI / 180 + starHost.modelData.d * 6.2832) * (14 + starHost.modelData.d * 26)
                property real twinkle: 0.25

                x: starHost.modelData.x * root.width + starHost.drift
                y: starHost.modelData.y * root.height
                opacity: root.entered ? starHost.twinkle : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                    }
                }

                SequentialAnimation on twinkle {
                    running: root.entered
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 0.25
                        to: 1
                        duration: starHost.modelData.dur / 2
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 1
                        to: 0.25
                        duration: starHost.modelData.dur / 2
                        easing.type: Easing.InOutSine
                    }
                }

                Rectangle {
                    width: starHost.modelData.size
                    height: starHost.modelData.size
                    radius: width / 2
                    color: starHost.modelData.c > 0.90 ? Colours.accent : Colours.ink
                    opacity: starHost.modelData.a
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Panels.closeAll()
        }
    }

    // ------------------------------------------------------------------ panel
    Item {
        id: panel

        // LAUNCHER → SIDE
        x: Math.round(Appearance.sideX(Config.launcher.side, root.width, panel.width, 24))
        y: Math.max(8, (root.height - panel.height) / 2)
        width: root.panelW
        height: root.boxSize * root.orbitScale + 24

        opacity: root.entered ? 1 : 0
        scale: root.entered ? 1 : 0.95

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }

        // ------------------------------------------------------- the system
        Item {
            id: orbitBox

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            width: root.boxSize
            height: root.boxSize

            transform: [
                Scale {
                    origin.x: root.orbC
                    origin.y: root.orbC
                    xScale: root.orbitScale
                    yScale: root.orbitScale
                },
                Rotation {
                    origin.x: root.orbC
                    origin.y: root.orbC
                    axis.x: 1
                    axis.y: 0
                    axis.z: 0
                    angle: root.tiltY
                },
                Rotation {
                    origin.x: root.orbC
                    origin.y: root.orbC
                    axis.x: 0
                    axis.y: 1
                    axis.z: 0
                    angle: root.tiltX
                }
            ]

            // The sun's light — a wide soft wash, and a tighter one that
            // breathes.
            Shape {
                x: root.orbC - 410
                y: root.orbC - 410
                width: 820
                height: 820

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: "transparent"
                    strokeWidth: 0

                    fillGradient: RadialGradient {
                        centerX: 410
                        centerY: 410
                        focalX: 410
                        focalY: 410
                        centerRadius: 330
                        focalRadius: 0

                        GradientStop {
                            position: 0.0
                            color: Colours.alpha(Colours.accent, 0.05 * Config.launcher.aura / 0.6)
                        }
                        GradientStop {
                            position: 1.0
                            color: Colours.alpha(Colours.accent, 0)
                        }
                    }

                    PathPolyline {
                        path: [
                            Qt.point(0, 0),
                            Qt.point(820, 0),
                            Qt.point(820, 820),
                            Qt.point(0, 820),
                            Qt.point(0, 0)
                        ]
                    }
                }
            }

            Shape {
                id: corona

                x: root.orbC - 280
                y: root.orbC - 280
                width: 560
                height: 560

                visible: Config.launcher.aura > 0.01

                SequentialAnimation on scale {
                    running: root.entered && corona.visible
                    loops: Animation.Infinite
                    NumberAnimation {
                        from: 1
                        to: 1.06
                        duration: 3400
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 1.06
                        to: 1
                        duration: 3400
                        easing.type: Easing.InOutSine
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: "transparent"
                    strokeWidth: 0

                    fillGradient: RadialGradient {
                        centerX: 280
                        centerY: 280
                        focalX: 280
                        focalY: 280
                        centerRadius: 240
                        focalRadius: 0

                        GradientStop {
                            position: 0.0
                            color: Colours.alpha(Colours.accent, Math.min(0.3, 0.11 * Config.launcher.aura / 0.6))
                        }
                        GradientStop {
                            position: 1.0
                            color: Colours.alpha(Colours.accent, 0)
                        }
                    }

                    PathPolyline {
                        path: [
                            Qt.point(0, 0),
                            Qt.point(560, 0),
                            Qt.point(560, 560),
                            Qt.point(0, 560),
                            Qt.point(0, 0)
                        ]
                    }
                }
            }

            // The orbit's own line (LAUNCHER → ORBIT LINE): a faint dotted
            // ellipse along the planets' path. Drawn once — it never changes
            // shape, it only grows in with the planets.
            Shape {
                id: ring

                property real grow: 0

                anchors.fill: parent
                visible: Config.launcher.orbitRing && root.slotCount > 0
                z: -300
                opacity: 0.9 * ring.grow
                scale: 0.6 + 0.4 * ring.grow
                preferredRendererType: Shape.GeometryRenderer
                layer.enabled: ring.visible
                layer.samples: 4

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colours.alpha(Colours.accent, 0.30)
                    strokeWidth: 1.6
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [1.2, 5]
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: root.orbC
                        centerY: root.orbC
                        radiusX: root.rx
                        radiusY: root.ry
                        startAngle: 0
                        sweepAngle: 360
                    }
                }

                NumberAnimation {
                    id: ringIn

                    target: ring
                    property: "grow"
                    from: 0
                    to: 1
                    duration: root.ms(520)
                    easing.type: Easing.OutCubic
                }
                Connections {
                    target: root

                    function onEnteredChanged(): void {
                        if (root.entered) {
                            if (root.ms(100) > 0)
                                ringIn.restart();
                            else
                                ring.grow = 1;
                        }
                    }
                    function onClosingChanged(): void {
                        if (root.closing)
                            ring.grow = 0;
                    }
                }
            }

            // The lock-on ring (LAUNCHER → LOCK-ON RING): four arcs turning
            // slowly round the chosen planet; it snaps tight when the
            // choice jumps.
            Item {
                id: reticle

                property real punch: 1

                x: root.orbC + Math.cos(root.selAng) * root.rx - 70
                y: root.orbC + Math.sin(root.selAng) * root.ry - 70
                width: 140
                height: 140
                z: 400
                visible: Config.launcher.reticle && root.slotCount > 0 && root.entered && !root.launching
                scale: reticle.punch

                SequentialAnimation {
                    id: reticlePunch

                    NumberAnimation { target: reticle; property: "punch"; from: 1.35; to: 1; duration: root.ms(300); easing.type: Easing.OutBack; easing.overshoot: 1.8 }
                }
                Connections {
                    target: root

                    function onIndexChanged(): void {
                        if (root.ms(100) > 0 && root.entered)
                            reticlePunch.restart();
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.GeometryRenderer
                    layer.enabled: reticle.visible
                    layer.samples: 4

                    RotationAnimation on rotation {
                        running: reticle.visible && root.ms(100) > 0
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 9000
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Colours.alpha(Colours.accent, 0.85)
                        strokeWidth: 2.2
                        capStyle: ShapePath.RoundCap

                        PathAngleArc { centerX: 70; centerY: 70; radiusX: 62; radiusY: 62; startAngle: 10; sweepAngle: 50; moveToStart: true }
                        PathAngleArc { centerX: 70; centerY: 70; radiusX: 62; radiusY: 62; startAngle: 100; sweepAngle: 50; moveToStart: true }
                        PathAngleArc { centerX: 70; centerY: 70; radiusX: 62; radiusY: 62; startAngle: 190; sweepAngle: 50; moveToStart: true }
                        PathAngleArc { centerX: 70; centerY: 70; radiusX: 62; radiusY: 62; startAngle: 280; sweepAngle: 50; moveToStart: true }
                    }
                }
            }

            // The soft halo behind the chosen planet.
            Shape {
                id: halo

                x: root.orbC + Math.cos(root.selAng) * root.rx - 62
                y: root.orbC + Math.sin(root.selAng) * root.ry - 62
                width: 124
                height: 124
                visible: root.slotCount > 0
                z: -200
                opacity: 0.85

                // The halo flinches when the lock jumps — the planet's own
                // little tick, one beat after the pill's.
                SequentialAnimation {
                    id: haloPulse

                    NumberAnimation {
                        target: halo
                        property: "opacity"
                        from: 0.85
                        to: 1
                        duration: 60
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: halo
                        property: "opacity"
                        from: 1
                        to: 0.85
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: "transparent"
                    strokeWidth: 0

                    fillGradient: RadialGradient {
                        centerX: 62
                        centerY: 62
                        focalX: 62
                        focalY: 62
                        centerRadius: 52
                        focalRadius: 0

                        GradientStop {
                            position: 0.0
                            color: Colours.alpha(Colours.accent, 0.2)
                        }
                        GradientStop {
                            position: 0.65
                            color: Colours.alpha(Colours.accent, 0.05)
                        }
                        GradientStop {
                            position: 1.0
                            color: Colours.alpha(Colours.accent, 0)
                        }
                    }

                    PathPolyline {
                        path: [
                            Qt.point(0, 0),
                            Qt.point(124, 0),
                            Qt.point(124, 124),
                            Qt.point(0, 124),
                            Qt.point(0, 0)
                        ]
                    }
                }
            }

            // ---------------------------------------------------- the planets
            Repeater {
                model: root.slotCount

                Item {
                    id: orb

                    required property int index

                    readonly property var app: root.orbitList[orb.index] ?? null
                    readonly property bool sel: orb.app !== null && root.selSlot === orb.index
                    readonly property real slotAng: ((-90 + orb.index * root.step) * Math.PI) / 180
                    readonly property real worldAng: orb.slotAng + (root.ringTarget + root.idleAngle) * Math.PI / 180
                    // Depth: the bottom of the ring reads as near, the top
                    // as far — the planets grow and brighten as they come
                    // around, and shrink as they pass behind the sun.
                    readonly property real depth: Math.sin(orb.worldAng)
                    readonly property real dScale: 0.95 + 0.05 * orb.depth
                    readonly property real dAlpha: 0.82 + 0.18 * ((orb.depth + 1) / 2)
                    property real born: 0
                    property real hoverBoost: 0
                    property real launchOff: 0
                    property real launchOut: 0
                    property real selBoost: orb.sel ? 1.14 : 1

                    Behavior on selBoost {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.8
                        }
                    }

                    // PLANETS ARRIVING: BLOOM grows out of the sun, SPIRAL
                    // swings out along a turn, DROP falls in from above
                    readonly property real spiralOff: root.ent === "spiral" ? (1 - Math.min(1, orb.born)) * 2.6 : 0
                    readonly property real reach: root.ent === "drop" ? 1 : orb.born
                    readonly property real dropOff: root.ent === "drop" ? (1 - Math.min(1, orb.born)) * -340 : 0

                    width: 92
                    height: 92
                    x: root.orbC + Math.cos(orb.worldAng + orb.spiralOff) * (root.rx * orb.reach + 260 * orb.launchOut) - 46
                    y: root.orbC + Math.sin(orb.worldAng + orb.spiralOff) * (root.ry * orb.reach + 260 * orb.launchOut) - 46 + orb.dropOff
                    // Depth sorts the stack: near planets render in front
                    // of far ones, the way the eye expects.
                    z: Math.round(orb.depth * 100)
                    scale: (root.ent === "drop" ? 0.7 + 0.3 * orb.born : orb.born) * orb.dScale * orb.selBoost * root.dip * (1 + 0.05 * orb.hoverBoost) * (1 + (root.fxKind === "zoom" ? 2.2 : 0.85) * orb.launchOff)
                    opacity: orb.born * (1 - orb.launchOff)
                    visible: orb.app !== null

                    // The pointer finds planets by position, not geometry —
                    // one panel-wide sensor feeds every planet at once.
                    readonly property real cxp: (root.mouseX - root.panelW / 2) / Math.max(0.01, root.orbitScale)
                    readonly property real cyp: (root.mouseY - root.orbC * root.orbitScale) / Math.max(0.01, root.orbitScale)
                    readonly property real ocx: root.orbC + Math.cos(orb.worldAng) * root.rx
                    readonly property real ocy: root.orbC + Math.sin(orb.worldAng) * root.ry
                    readonly property bool hovered: root.entered && orb.born > 0.85 && Math.abs(orb.cxp - orb.ocx) < 62 && Math.abs(orb.cyp - orb.ocy) < 62
                    property real labelPx: orb.sel ? 13 : 11

                    Behavior on labelPx {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }

                    onHoveredChanged: {
                        if (orb.hovered && !root.closing) {
                            hoverUp.restart();
                            root.overOrb = true;
                            if (orb.app)
                                root.gotoIndex(root.winBase + orb.index);
                        } else {
                            root.overOrb = false;
                            hoverDown.restart();
                        }
                    }

                    // Birth: staggered bloom out of the sun on open; instant
                    // for pills that appear mid-typing.
                    Timer {
                        id: birthTimer

                        interval: root.ms(orb.index * (root.ent === "spiral" ? 60 : 45))
                        onTriggered: {
                            if (root.ent === "none")
                                orb.born = 1;
                            else
                                birthAnim.restart();
                        }
                    }

                    NumberAnimation {
                        id: birthAnim

                        target: orb
                        property: "born"
                        from: 0
                        to: 1
                        duration: root.ms(root.ent === "spiral" ? 620 : (root.ent === "drop" ? 520 : 400))
                        easing.type: Easing.OutBack
                        easing.overshoot: root.ent === "drop" ? 1.6 : 1.3
                    }

                    SequentialAnimation {
                        id: exitAnim

                        PauseAnimation {
                            duration: root.ms(Math.max(0, root.slotCount - 1 - orb.index) * 22)
                        }
                        NumberAnimation {
                            target: orb
                            property: "born"
                            from: orb.born
                            to: 0
                            duration: root.ms(160)
                            easing.type: Easing.OutCubic
                        }
                    }

                    ParallelAnimation {
                        id: launchAnim

                        NumberAnimation {
                            target: orb
                            property: "launchOff"
                            from: 0
                            to: 1
                            duration: root.ms(320)
                            easing.type: Easing.OutQuad
                        }
                        // ZOOM flies the planet at you instead of off the ring
                        NumberAnimation {
                            target: orb
                            property: "launchOut"
                            from: 0
                            to: root.fxKind === "zoom" ? 0 : 1
                            duration: root.ms(320)
                            easing.type: Easing.OutExpo
                        }
                    }

                    NumberAnimation {
                        id: hoverUp

                        target: orb
                        property: "hoverBoost"
                        to: 1
                        duration: 90
                        easing.type: Easing.OutCubic
                    }

                    NumberAnimation {
                        id: hoverDown

                        target: orb
                        property: "hoverBoost"
                        to: 0
                        duration: 180
                        easing.type: Easing.OutCubic
                    }

                    Component.onCompleted: {
                        if (root.entered && !root.closing) {
                            birthTimer.interval = 0;
                            birthTimer.start();
                        }
                    }

                    Connections {
                        target: root

                        function onEnteredChanged(): void {
                            // The delegate can be mid-destruction when these
                            // fire (the launcher closing over a config
                            // reload) — its animations resolve to undefined
                            // then, and calling them would throw.
                            if (!birthTimer)
                                return;
                            if (root.entered) {
                                birthTimer.interval = root.ms(orb.index * (root.ent === "spiral" ? 60 : 45));
                                birthTimer.start();
                            }
                        }
                        function onClosingChanged(): void {
                            if (!birthTimer || !exitAnim)
                                return;
                            birthTimer.stop();
                            if (root.closing && orb.born > 0.01)
                                exitAnim.restart();
                        }
                        function onLaunchTickChanged(): void {
                            if (!launchAnim)
                                return;
                            if (root.launchTick > 0 && orb.sel && orb.app !== null)
                                launchAnim.restart();
                        }
                    }

                    Item {
                        anchors.fill: parent
                        opacity: orb.sel ? 1 : orb.dAlpha

                        // Soft ground shadow — the planet floats above the
                        // ring plane.
                        Plate {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height - 14
                            width: parent.width * 0.74
                            height: parent.width * 0.32
                            radius: Appearance.pill(height)
                            color: Qt.rgba(0, 0, 0, 0.30)
                        }

                        Rectangle {
                            id: orbDisc

                            anchors.fill: parent
                            radius: width / 2
                            antialiasing: true
                            clip: true
                            // the chosen planet wears a thin rim of light
                            border.width: orb.sel ? 2 : 0
                            border.color: Colours.alpha(Colours.accent, 0.75)
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0
                                    color: orb.sel ? Colours.mix(Colours.surfaceHigh, Colours.accent, 0.30) : Colours.lighten(Colours.surfaceHigh, 0.05)
                                }
                                GradientStop {
                                    position: 1.0
                                    color: orb.sel ? Colours.mix(Colours.surface, Colours.accent, 0.18) : Colours.surface
                                }
                            }

                            // A curved kiss of light across the top — the
                            // whole "glass" reads in one stroke.
                            Plate {
                                anchors.top: parent.top
                                anchors.topMargin: parent.height * 0.09
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width * 0.80
                                height: parent.height * 0.28
                                radius: Appearance.pill(height)
                                color: Colours.alpha(Colours.ink, orb.sel ? 0.14 : 0.08)
                            }

                            // The orbs are positioned on the ring, never rotated,
                            // so the icons already face up — no counter-rotation.
                            Item {
                                anchors.fill: parent

                                IconImage {
                                    anchors.centerIn: parent
                                    visible: Config.launcher.showIcons && orb.app?.kind === "app"
                                    implicitSize: 50
                                    scale: orb.sel ? 1 : 0.86
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 1.6
                                        }
                                    }
                                    source: orb.app?.kind === "app" && (orb.app.icon ?? "") !== "" ? Quickshell.iconPath(orb.app.icon, "application-x-executable") : ""
                                    asynchronous: true
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    visible: orb.app !== null && orb.app.kind !== "app"
                                    name: orb.app?.icon ?? "search"
                                    color: orb.sel ? Colours.accent : Colours.inkDim
                                    font.pixelSize: 42
                                    scale: orb.sel ? 1 : 0.86
                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: 180
                                            easing.type: Easing.OutBack
                                            easing.overshoot: 1.6
                                        }
                                    }
                                }
                            }

                            Ripple {
                                id: orbRipple

                                anchors.fill: parent
                                color: Colours.accent
                                maxOpacity: 0.25
                            }
                        }

                        // The pin star, riding the pill's shoulder.
                        Plate {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 2
                            width: 20
                            height: 20
                            radius: Appearance.r(10)
                            visible: orb.app?.kind === "app" && orb.app?.pinned === true
                            color: Colours.paper
                            antialiasing: true

                            Icon {
                                anchors.centerIn: parent
                                name: "star"
                                color: Colours.accent
                                font.pixelSize: 11
                            }
                        }
                    }

                    // Alt held: the planet's quick key (LAUNCHER → QUICK KEYS)
                    Rectangle {
                        id: orbBadge

                        readonly property bool shown: root.altHeld && orb.app !== null && orb.index < 9

                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: -2
                        width: 26
                        height: 26
                        radius: 13
                        z: 3
                        color: orb.sel ? Colours.accent : Colours.paper
                        border.width: 1.5
                        border.color: Colours.accent
                        opacity: orbBadge.shown ? 1 : 0
                        scale: orbBadge.shown ? 1 : 0.4
                        visible: opacity > 0.01

                        Behavior on opacity {
                            NumberAnimation { duration: root.ms(140) }
                        }
                        Behavior on scale {
                            NumberAnimation { duration: root.ms(240); easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: String(orb.index + 1)
                            color: orb.sel ? Colours.on(Colours.accent) : Colours.accent
                            font.family: Appearance.fontFamily.mono
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    // The planet's name rides beneath it — it speaks only
                    // when the planet comes around to the front.
                    Text {
                        anchors.top: parent.bottom
                        anchors.topMargin: 3
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 176
                        horizontalAlignment: Text.AlignHCenter
                        property real labelSp: orb.sel ? 0.9 : 0.4
                        Behavior on labelSp { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        visible: orb.app !== null
                        // the typed letters lit (LAUNCHER → LIGHT THE TYPED LETTERS)
                        text: orb.app ? Apps.marked(orb.app.name, input.text, String(Colours.accent), false) : ""
                        textFormat: Text.StyledText
                        color: orb.sel ? Colours.ink : Colours.alpha(Colours.ink, 0.62)
                        opacity: Math.max(orb.dAlpha, orb.hoverBoost * 0.85)
                        font.family: Appearance.fontFamily.body
                        font.pixelSize: orb.labelPx
                        font.weight: orb.sel ? Font.Black : Font.DemiBold
                        font.letterSpacing: labelSp
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: orbArea

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: event => {
                            orbRipple.pop(event.x, event.y);
                            root.run(orb.app);
                        }
                    }
                }
            }

            // The launch wave: one clean ring of light where the planet was.
            Rectangle {
                id: shock

                x: root.orbC + Math.cos(root.selAng) * root.rx - 58
                y: root.orbC + Math.sin(root.selAng) * root.ry - 58
                width: 116
                height: 116
                radius: Appearance.r(58)
                color: "transparent"
                border.width: 2
                border.color: Colours.accent
                scale: 0.5
                opacity: 0
                visible: root.slotCount > 0
                z: 500

                ParallelAnimation {
                    id: shockAnim

                    NumberAnimation {
                        target: shock
                        property: "scale"
                        from: 0.5
                        to: 2.4
                        duration: root.ms(460)
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: shock
                        property: "opacity"
                        from: 0.5
                        to: 0
                        duration: root.ms(460)
                        easing.type: Easing.OutQuad
                    }
                }

                Connections {
                    target: root

                    function onLaunchTickChanged(): void {
                        if (root.launchTick > 0 && root.fxKind === "burst")
                            shockAnim.restart();
                    }
                }
            }

            // The inner wave: a tight white flash-ring that breaks before
            // the accent ring — the classic two-stage detonation.
            Rectangle {
                id: shock2

                x: root.orbC + Math.cos(root.selAng) * root.rx - 58
                y: root.orbC + Math.sin(root.selAng) * root.ry - 58
                width: 116
                height: 116
                radius: Appearance.r(58)
                color: "transparent"
                border.width: 1.5
                border.color: Colours.alpha(Colours.ink, 0.85)
                scale: 0.5
                opacity: 0
                visible: root.slotCount > 0
                z: 500

                ParallelAnimation {
                    id: shock2Anim

                    NumberAnimation {
                        target: shock2
                        property: "scale"
                        from: 0.3
                        to: 1.6
                        duration: root.ms(320)
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: shock2
                        property: "opacity"
                        from: 0.7
                        to: 0
                        duration: root.ms(320)
                        easing.type: Easing.OutQuad
                    }
                }

                Connections {
                    target: root

                    function onLaunchTickChanged(): void {
                        if (root.launchTick > 0 && root.fxKind === "burst") {
                            shock2Anim.restart();
                            flashAnim.restart();
                        }
                    }
                }
            }

            // The only time words appear below the pill: when there is
            // genuinely nothing to show.
            Item {
                id: nothingWrap

                anchors.horizontalCenter: parent.horizontalCenter
                y: root.orbC + 58
                width: 400
                height: 70
                opacity: input.text.trim() !== "" && root.results.length === 0 ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NOTHING FOUND"
                    color: Colours.inkDim
                    font.family: Appearance.fontFamily.display
                    font.pixelSize: Appearance.font.size.large
                    font.weight: Font.Black
                    font.letterSpacing: 2.2
                }

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 34
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "TRY SOMETHING ELSE"
                    color: Colours.alpha(Colours.inkDim, 0.65)
                    font.family: Appearance.fontFamily.body
                    font.pixelSize: Appearance.font.size.tiny
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.6
                }
            }

            // ------------------------------------------------------- the sun
            //  The search pill — the one thing that never orbits. When you
            //  are not typing it speaks the chosen app's name; start typing
            //  and it becomes a search box. Its left glyph is always the
            //  icon of whatever you are about to fire.
            Item {
                id: fieldWrap

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(520, root.panelW - 40)
                height: 76
                z: 1000

                // The sun settles into the room on open — a short bloom
                // from small to full, so the panel has a centre to grow
                // around.
                SequentialAnimation {
                    id: fieldSettle

                    NumberAnimation {
                        target: fieldWrap
                        property: "scale"
                        from: 0.92
                        to: 1
                        duration: 300
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }
                }

                SequentialAnimation {
                    id: pillPunch

                    NumberAnimation {
                        target: fieldWrap
                        property: "scale"
                        from: 1
                        to: 1.03
                        duration: 70
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: fieldWrap
                        property: "scale"
                        from: 1.03
                        to: 1
                        duration: 190
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.6
                    }
                }

                // The sun kicks when it fires — down and back, like recoil.
                SequentialAnimation {
                    id: fieldRecoil

                    NumberAnimation {
                        target: fieldWrap
                        property: "scale"
                        from: 1
                        to: 0.985
                        duration: 60
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: fieldWrap
                        property: "scale"
                        from: 0.985
                        to: 1
                        duration: 210
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.6
                    }
                }

                // The sun's own halo — a tight accent wash right behind the
                // pill that strengthens while you type, as if the search
                // itself were the light source.
                Shape {
                    z: -1
                    anchors.centerIn: parent
                    width: fieldWrap.width + 150
                    height: fieldWrap.height + 90

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: "transparent"
                        strokeWidth: 0

                        fillGradient: RadialGradient {
                            centerX: (fieldWrap.width + 150) / 2
                            centerY: (fieldWrap.height + 90) / 2
                            focalX: (fieldWrap.width + 150) / 2
                            focalY: (fieldWrap.height + 90) / 2
                            centerRadius: fieldWrap.width * 0.62
                            focalRadius: 0

                            GradientStop {
                                position: 0.0
                                color: Colours.alpha(Colours.accent, root.typing ? 0.17 : 0.10)
                                Behavior on color {
                                    ColorAnimation { duration: 240; easing.type: Easing.OutCubic }
                                }
                            }
                            GradientStop {
                                position: 1.0
                                color: Colours.alpha(Colours.accent, 0)
                            }
                        }

                        PathPolyline {
                            path: [
                                Qt.point(0, 0),
                                Qt.point(fieldWrap.width + 150, 0),
                                Qt.point(fieldWrap.width + 150, fieldWrap.height + 90),
                                Qt.point(0, fieldWrap.height + 90),
                                Qt.point(0, 0)
                            ]
                        }
                    }
                }

                // Grounding: the sun floats a finger above the plane — a
                // soft dark pool where its light meets the floor, dimming
                // the halo right beneath it so the pill reads as sitting
                // ON the light, not inside it.
                Shape {
                    z: -1
                    x: -50
                    y: fieldWrap.height - 14
                    width: fieldWrap.width + 100
                    height: 34

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: "transparent"
                        strokeWidth: 0

                        fillGradient: RadialGradient {
                            centerX: (fieldWrap.width + 100) / 2
                            centerY: 17
                            focalX: (fieldWrap.width + 100) / 2
                            focalY: 17
                            centerRadius: fieldWrap.width * 0.5
                            focalRadius: 0

                            GradientStop {
                                position: 0.0
                                color: Qt.rgba(0, 0, 0, 0.34)
                            }
                            GradientStop {
                                position: 1.0
                                color: Qt.rgba(0, 0, 0, 0)
                            }
                        }

                        PathPolyline {
                            path: [
                                Qt.point(0, 0),
                                Qt.point(fieldWrap.width + 100, 0),
                                Qt.point(fieldWrap.width + 100, 34),
                                Qt.point(0, 34),
                                Qt.point(0, 0)
                            ]
                        }
                    }
                }

                Rectangle {
                    id: field

                    anchors.fill: parent
                    radius: Appearance.r(999)
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Colours.mix(Colours.surfaceHigh, Colours.accent, 0.10)
                        }
                        GradientStop {
                            position: 1.0
                            color: Colours.mix(Colours.surface, Colours.accent, 0.04)
                        }
                    }
                    antialiasing: true
                    clip: true

                    // A hairline of light along the crown of the pill — the
                    // glass catching the room.
                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 24
                        height: 2
                        radius: 1
                        color: Colours.alpha(Colours.ink, root.typing ? 0.26 : 0.15)
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 26
                        anchors.rightMargin: 26
                        spacing: 14

                        Item {
                            id: glyphHolder

                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 40

                            SequentialAnimation {
                                id: pulse

                                NumberAnimation {
                                    target: glyphHolder
                                    property: "scale"
                                    from: 1
                                    to: 1.2
                                    duration: 130
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: glyphHolder
                                    property: "scale"
                                    from: 1.2
                                    to: 1
                                    duration: 320
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.6
                                }
                            }

                            IconImage {
                                anchors.centerIn: parent
                                visible: Config.launcher.showIcons && root.selected && root.selected.kind === "app" && root.selected.icon !== ""
                                implicitSize: 32
                                source: root.selected && root.selected.kind === "app" && root.selected.icon !== "" ? Quickshell.iconPath(root.selected.icon, "application-x-executable") : ""
                                asynchronous: true
                            }

                            Icon {
                                anchors.centerIn: parent
                                visible: !(Config.launcher.showIcons && root.selected && root.selected.kind === "app")
                                name: root.selected ? root.selected.icon : "search"
                                color: Colours.accent
                                font.pixelSize: 24
                            }
                        }

                        TextInput {
                            id: input

                            anchors.verticalCenter: parent.verticalCenter
                            width: field.width - 26 - 26 - 40 - 14 - 24
                            color: Colours.ink
                            font.family: Appearance.fontFamily.display
                            font.pixelSize: Appearance.font.size.huge
                            font.weight: Font.Black
                            font.letterSpacing: 0.8
                            selectionColor: Colours.accent
                            selectedTextColor: Colours.on(Colours.accent)
                            clip: true
                            leftPadding: 4

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: input.text.length === 0 && root.selected === null
                                text: "RUN…"
                                color: Colours.alpha(Colours.inkDim, 0.4)
                                font: input.font

                                // The invitation breathes — slowly, so the
                                // empty pill never reads as dead.
                                SequentialAnimation on opacity {
                                    running: input.text.length === 0 && root.selected === null
                                    loops: Animation.Infinite

                                    NumberAnimation {
                                        from: 0.6
                                        to: 1
                                        duration: 1700
                                        easing.type: Easing.InOutSine
                                    }
                                    NumberAnimation {
                                        from: 1
                                        to: 0.6
                                        duration: 1700
                                        easing.type: Easing.InOutSine
                                    }
                                }
                            }

                            Keys.onReleased: event => {
                                if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta || !(event.modifiers & Qt.AltModifier))
                                    root.altHeld = false;
                            }
                            Keys.onPressed: event => {
                                const ctrl = (event.modifiers & Qt.ControlModifier) !== 0;
                                const t = event.text;

                                // hold Alt: the planets show their numbers;
                                // Alt+1 … Alt+9 fires that one
                                if (event.key === Qt.Key_Alt) {
                                    root.altHeld = Config.launcher.quickKeys;
                                    return;
                                }
                                if ((event.modifiers & Qt.AltModifier) && Config.launcher.quickKeys && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                                    const n = event.key - Qt.Key_1;
                                    const it = n < root.slotCount ? root.orbitList[n] : null;
                                    if (it) {
                                        root.gotoIndex(root.winBase + n);
                                        root.run(it);
                                    } else {
                                        Sfx.back();
                                    }
                                    event.accepted = true;
                                    return;
                                }

                                // Typing ticks like a keypad; backspace
                                // clicks back. Feel, not noise.
                                if (!ctrl && t.length === 1 && t >= " ")
                                    Sfx.cursor();
                                if (!ctrl && event.key === Qt.Key_Backspace)
                                    Sfx.back();

                                // Ctrl+Backspace eats a whole word.
                                if (ctrl && event.key === Qt.Key_Backspace) {
                                    const txt = input.text.replace(/\S+\s*$/, "");
                                    if (txt !== input.text) {
                                        input.text = txt;
                                        Sfx.back();
                                    }
                                    event.accepted = true;
                                    return;
                                }

                                // Ctrl+J/K and Ctrl+N/P, so your hands can
                                // stay put.
                                if (ctrl) {
                                    if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                                        root.moveCursor(1);
                                        event.accepted = true;
                                        return;
                                    }
                                    if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                                        root.moveCursor(-1);
                                        event.accepted = true;
                                        return;
                                    }
                                }

                                switch (event.key) {
                                case Qt.Key_Escape:
                                    // Two-stage: first Escape clears the
                                    // query, the second leaves — the menu
                                    // is a place you back out of, not fall
                                    // out of.
                                    if (input.text !== "") {
                                        input.text = "";
                                        Sfx.back();
                                    } else {
                                        Panels.closeAll();
                                    }
                                    event.accepted = true;
                                    return;
                                case Qt.Key_Down:
                                case Qt.Key_Tab:
                                    root.moveCursor(1);
                                    event.accepted = true;
                                    return;
                                case Qt.Key_Up:
                                case Qt.Key_Backtab:
                                    root.moveCursor(-1);
                                    event.accepted = true;
                                    return;
                                case Qt.Key_Left:
                                    // Inside text the arrows edit; at the
                                    // edges they orbit.
                                    if (input.text.length > 0 && input.cursorPosition > 0) {
                                        event.accepted = false;
                                        return;
                                    }
                                    root.moveCursor(-1);
                                    event.accepted = true;
                                    return;
                                case Qt.Key_Right:
                                    if (input.text.length > 0 && input.cursorPosition < input.text.length) {
                                        event.accepted = false;
                                        return;
                                    }
                                    root.moveCursor(1);
                                    event.accepted = true;
                                    return;
                                case Qt.Key_Home:
                                    root.gotoIndex(0);
                                    event.accepted = true;
                                    return;
                                case Qt.Key_End:
                                    root.gotoIndex(root.results.length - 1);
                                    event.accepted = true;
                                    return;
                                case Qt.Key_P:
                                    // Alt+P only: a bare "p" is a letter the
                                    // user is typing ("spotify", "python").
                                    if (!(event.modifiers & Qt.AltModifier))
                                        break;
                                    // Pin the app under the cursor — pinned
                                    // apps outrank frecency forever, until
                                    // unpinned.
                                    if (root.selected && root.selected.kind === "app") {
                                        Apps.togglePin(root.selected.id);
                                        Sfx.toggle();
                                    } else {
                                        Sfx.back();
                                    }
                                    event.accepted = true;
                                    return;
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                    if (root.selected)
                                        root.run(root.selected);
                                    else
                                        Sfx.back();
                                    event.accepted = true;
                                    return;
                                }
                            }
                        }
                    }

                    // The pill's voice: the chosen app, spoken quietly.
                    // Sits over the (empty) input; start typing and it
                    // steps aside.
                    Row {
                        id: infoRow

                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 26 + 40 + 14
                        visible: input.text === "" && root.selected !== null
                        spacing: 10
                        z: 2

                        SequentialAnimation {
                            id: namePop

                            NumberAnimation {
                                target: infoRow
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: infoRow
                                    property: "scale"
                                    from: 0.96
                                    to: 1
                                    duration: 220
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.7
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, field.width - 26 - 26 - 40 - 14 - 90)
                            text: root.selected ? root.selected.name : ""
                            color: Colours.ink
                            font.family: Appearance.fontFamily.display
                            font.pixelSize: Appearance.font.size.huge
                            font.weight: Font.Black
                            font.letterSpacing: 0.8
                            elide: Text.ElideRight
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Config.launcher.subtitles && root.selected?.sub !== undefined && root.selected?.sub !== ""
                            text: root.selected ? root.selected.sub : ""
                            color: Colours.alpha(Colours.inkDim, 0.9)
                            font.family: Appearance.fontFamily.body
                            font.pixelSize: Appearance.font.size.small
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.4
                        }

                        // A small coloured dot for non-app results — enough
                        // to tell a setting from a command, without a label.
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.selected !== null && root.selected.kind !== "app"
                            width: 8
                            height: 8
                            radius: 4
                            color: root.selected?.kind === "setting" ? Colours.accentAlt : (root.selected?.kind === "exec" ? Colours.warning : Colours.accent)
                        }

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.selected?.kind === "app" && root.selected?.pinned === true
                            name: "star"
                            color: Colours.accent
                            font.pixelSize: 13
                        }
                    }

                    // The muzzle blink — a white flash inside the glass the
                    // instant the planet leaves, so the whole system fires
                    // as one thing.
                    Rectangle {
                        id: muzzleFlash

                        anchors.fill: parent
                        color: "white"
                        opacity: 0
                    }

                    SequentialAnimation {
                        id: fieldMuzzle

                        NumberAnimation {
                            target: muzzleFlash
                            property: "opacity"
                            from: 0
                            to: 0.16
                            duration: 70
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: muzzleFlash
                            property: "opacity"
                            from: 0.16
                            to: 0
                            duration: 420
                            easing.type: Easing.InOutQuad
                        }
                    }
                }

                // Scroll over the pill orbits too — for the mouse people.
                // Trackpads emit bursts of wheel events; a short gate keeps
                // one flick from flying through every result.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    property real lastWheel: 0
                    onWheel: wheel => {
                        const t = Date.now();
                        if (t - lastWheel < 90)
                            return;
                        lastWheel = t;
                        if (wheel.angleDelta.y > 0)
                            root.moveCursor(-1);
                        else
                            root.moveCursor(1);
                    }
                }
            }
        }

        // One quiet sensor for the whole panel: it feeds the parallax tilt
        // and the planets' hover glow from a single place. It accepts no
        // buttons, so clicks fall through to whatever lives beneath.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            cursorShape: root.overOrb ? Qt.PointingHandCursor : (root.overPill ? Qt.IBeamCursor : Qt.ArrowCursor)

            onPositionChanged: mouse => {
                root.mouseX = mouse.x;
                root.mouseY = mouse.y;
                const nx = Math.max(-1, Math.min(1, (mouse.x / Math.max(1, root.panelW) - 0.5) * 2));
                const ny = Math.max(-1, Math.min(1, (mouse.y / Math.max(1, panel.height) - 0.5) * 2));
                root.tiltX = nx * 2.4 * Config.launcher.orbitTilt;
                root.tiltY = -ny * 1.6 * Config.launcher.orbitTilt;
                // The text field keeps its beam cursor.
                const pillW = Math.min(520, root.panelW - 40) * root.orbitScale / 2;
                const pillH = 38 * root.orbitScale;
                root.overPill = Math.abs(mouse.x - root.panelW / 2) < pillW && Math.abs(mouse.y - root.orbC * root.orbitScale) < pillH;
            }

            onExited: {
                root.mouseX = -999;
                root.mouseY = -999;
                root.overOrb = false;
                root.overPill = false;
                root.tiltX = 0;
                root.tiltY = 0;
            }

            onWheel: wheel => {
                if (wheel.angleDelta.y > 0)
                    root.moveCursor(-1);
                else
                    root.moveCursor(1);
            }
        }
    }

    // The key line under the orbit (LAUNCHER → KEY HINTS): it comes in a
    // moment after opening and steps aside once you type.
    Text {
        anchors.horizontalCenter: panel.horizontalCenter
        y: Math.min(root.height - 40, panel.y + panel.height + 6)
        visible: Config.launcher.hints
        text: "↑ ↓  ORBIT   ·   ⏎  LAUNCH   ·   ALT+P  PIN" + (Config.launcher.quickKeys ? "   ·   ALT+1…9  QUICK" : "") + "   ·   =  MATHS   ·   " + Config.launcher.actionPrefix + "  COMMAND   ·   ESC  BACK"
        color: Colours.alpha(Colours.inkDim, 0.7)
        font.family: Appearance.fontFamily.body
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1.4
        opacity: root.entered && !root.typing && !root.launching ? 1 : 0

        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: root.entered && !root.typing ? root.ms(700) : 0 }
                NumberAnimation { duration: root.ms(260) }
            }
        }
    }

    // The launch flash — a room-wide blink, soft as a shutter, exactly on
    // the beat the planet leaves. Everything else stays quiet.
    Rectangle {
        id: flash

        anchors.fill: parent
        color: Colours.alpha(Colours.ink, 0.05)
        opacity: root.flash
        visible: root.flash > 0
    }

    SequentialAnimation {
        id: flashAnim

        NumberAnimation {
            target: root
            property: "flash"
            from: 0
            to: 1
            duration: 70
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "flash"
            from: 1
            to: 0
            duration: 420
            easing.type: Easing.InOutQuad
        }
    }
}
