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
//  Click her: she squishes.
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
    property real open: root.asleep ? 0.06 : (root.thinking ? 0.82 : 1)
    property real smile: root.happy ? 1 : 0
    property real cross: root.failed ? 1 : 0
    property real wide: root.hearing ? 1 : 0
    property real think: root.thinking ? 1 : 0
    property real cheeks: root.asleep || root.failed ? 0 : (root.speaking || root.happy ? 1 : 0.55)
    property real mouthOpen: root.speaking ? 1 : 0
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

    TapHandler {
        onTapped: {
            hop.restart();
            Sfx.pop();
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

    FrameAnimation {
        running: root.onScreen
        onTriggered: {
            shader.time += frameTime;
            if (root.hearing || root.speaking || root.bands[0] > 0.01 || root.bars[0] > 0.01)
                root.sample();
        }
    }

    ShaderEffect {
        id: shader

        anchors.fill: parent

        property real px: 2 / Math.max(1, width)
        property real time: 0
        property real squash: root.squash
        // her colours: a deep velvet of the accent, its rim lit, white eyes
        property color deep: Colours.mix(Colours.accent, "#05040a", 0.62)
        property color sheen: Colours.mix(Colours.accent, "#ffffff", 0.38)
        property color ink: Qt.rgba(1, 0.985, 0.97, 1)
        property color blush: Colours.alpha(Colours.mix(Colours.accent, "#ff6f9a", 0.6), 0.9)
        property vector4d eye: Qt.vector4d(root.open * root.lid, root.smile, root.cross, root.wide)
        property vector4d look: Qt.vector4d(gazeX.value / 2.2, gazeY.value / 1.8, root.cheeks, root.mouthOpen)
        property vector4d mouthA: Qt.vector4d(root.bars[0], root.bars[1], root.bars[2], root.bars[3])
        property vector4d mouthB: Qt.vector4d(root.bars[4], root.bars[5], root.bars[6], root.bars[7])
        property vector4d haloA: Qt.vector4d(root.bands[0], root.bands[1], root.bands[2], root.bands[3])
        property vector4d haloB: Qt.vector4d(root.bands[4], root.bands[5], root.bands[6], root.bands[7])
        property vector4d haloC: Qt.vector4d(root.bands[8], root.bands[9], root.bands[10], root.bands[11])
        property vector4d haloD: Qt.vector4d(root.bands[12], root.bands[13], root.bands[14], root.bands[15])
        property vector4d mode: Qt.vector4d(root.think, Config.velly.faceHalo ? root.halo : 0, root.energy, root.wake)

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/velvet.frag.qsb")
    }
}
