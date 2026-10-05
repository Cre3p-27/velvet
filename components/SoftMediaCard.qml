//  VELVET  ·  components/SoftMediaCard.qml
//  The soft looks' music card — the SOFT lock's and the SOFT desktop
//  widget's: the cover in a wavy frame with the track as a ring round it,
//  the title, five buttons (previous · back 10 s · play/pause · forward
//  10 s · next) and a squiggle that is the timeline (click to seek).
//
//  It reads the shell's one player choice (Lyrics.bridge) and polls the
//  position only while it is shown and something plays.
import qs.config
import qs.services
import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects as GE

Rectangle {
    id: mc

    // The look's unit (the lock passes its screen scale) and its colours.
    property real u: 1
    property color tone: Colours.surfaceHigh
    property color toneHigh: Colours.surfaceHigh
    property color accent: Colours.accent
    property color onAccent: Colours.on(Colours.accent)
    property string family: Appearance.fontFamily.soft
    // Off: a picture (the settings' preview) — nothing reacts.
    property bool interactive: true
    property bool compact: false
    // A chevron that asks the owner to fold the card away again.
    property bool collapsible: false
    property real fillOpacity: 0.96
    // The cover's frame: any M3Shape kind, and a slow turn if wanted.
    property string coverShape: "wavy"
    property real coverSpin: 0

    signal collapse

    readonly property var mp: Lyrics.bridge
    readonly property bool has: (mc.mp?.has ?? false) && (mc.mp?.title ?? "") !== ""
    property real pos: 0
    readonly property real frac: (mc.mp?.length ?? 0) > 0 ? Math.max(0, Math.min(1, mc.pos / mc.mp.length)) : 0
    readonly property real art: (mc.compact ? 108 : 150) * mc.u

    implicitWidth: (mc.compact ? 384 : 556) * mc.u
    implicitHeight: mc.art + 36 * mc.u
    radius: 26 * mc.u
    color: Colours.alpha(mc.tone, mc.fillOpacity)
    antialiasing: true

    function clockOf(sec: real): string {
        const t = Math.max(0, Math.floor(sec || 0));
        const m = Math.floor(t / 60);
        return `${m}:${String(t % 60).padStart(2, "0")}`;
    }

    function nudge(sec: real): void {
        const p = mc.mp?.player;
        if (!p || !p.canSeek || !(p.length > 0))
            return;
        p.position = Math.max(0, Math.min(p.length, (p.position ?? 0) + sec));
        mc.pos = p.position;
    }

    Timer {
        interval: 1000
        repeat: true
        running: mc.visible && mc.has && (mc.mp?.playing ?? false)
        triggeredOnStart: true
        onTriggered: mc.pos = mc.mp ? mc.mp.position() : 0
    }

    // A paused track has a position too.
    Component.onCompleted: mc.pos = mc.mp ? mc.mp.position() : 0
    onHasChanged: mc.pos = mc.mp ? mc.mp.position() : 0

    // ── the cover in its wavy frame, with the ring that is the track
    Item {
        id: cover

        x: 18 * mc.u
        anchors.verticalCenter: parent.verticalCenter
        width: mc.art
        height: mc.art

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Colours.alpha(Colours.ink, 0.12)
                strokeWidth: 3 * mc.u
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: cover.width / 2
                    centerY: cover.height / 2
                    radiusX: cover.width / 2 - 3 * mc.u
                    radiusY: radiusX
                    startAngle: 0
                    sweepAngle: 360
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: mc.accent
                strokeWidth: 3.5 * mc.u
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: cover.width / 2
                    centerY: cover.height / 2
                    radiusX: cover.width / 2 - 3 * mc.u
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: 360 * mc.frac
                }
            }
        }

        Item {
            id: artBox

            anchors.centerIn: parent
            width: parent.width - 18 * mc.u
            height: width
            layer.enabled: true
            layer.effect: GE.OpacityMask {
                maskSource: M3Shape {
                    width: artBox.width
                    height: artBox.height
                    kind: mc.coverShape
                    color: "white"
                    intro: false
                    spin: mc.coverSpin
                }
            }

            Rectangle {
                anchors.fill: parent
                color: mc.toneHigh

                Icon {
                    anchors.centerIn: parent
                    name: "music_note"
                    color: mc.accent
                    font.pixelSize: parent.width * 0.35
                }
            }

            Image {
                anchors.fill: parent
                source: mc.mp?.artUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 256
                sourceSize.height: 256
            }
        }
    }

    Column {
        x: cover.x + cover.width + 20 * mc.u
        anchors.verticalCenter: parent.verticalCenter
        width: mc.width - x - 18 * mc.u
        spacing: 10 * mc.u

        Item {
            width: parent.width
            height: titleText.height

            Text {
                id: titleText

                width: parent.width - (mc.collapsible ? 28 * mc.u : 0)
                elide: Text.ElideRight
                text: mc.has ? ((mc.mp.artist ?? "") !== "" ? `${mc.mp.title} - ${mc.mp.artist}` : mc.mp.title) : "Nothing playing"
                color: Colours.ink
                font.family: mc.family
                font.pixelSize: (mc.compact ? 13 : 16) * mc.u
                font.weight: Font.DemiBold
            }
            Icon {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: mc.collapsible
                name: "expand_less"
                color: Colours.ink
                font.pixelSize: 20 * mc.u

                TapHandler {
                    enabled: mc.interactive
                    onTapped: mc.collapse()
                }
            }
        }

        // prev · back 10 s · play/pause · forward 10 s · next
        Row {
            spacing: 6 * mc.u

            Repeater {
                model: [["skip_previous", "prev"], ["fast_rewind", "back"], ["", "play"], ["fast_forward", "fwd"], ["skip_next", "next"]]

                Rectangle {
                    id: mb

                    required property var modelData
                    readonly property bool main: mb.modelData[1] === "play"

                    width: (mb.main ? 52 : 30) * mc.u
                    height: (mb.main ? 34 : 30) * mc.u
                    anchors.verticalCenter: parent.verticalCenter
                    radius: (mb.main ? 12 : 15) * mc.u
                    color: mb.main ? mc.accent : (mbHover.hovered ? Colours.alpha(Colours.ink, 0.1) : "transparent")
                    scale: mbTap.pressed ? 0.9 : 1
                    antialiasing: true

                    Behavior on scale {
                        NumberAnimation {
                            duration: 110
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: mb.main ? ((mc.mp?.playing ?? false) ? "pause" : "play_arrow") : mb.modelData[0]
                        color: mb.main ? mc.onAccent : Colours.alpha(Colours.ink, 0.85)
                        font.pixelSize: (mb.main ? 20 : 17) * mc.u
                        filled: true
                    }

                    HoverHandler {
                        id: mbHover

                        enabled: mc.interactive
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        id: mbTap

                        enabled: mc.interactive && mc.has
                        onTapped: {
                            switch (mb.modelData[1]) {
                            case "prev":
                                mc.mp.prev();
                                break;
                            case "next":
                                mc.mp.next();
                                break;
                            case "back":
                                mc.nudge(-10);
                                break;
                            case "fwd":
                                mc.nudge(10);
                                break;
                            default:
                                mc.mp.toggle();
                            }
                        }
                    }
                }
            }
        }

        // The squiggle: a wave up to where the song is, a hairline after.
        Item {
            id: squiggle

            width: parent.width
            height: 12 * mc.u

            readonly property real done: squiggle.width * mc.frac
            readonly property var wave: {
                const pts = [];
                const amp = 3 * mc.u;
                const wl = 14 * mc.u;
                const steps = Math.max(2, Math.ceil(squiggle.done / (2 * mc.u)));
                for (let i = 0; i <= steps; i++) {
                    const x = squiggle.done * i / steps;
                    pts.push(Qt.point(x, squiggle.height / 2 + Math.sin(x / wl * Math.PI * 2) * amp));
                }
                return pts;
            }

            Plate {
                x: squiggle.done
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, squiggle.width - squiggle.done)
                height: 2 * mc.u
                radius: Appearance.pill(height)
                color: Colours.alpha(Colours.ink, 0.16)
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colours.alpha(Colours.ink, 0.85)
                    strokeWidth: 2.2 * mc.u
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    PathPolyline {
                        path: squiggle.wave
                    }
                }
            }

            Rectangle {
                x: squiggle.done - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 3 * mc.u
                height: 14 * mc.u
                radius: width / 2
                color: Colours.ink
            }

            MouseArea {
                anchors.fill: parent
                enabled: mc.interactive && mc.has
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    mc.mp.seek(mouse.x / squiggle.width);
                    mc.pos = mc.mp.position();
                }
            }
        }

        Text {
            visible: !mc.compact
            text: `${mc.clockOf(mc.pos)} / ${mc.clockOf(mc.mp?.length ?? 0)}`
            color: Colours.alpha(Colours.ink, 0.55)
            font.family: mc.family
            font.pixelSize: 11 * mc.u
        }
    }
}
