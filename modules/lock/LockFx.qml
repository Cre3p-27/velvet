//  VELVET  ·  modules/lock/LockFx.qml
//  The atmosphere over a look's lock (LOCK SCREEN → VIBE FACES → EFFECT), laid
//  over the face and kept thin enough that every word stays readable:
//    stars     — points drifting up and twinkling
//    embers    — warm sparks rising and flickering out
//    rain      — fine streaks falling at a slant
//    snow      — soft flakes drifting down
//    scanlines — a CRT's lines and a slow bright band rolling down
//    grain     — film grain that shifts a few times a second
//    vignette  — the corners sink into the dark
//  and, on its own switch, GLOW: the screen's edges breathe in the accent
//  with the music (Spectrum.level).
import qs.config
import qs.services
import QtQuick

Item {
    id: root

    property string kind: "none"
    property bool glow: false
    property bool running: true
    property color tint: Colours.accent
    property real strength: 1

    readonly property real u: Math.max(0.5, Math.min(root.width / 1920, root.height / 1080))
    readonly property bool particles: ["stars", "embers", "rain", "snow"].indexOf(root.kind) >= 0

    enabled: false

    // ── particles: one Repeater, each kind its own motion
    Repeater {
        model: root.particles ? (root.kind === "rain" ? 90 : (root.kind === "snow" ? 70 : 56)) : 0

        Rectangle {
            id: p

            required property int index

            // a stable random per particle
            readonly property real r1: ((index * 9301 + 49297) % 233280) / 233280
            readonly property real r2: ((index * 4271 + 1013) % 7919) / 7919
            readonly property real r3: ((index * 7717 + 31) % 1009) / 1009
            readonly property bool rising: root.kind === "stars" || root.kind === "embers"
            readonly property real travel: root.height * (root.kind === "rain" ? 1.25 : 1.15)
            property real phase: 0
            readonly property real t: (p.phase + p.r3) % 1

            width: root.kind === "rain" ? Math.max(1, 1.4 * root.u) : (root.kind === "snow" ? (3 + p.r2 * 5) * root.u : (root.kind === "embers" ? (2 + p.r2 * 3.5) * root.u : (1.5 + p.r2 * 2.5) * root.u))
            height: root.kind === "rain" ? (26 + p.r2 * 30) * root.u : width
            radius: root.kind === "rain" ? width / 2 : width / 2
            rotation: root.kind === "rain" ? 14 : 0
            color: root.kind === "embers" ? Qt.rgba(1, 0.55 + p.r2 * 0.3, 0.2, 1) : (root.kind === "stars" ? Qt.tint("#ffffff", Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.35 * p.r2)) : Qt.rgba(1, 1, 1, 1))
            x: root.width * p.r1 + (root.kind === "rain" ? -p.t * root.height * 0.25 : Math.sin((p.t + p.r2) * Math.PI * 2) * 30 * root.u)
            y: p.rising ? root.height + 20 - p.t * p.travel : -40 + p.t * p.travel
            opacity: {
                const fade = Math.min(1, Math.min(p.t, 1 - p.t) * 6);
                const base = root.kind === "rain" ? 0.22 : (root.kind === "snow" ? 0.55 : (root.kind === "embers" ? 0.75 : 0.6));
                const twinkle = root.kind === "stars" || root.kind === "embers" ? 0.55 + 0.45 * Math.sin((p.t * 9 + p.r1 * 6) * Math.PI) : 1;
                return Math.max(0, fade * base * twinkle * root.strength);
            }

            NumberAnimation on phase {
                running: root.running && root.particles
                from: 0
                to: 1
                duration: (root.kind === "rain" ? 900 + p.r2 * 500 : (root.kind === "snow" ? 14000 + p.r2 * 9000 : (root.kind === "embers" ? 7000 + p.r2 * 6000 : 16000 + p.r2 * 14000)))
                loops: Animation.Infinite
            }
        }
    }

    // ── scanlines and the rolling band
    Item {
        anchors.fill: parent
        visible: root.kind === "scanlines"
        opacity: root.strength

        Repeater {
            model: root.kind === "scanlines" ? Math.ceil(root.height / Math.max(2, 3 * root.u)) : 0

            Rectangle {
                required property int index

                y: index * Math.max(2, 3 * root.u)
                width: root.width
                height: 1
                color: Qt.rgba(0, 0, 0, 0.18)
            }
        }
        Rectangle {
            id: band

            width: root.width
            height: root.height * 0.16
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.045) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
            }

            NumberAnimation on y {
                running: root.running && root.kind === "scanlines"
                from: -root.height * 0.2
                to: root.height
                duration: 6500
                loops: Animation.Infinite
            }
        }
    }

    // ── grain: a few hundred specks, reshuffled a few times a second
    Item {
        id: grain

        anchors.fill: parent
        visible: root.kind === "grain"
        property int seed: 0

        Timer {
            running: root.running && root.kind === "grain"
            interval: 110
            repeat: true
            onTriggered: grain.seed = (grain.seed + 1) % 997
        }
        Repeater {
            model: root.kind === "grain" ? 420 : 0

            Rectangle {
                required property int index

                readonly property real a: ((index * 9301 + grain.seed * 49297) % 233280) / 233280
                readonly property real b: ((index * 4271 + grain.seed * 7919) % 104729) / 104729

                x: a * root.width
                y: b * root.height
                width: Math.max(1, 1.6 * root.u)
                height: width
                color: (index + grain.seed) % 2 === 0 ? Qt.rgba(1, 1, 1, 0.09 * root.strength) : Qt.rgba(0, 0, 0, 0.14 * root.strength)
            }
        }
    }

    // ── vignette: four soft edges
    Item {
        anchors.fill: parent
        visible: root.kind === "vignette"
        opacity: 0.85 * root.strength

        Rectangle {
            width: parent.width
            height: parent.height * 0.32
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.6) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
            }
        }
        Rectangle {
            y: parent.height * 0.68
            width: parent.width
            height: parent.height * 0.32
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.65) }
            }
        }
        Rectangle {
            width: parent.width * 0.22
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.5) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0) }
            }
        }
        Rectangle {
            x: parent.width * 0.78
            width: parent.width * 0.22
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.5) }
            }
        }
    }

    // ── glow: the edges breathe with the music
    Item {
        id: glowLayer

        anchors.fill: parent
        visible: root.glow
        // the music, or a slow breath while it is quiet
        property real breath: 0
        readonly property real level: Spectrum.live ? Math.min(1, Spectrum.level * 1.4) : 0.18 + 0.12 * glowLayer.breath
        opacity: 0.25 + 0.75 * glowLayer.level

        Behavior on opacity {
            NumberAnimation { duration: 90 }
        }
        SequentialAnimation on breath {
            running: root.running && root.glow
            loops: Animation.Infinite
            NumberAnimation { from: 0; to: 1; duration: 2400; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1; to: 0; duration: 2400; easing.type: Easing.InOutSine }
        }

        readonly property color c0: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0)
        readonly property color c1: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.55)

        Rectangle {
            width: parent.width
            height: parent.height * 0.14
            gradient: Gradient {
                GradientStop { position: 0; color: glowLayer.c1 }
                GradientStop { position: 1; color: glowLayer.c0 }
            }
        }
        Rectangle {
            y: parent.height * 0.86
            width: parent.width
            height: parent.height * 0.14
            gradient: Gradient {
                GradientStop { position: 0; color: glowLayer.c0 }
                GradientStop { position: 1; color: glowLayer.c1 }
            }
        }
        Rectangle {
            width: parent.width * 0.08
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: glowLayer.c1 }
                GradientStop { position: 1; color: glowLayer.c0 }
            }
        }
        Rectangle {
            x: parent.width * 0.92
            width: parent.width * 0.08
            height: parent.height
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: glowLayer.c0 }
                GradientStop { position: 1; color: glowLayer.c1 }
            }
        }
    }
}
