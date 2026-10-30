//  VELVET  ·  modules/island/VellyFace.qml
//  Velly herself (VELLY → FACE → VELVET): a little ball of velvet — dark
//  where it faces you, glowing at its rim, a fuzz round its edge — drawn by
//  one shader (assets/shaders/velvet.frag); this file decides what she does.
//
//    READY      she bobs, blinks now and then, looks where your pointer is
//               (or about the room when it is away); her fuzz breathes.
//    LISTENING  eyes wide open, her fuzz stands up with your voice.
//    THINKING   she looks up and aside and kneads herself; a sheen runs round.
//    SPEAKING   a mouth opens with the audio she is playing, the fuzz rides
//               it too; she smiles a little.
//    DONE       a happy squint (^ ^) and a hop when an answer has landed.
//    ERROR      crossed-out eyes, the fuzz lies down.
//    WAKING     she squashes, springs up, a ring runs out of her.
//    ASLEEP     eyes shut.
//  Click her: she giggles and squishes; three quick clicks and she spins.
//  Pet her (move the pointer over her): she blushes, purrs, hearts float up.
//  Music playing while she rests: she bobs along. Left alone a while: a yawn.
//  Asleep: little bubbles. Talking or listening: she glows from inside.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    // false while nobody can see it: the clock and the levels rest
    property bool onScreen: true
    // where the hand is, in this item's coordinates (null: not over the module)
    property var pointer: null

    readonly property string phase: Velly.phase
    readonly property bool asleep: root.phase === "off"
    readonly property bool hearing: root.phase === "listening" || root.phase === "hearing"
    readonly property bool thinking: root.phase === "thinking"
    readonly property bool speaking: root.phase === "speaking"
    readonly property bool failed: root.phase === "error"

    implicitWidth: 180
    implicitHeight: 180

    // ── what the face does, each on its own soft curve
    property real open: (root.asleep ? 0.06 : (root.thinking ? 0.82 : 1)) * (1 - 0.85 * root.yawn)
    // happy: an answer landed, you petted her, or the music is good
    property real smile: root.happy || root.love > 0.6 || root.dance > 0.35 ? 1 : 0
    property real cross: root.failed ? 1 : 0
    property real wide: root.hearing ? 1 : 0
    property real think: root.thinking ? 1 : 0
    property real cheeks: root.asleep || root.failed ? 0 : Math.min(1, (root.speaking || root.happy ? 1 : 0.55) + root.love)
    property real mouthOpen: root.speaking ? 1 : root.yawn
    // her inner light: brighter while she listens and talks
    property real glow: root.speaking ? 0.55 : (root.hearing ? 0.4 : (root.thinking ? 0.25 : 0.1))

    Behavior on glow {
        NumberAnimation {
            duration: 400
        }
    }
    property real halo: root.asleep ? 0.25 : (root.failed ? 0.3 : 1)
    property real energy: root.hearing || root.speaking ? 1 : 0
    property real wake: 1

    // a blink closes the lids over whatever the eyes are doing
    property real lid: 1

    Behavior on open {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.6
        }
    }
    Behavior on smile {
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutBack
        }
    }
    Behavior on cross {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    Behavior on wide {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutBack
            easing.overshoot: 2.2
        }
    }
    Behavior on think {
        NumberAnimation {
            duration: 360
            easing.type: Easing.OutCubic
        }
    }
    Behavior on cheeks {
        NumberAnimation {
            duration: 420
        }
    }
    Behavior on mouthOpen {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    Behavior on halo {
        NumberAnimation {
            duration: 500
            easing.type: Easing.OutCubic
        }
    }
    Behavior on energy {
        NumberAnimation {
            duration: 300
        }
    }

    // ── happy: a squint when an answer has landed
    property bool happy: false

    Timer {
        id: happyFor

        interval: 1900
        onTriggered: root.happy = false
    }

    property string lastPhase: root.phase

    onPhaseChanged: {
        const was = root.lastPhase;
        root.lastPhase = root.phase;
        if (root.phase === "ready" && (was === "speaking" || was === "thinking")) {
            root.happy = true;
            happyFor.restart();
        } else if (root.phase !== "ready") {
            root.happy = false;
        }
        // waking: one ripple out of the middle
        if (was === "off" && root.phase !== "off") {
            ripple.restart();
            hop.restart();
            Sfx.chirp("wake");
        }
        // her little sounds for what she does
        if (root.onScreen) {
            if (root.hearing && !(was === "listening" || was === "hearing") && was !== "off")
                Sfx.chirp("listen");
            else if (root.thinking && (was === "listening" || was === "hearing"))
                Sfx.chirp("heard");
            else if (root.happy)
                Sfx.chirp("done");
            else if (root.failed)
                Sfx.chirp("error");
        }
        if (root.happy)
            hop.restart();
    }

    // ── her body: a squash and a spring back (waking, a happy hop, a squeeze)
    property real squash: 0

    SequentialAnimation {
        id: hop

        NumberAnimation {
            target: root
            property: "squash"
            to: -0.8
            duration: 110
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "squash"
            to: 0.55
            duration: 150
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: root
            property: "squash"
            to: 0
            duration: 520
            easing.type: Easing.OutElastic
            easing.amplitude: 1.2
            easing.period: 0.4
        }
    }

    // ── click her: a giggle and a squish; three quick ones and she spins
    property int taps: 0
    property real spin: 0

    TapHandler {
        onTapped: {
            hop.restart();
            Sfx.chirp("giggle");
            root.taps++;
            tapWindow.restart();
            if (root.taps >= 3) {
                root.taps = 0;
                spinAnim.restart();
                root.love = 1;
            }
        }
    }

    Timer {
        id: tapWindow

        interval: 650
        onTriggered: root.taps = 0
    }

    NumberAnimation {
        id: spinAnim

        target: root
        property: "spin"
        from: 0
        to: 360
        duration: 900
        easing.type: Easing.OutBack
        easing.overshoot: 1.4
    }

    // ── pet her: the pointer moving over her warms her up
    property real love: 0
    property point lastPet: Qt.point(-1, -1)
    property double lastPurr: 0

    onPointerChanged: {
        const p = root.pointer;
        if (!p) {
            root.lastPet = Qt.point(-1, -1);
            return;
        }
        root.idleFor = 0;
        const near = Math.hypot(p.x - root.width / 2, p.y - root.height / 2) < root.width * 0.32;
        if (near && root.lastPet.x >= 0) {
            root.love = Math.min(1, root.love + Math.hypot(p.x - root.lastPet.x, p.y - root.lastPet.y) / 900);
            if (root.love > 0.55 && Date.now() - root.lastPurr > 3500) {
                root.lastPurr = Date.now();
                Sfx.chirp("purr");
            }
        }
        root.lastPet = near ? p : Qt.point(-1, -1);
    }

    // ── left alone: now and then a yawn
    property real idleFor: 0
    property real yawn: 0

    SequentialAnimation {
        id: yawnAnim

        NumberAnimation {
            target: root
            property: "yawn"
            to: 1
            duration: 900
            easing.type: Easing.InOutSine
        }
        PauseAnimation {
            duration: 500
        }
        NumberAnimation {
            target: root
            property: "yawn"
            to: 0
            duration: 700
            easing.type: Easing.InOutSine
        }
    }

    NumberAnimation {
        id: ripple

        target: root
        property: "wake"
        from: 0
        to: 1
        duration: 900
        easing.type: Easing.OutCubic
    }

    // ── blinking: now and then, sometimes twice
    SequentialAnimation {
        id: blink

        NumberAnimation {
            target: root
            property: "lid"
            to: 0.05
            duration: 70
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: root
            property: "lid"
            to: 1
            duration: 120
            easing.type: Easing.OutBack
        }
    }

    Timer {
        running: root.onScreen && !root.asleep && !root.failed
        interval: 2600 + Math.random() * 3400
        repeat: true
        onTriggered: {
            interval = 2600 + Math.random() * 3400;
            if (root.happy)
                return;
            blink.restart();
            if (Math.random() < 0.2)
                twice.restart();
        }
    }

    Timer {
        id: twice

        interval: 230
        onTriggered: blink.restart()
    }

    // ── where she looks: at your pointer, else about the room
    property point wander: Qt.point(0, 0)

    Timer {
        running: root.onScreen && root.pointer === null && !root.asleep
        interval: 2400
        repeat: true
        onTriggered: {
            interval = 1800 + Math.random() * 3200;
            root.wander = Math.random() < 0.3 ? Qt.point(0, 0) : Qt.point((Math.random() * 2 - 1) * 1.6, (Math.random() * 2 - 1) * 0.7);
        }
    }

    readonly property point gazeTarget: {
        if (root.thinking)
            return Qt.point(1.5, -1.3);
        if (root.asleep)
            return Qt.point(0, 0.6);
        if (root.pointer) {
            const dx = (root.pointer.x - root.width / 2) / 34;
            const dy = (root.pointer.y - root.height / 2) / 40;
            return Qt.point(Math.max(-2.2, Math.min(2.2, dx)), Math.max(-1.8, Math.min(1.4, dy)));
        }
        return root.wander;
    }

    Spring {
        id: gazeX

        to: root.gazeTarget.x
        spring: 4.5
        damping: 0.42
        epsilon: 0.01
    }

    Spring {
        id: gazeY

        to: root.gazeTarget.y
        spring: 4.5
        damping: 0.42
        epsilon: 0.01
    }

    // ── the levels: the voice (hers or yours) for the halo and the mouth
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var bars: [0, 0, 0, 0, 0, 0, 0, 0]

    function sample(): void {
        const b = [];
        const m = [];
        if (root.hearing) {
            for (let i = 0; i < 16; i++)
                b.push(Math.min(1, Velly.band(i, 16) * 1.25));
        } else if (root.speaking) {
            const n = 64;
            const at = Math.floor(Math.max(0, Math.min(1, Velly.speakProgress)) * n);
            for (let j = 0; j < 8; j++)
                m.push(Math.min(1, Velly.mouthAt(Math.max(0, Math.min(n - 1, at + j - 4)), n) * 1.15));
            for (let i = 0; i < 16; i++)
                b.push(Math.min(1, Velly.mouthAt(Math.max(0, Math.min(n - 1, at - i)), n) * (1.1 - i * 0.03)));
        }
        root.bands = b.length === 16 ? b : root.bands.map(v => v * 0.85);
        root.bars = m.length === 8 ? m : root.bars.map(v => v * 0.7);
    }

    // music playing while she rests: she bobs along
    readonly property bool resting: root.phase === "ready" || root.phase === "off"
    property real dance: 0

    FrameAnimation {
        running: root.onScreen
        onTriggered: {
            shader.time += frameTime;
            if (root.hearing || root.speaking || root.bands[0] > 0.01 || root.bars[0] > 0.01)
                root.sample();
            // love cools down, slowly
            root.love = Math.max(0, root.love - frameTime * 0.12);
            const playing = Lyrics.bridge?.playing ?? false;
            const beat = root.resting && playing ? Math.max(0, (Spectrum.level ?? 0) - 0.25) : 0;
            root.dance += (beat * 1.1 - root.dance) * Math.min(1, frameTime * 14);
            // a yawn after a while with nothing going on
            if (root.phase === "ready" && !root.pointer && !playing) {
                root.idleFor += frameTime;
                if (root.idleFor > 28 && !yawnAnim.running) {
                    root.idleFor = 0;
                    yawnAnim.restart();
                }
            } else {
                root.idleFor = 0;
            }
        }
    }

    ShaderEffect {
        id: shader

        anchors.fill: parent

        property real px: 2 / Math.max(1, width)
        property real time: 0
        property real squash: Math.max(-1, Math.min(1, root.squash - root.dance))
        // her colours: a deep velvet of the accent, its rim lit, white eyes
        property color deep: Colours.mix(Colours.accent, "#05040a", 0.62)
        property color sheen: Colours.mix(Colours.accent, "#ffffff", 0.38)
        property color ink: Qt.rgba(1, 0.985, 0.97, 1)
        property color blush: Colours.alpha(Colours.mix(Colours.accent, "#ff6f9a", 0.6), 0.9)
        property vector4d eye: Qt.vector4d(root.open * root.lid, root.smile, root.cross, root.wide)
        property vector4d look: Qt.vector4d(gazeX.value / 2.2, gazeY.value / 1.8, root.cheeks, root.mouthOpen)
        // (a yawn opens her mouth wide)
        property vector4d mouthA: Qt.vector4d(root.bars[0] + root.yawn, root.bars[1] + root.yawn, root.bars[2] + root.yawn, root.bars[3] + root.yawn)
        property vector4d mouthB: Qt.vector4d(root.bars[4] + root.yawn, root.bars[5] + root.yawn, root.bars[6] + root.yawn, root.bars[7] + root.yawn)
        property vector4d haloA: Qt.vector4d(root.bands[0], root.bands[1], root.bands[2], root.bands[3])
        property vector4d haloB: Qt.vector4d(root.bands[4], root.bands[5], root.bands[6], root.bands[7])
        property vector4d haloC: Qt.vector4d(root.bands[8], root.bands[9], root.bands[10], root.bands[11])
        property vector4d haloD: Qt.vector4d(root.bands[12], root.bands[13], root.bands[14], root.bands[15])
        property vector4d mode: Qt.vector4d(root.think, Config.velly.faceHalo ? root.halo : 0, root.energy, root.wake)
        // tilt (curious, towards your pointer) · love · sleep · her inner light
        property vector4d extra: Qt.vector4d(gazeX.value * 0.05 * (root.pointer ? 1 : 0.4), root.love, root.asleep ? 1 : 0, root.glow)
        rotation: root.spin

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/velvet.frag.qsb")
    }
}
