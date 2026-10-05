//  VELVET  ·  modules/island/IslandMusic.qml
//  The NOW PLAYING body of the Dynamic Island. Receives the MPRIS bridge
//  from Island.qml — no MPRIS import here, so this file stays harmless in a
//  build without the service (the island simply says NOTHING PLAYING).
//
//  The island is ALWAYS black, whatever the wallpaper: all text rides on
//  ink (the palette's light text) and never on paper (its dark one).
//
//  The transport is three clear steps of weight: two bare skip glyphs, one
//  accent circle. Pressing dips a button fast (70 ms) and it springs back
//  with a little overshoot; the play circle ripples from exactly where the
//  click landed, so a press feels like it arrived, not merely registered.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var bridge: null

    readonly property bool has: root.bridge?.has ?? false
    readonly property string title: root.bridge?.title ?? ""
    readonly property string artist: root.bridge?.artist ?? ""
    readonly property string album: root.bridge?.album ?? ""
    readonly property bool playing: root.bridge?.playing ?? false
    readonly property real length: root.bridge?.length ?? 0
    readonly property string artUrl: root.bridge?.artUrl ?? ""

    // MPRIS position is a poll, not a stream — read it every beat, exactly
    // like Lyrics does.
    property real pos: 0

    Timer {
        running: root.has
        interval: 900
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pos = root.bridge.position()
    }

    readonly property real frac: root.length > 0 ? Math.max(0, Math.min(1, root.pos / root.length)) : 0

    function fmt(seconds: real): string {
        if (!(seconds > 0))
            return "0:00";
        const m = Math.floor(seconds / 60);
        const s = Math.floor(seconds % 60);
        return `${m}:${s < 10 ? "0" + s : s}`;
    }

    anchors.fill: parent

    // ─────────────────────────────────────────────────────────── while playing
    Item {
        anchors.fill: parent
        visible: root.has

        // ── the cover, square against the black sheet
        Plate {
            id: cover

            x: 20
            y: 20
            width: 64
            height: 64
            radius: Appearance.r(15)
            color: Colours.alpha(Colours.ink, 0.1)
            clip: true
            antialiasing: true

            Image {
                anchors.fill: parent
                visible: root.artUrl !== ""
                source: root.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }

            Icon {
                anchors.centerIn: parent
                visible: root.artUrl === ""
                name: "music_note"
                color: Colours.alpha(Colours.ink, 0.45)
                font.pixelSize: 28
            }
        }

        // ── the titles, riding on the cover's middle
        P5Text {
            x: 100
            y: 24
            width: parent.width - 100 - 20
            text: root.title
            color: Colours.ink
            font.pixelSize: Appearance.font.size.normal
            elide: Text.ElideRight
        }

        P5Text {
            x: 100
            y: 48
            width: parent.width - 100 - 20
            text: root.artist
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        P5Text {
            x: 100
            y: 68
            width: parent.width - 100 - 20
            visible: root.album.length > 0
            text: root.album.toUpperCase()
            color: Colours.alpha(Colours.inkDim, 0.7)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1
            elide: Text.ElideRight
        }

        // ── the transport — centred in the band the cover and the progress
        //    row leave open. Press dips fast, release springs back.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 164
            spacing: 40

            // SKIP BACK — bare glyph; the press flash is its whole voice.
            Item {
                id: prevBtn

                width: 44
                height: 44
                anchors.verticalCenter: parent.verticalCenter
                scale: prevMA.pressed ? 0.84 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: prevMA.pressed ? 70 : 200
                        easing.type: prevMA.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.7
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    name: "skip_previous"
                    color: prevMA.pressed ? Colours.accent : (prevHover.hovered ? Colours.ink : Colours.alpha(Colours.ink, 0.75))
                    font.pixelSize: 22

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.instant
                        }
                    }
                }

                HoverHandler {
                    id: prevHover
                }

                MouseArea {
                    id: prevMA

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: Sfx.cursor()
                    onClicked: root.bridge.prev()
                }
            }

            // PLAY / PAUSE — the accent core, with the ripple inside it.
            Item {
                id: playBtn

                width: 56
                height: 56
                anchors.verticalCenter: parent.verticalCenter
                scale: playMA.pressed ? 0.9 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: playMA.pressed ? 70 : 200
                        easing.type: playMA.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.7
                    }
                }

                Plate {
                    id: playCircle

                    anchors.fill: parent
                    radius: Appearance.r(28)
                    clip: true
                    color: playMA.pressed || playHover.hovered ? Colours.accentHot : Colours.accent
                    antialiasing: true

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.instant
                        }
                    }

                    Ripple {
                        id: playRipple

                        anchors.fill: parent
                        color: "#050505"
                        maxOpacity: 0.24
                    }

                    Icon {
                        anchors.centerIn: parent
                        // The play triangle carries its weight left of its
                        // box centre — nudge it right to sit optically true.
                        anchors.horizontalCenterOffset: root.playing ? 0 : 2
                        name: root.playing ? "pause" : "play_arrow"
                        color: "#050505"
                        font.pixelSize: 27
                    }
                }

                HoverHandler {
                    id: playHover
                }

                MouseArea {
                    id: playMA

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: Sfx.cursor()
                    onClicked: event => {
                        Sfx.select();
                        playRipple.pop(event.x, event.y);
                        root.bridge.toggle();
                    }
                }
            }

            // SKIP FORWARD — mirror of the back button.
            Item {
                id: nextBtn

                width: 44
                height: 44
                anchors.verticalCenter: parent.verticalCenter
                scale: nextMA.pressed ? 0.84 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: nextMA.pressed ? 70 : 200
                        easing.type: nextMA.pressed ? Easing.OutQuad : Easing.OutBack
                        easing.overshoot: 1.7
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    name: "skip_next"
                    color: nextMA.pressed ? Colours.accent : (nextHover.hovered ? Colours.ink : Colours.alpha(Colours.ink, 0.75))
                    font.pixelSize: 22

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.instant
                        }
                    }
                }

                HoverHandler {
                    id: nextHover
                }

                MouseArea {
                    id: nextMA

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: Sfx.cursor()
                    onClicked: root.bridge.next()
                }
            }
        }

        // ── the sound itself — the live cava bands under the transport.
        //    Real levels or nothing: no cava, no strip, because these bars
        //    claim to be the music.
        Item {
            id: wave

            x: 24
            y: 250
            width: parent.width - 48
            height: 36
            visible: root.has && root.playing && Config.services.audioReactive && Config.services.audioIsland && Spectrum.live

            Row {
                id: waveRow

                anchors.fill: parent
                spacing: 6

                Repeater {
                    model: Spectrum.count

                    Rectangle {
                        required property int index

                        readonly property real band: Spectrum.at(index)

                        width: (waveRow.width - (Spectrum.count - 1) * waveRow.spacing) / Math.max(1, Spectrum.count)
                        height: 3 + band * 31
                        y: waveRow.height - height
                        radius: 1.5
                        color: Colours.alpha(Colours.accent, 0.28 + band * 0.62)
                        antialiasing: true
                    }
                }
            }
        }

        // ── progress — times in the house mono, one thin track. The fill
        //    glides between polls instead of stepping, and the track itself
        //    is the seek bar: press anywhere, drag, release — the bridge
        //    jumps to exactly that beat.
        property real seekAt: -1               // -1 = not seeking
        readonly property real displayFrac: root.seekAt >= 0 ? root.seekAt : root.frac
        readonly property real displayPos: root.displayFrac * root.length

        P5Text {
            x: 20
            y: parent.height - 56
            text: root.fmt(root.displayPos)
            color: Colours.inkDim
            font.family: Appearance.fontFamily.mono
            font.pixelSize: Appearance.font.size.tiny
        }

        P5Text {
            anchors.right: parent.right
            anchors.rightMargin: 20
            y: parent.height - 56
            text: root.fmt(root.length)
            color: Colours.inkDim
            font.family: Appearance.fontFamily.mono
            font.pixelSize: Appearance.font.size.tiny
        }

        Rectangle {
            x: 20
            y: parent.height - 36
            width: parent.width - 40
            height: 4
            radius: 2
            color: Colours.alpha(Colours.ink, 0.15)
        }

        Rectangle {
            x: 20
            y: parent.height - 36 - (trackHover.hovered ? 1 : 0)
            width: (parent.width - 40) * root.displayFrac
            height: trackHover.hovered ? 6 : 4
            radius: 2
            color: trackHover.hovered ? Colours.accent : Colours.alpha(Colours.accent, 0.9)
            visible: root.length > 0

            Behavior on width {
                enabled: root.seekAt < 0
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutQuad
                }
            }
        }

        MouseArea {
            id: trackHover

            x: 20
            y: parent.height - 46
            width: parent.width - 40
            height: 22
            enabled: root.has && root.length > 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: event => root.seekAt = Math.max(0, Math.min(1, event.x / trackHover.width))
            onPositionChanged: event => {
                if (pressed)
                    root.seekAt = Math.max(0, Math.min(1, event.x / trackHover.width));
            }
            onReleased: {
                if (root.seekAt >= 0)
                    root.bridge.seek(root.seekAt);
                root.seekAt = -1;
            }
            onCanceled: root.seekAt = -1
        }
    }

    // ─────────────────────────────────────────────────────────── nothing playing
    Item {
        anchors.fill: parent
        visible: !root.has

        Column {
            anchors.centerIn: parent
            spacing: 10

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 34
                height: 36
                name: "music_note"
                color: Colours.alpha(Colours.ink, 0.35)
                font.pixelSize: 32
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: "NOTHING PLAYING"
                color: Colours.alpha(Colours.ink, 0.75)
                font.pixelSize: Appearance.font.size.large
                tracking: 1.6
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "START SOMETHING AND IT APPEARS HERE"
                color: Colours.inkDim
                font.pixelSize: Appearance.font.size.tiny
                tracking: 1.2
            }
        }
    }
}
