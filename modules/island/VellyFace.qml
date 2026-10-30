//  VELVET  ·  modules/island/VellyFace.qml
//  Velly's face (VELLY → FACE → DOTS): a round dot-matrix display, like a
//  little device sitting in the capsule. The dots are drawn by one shader
//  (assets/shaders/dotface.frag); this file decides what the face does.
//
//    READY      she blinks now and then, looks where your pointer is (or
//               about the room when it is away), cheeks warm; the halo of
//               dot rays round the display breathes in a slow wave.
//    LISTENING  eyes wide open, the halo rides your voice (bin/velvet-ears).
//    THINKING   she looks up and aside, a comet of dots runs round the rim.
//    SPEAKING   a mouth of dot bars moves with the audio she is playing, the
//               halo rides it too; she smiles a little.
//    DONE       a happy squint (^ ^) when an answer has landed.
//    ERROR      crossed-out eyes, the halo goes quiet.
//    WAKING     a ripple runs out from the middle of the display.
//    ASLEEP     eyes shut, the display dim.
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
    property real smile: root.happy ? 1 : (root.speaking ? 0.3 : 0)
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
        if (was === "off" && root.phase !== "off")
            ripple.restart();
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
        property real grid: [17, 21, 25].indexOf(Config.velly.faceDots) >= 0 ? Config.velly.faceDots : 21
        // the display stays a dark little device in every look: white dots,
        // the accent for the warm bits
        property color ink: Qt.rgba(1, 0.98, 0.96, 0.96)
        property color off: Qt.rgba(1, 1, 1, 0.075)
        property color hot: Colours.accent
        property color glass: Qt.rgba(0.035, 0.032, 0.04, 0.94)
        property vector4d eye: Qt.vector4d(root.open * root.lid, root.smile, root.cross, root.wide)
        property vector4d look: Qt.vector4d(gazeX.value, gazeY.value, root.cheeks, root.mouthOpen)
        property vector4d mouthA: Qt.vector4d(root.bars[0], root.bars[1], root.bars[2], root.bars[3])
        property vector4d mouthB: Qt.vector4d(root.bars[4], root.bars[5], root.bars[6], root.bars[7])
        property vector4d haloA: Qt.vector4d(root.bands[0], root.bands[1], root.bands[2], root.bands[3])
        property vector4d haloB: Qt.vector4d(root.bands[4], root.bands[5], root.bands[6], root.bands[7])
        property vector4d haloC: Qt.vector4d(root.bands[8], root.bands[9], root.bands[10], root.bands[11])
        property vector4d haloD: Qt.vector4d(root.bands[12], root.bands[13], root.bands[14], root.bands[15])
        property vector4d mode: Qt.vector4d(root.think, Config.velly.faceHalo ? root.halo : 0, root.energy, root.wake)

        fragmentShader: Qt.resolvedUrl("../../assets/shaders/dotface.frag.qsb")
    }
}
