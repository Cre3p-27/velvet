//  VELVET  ·  Media — what is playing, in the bar.
//  Loaded by path from Bar.qml, so a Quickshell build without the MPRIS
//  service costs us this one module instead of the whole taskbar.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Item {
    id: root

    property bool vertical: true
    property int span: 30

    readonly property var player: {
        // One choice for the whole shell (services/MprisBridge.qml): it
        // remembers the last player that played, so a pause never hands
        // the controls to a browser tab. The scan below is the fallback.
        if (Lyrics.bridge)
            return Lyrics.bridge.player;
        const list = Mpris.players?.values ?? [];
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i];
        return list.length > 0 ? list[0] : null;
    }

    readonly property bool playing: root.player?.isPlaying ?? false
    // Live audio driving this entry: cava feeding us, music playing, and the
    // switch on in MODULES → AUDIO-REACTIVE. When any of those is missing the
    // bars fall back to their old decorative stagger — which is honest,
    // because it was never claiming to be the sound.
    readonly property bool reactive: Config.services.audioReactive && Config.services.audioBar && Spectrum.live && root.playing
    readonly property string title: root.player?.trackTitle ?? ""
    readonly property string artist: root.player?.trackArtist ?? ""
    readonly property bool has: root.title.length > 0

    // Measured off the text itself, never off the label's implicitWidth —
    // the label's width is driven by this value, and measuring the label
    // would close a binding loop.
    readonly property real textLen: root.vertical ? 0 : Math.min(200, metrics.advanceWidth)

    implicitWidth: root.has ? (root.vertical ? root.span : 26 + root.textLen + 12) : 0
    implicitHeight: root.has ? (root.vertical ? root.span + 4 : root.span) : 0
    // Hides only once the fade has finished, so a track that stops
    // dissolves out of the bar instead of popping.
    visible: root.opacity > 0.01
    opacity: root.has ? 1 : 0

    // The entry gives under the pointer, exactly like the BarButtons.
    scale: mouse.pressed ? 0.92 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutBack
            easing.overshoot: 2.4
        }
    }

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutExpo
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.normal
        }
    }

    // While the meter is live, the entry breathes: a wash of accent behind
    // the bars whose strength follows the loudness of what is playing.
    Plate {
        anchors.fill: parent
        radius: Appearance.r(8)
        visible: root.reactive
        color: Colours.alpha(Colours.accent, 0.05 + Spectrum.level * 0.17)
        antialiasing: true
    }

    // Four bars that move while something plays and rest flat when it doesn't.
    // With live levels they move with the music; without them they say "this
    // is alive" and nothing more.
    Row {
        id: bars

        x: root.vertical ? (root.span - width) / 2 : 0
        y: root.vertical ? 2 : (root.height - height) / 2
        height: 20
        spacing: 3

        Repeater {
            model: 4

            Rectangle {
                id: bar

                required property int index

                // Decorative mode animates this plain property; live mode
                // binds the height straight to the spectrum. Animating a
                // bound property would eat the binding on the first frame,
                // so the two never touch the same value.
                property real animHeight: 6

                width: 3.5
                height: root.reactive ? (4 + Spectrum.group(index, 4) * 15) : animHeight
                radius: 1.5
                color: root.playing ? Colours.accent : Colours.alpha(Colours.inkDim, 0.6)
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.normal
                    }
                }

                SequentialAnimation {
                    running: root.playing && root.visible && !root.reactive
                    loops: Animation.Infinite
                    alwaysRunToEnd: true

                    PauseAnimation {
                        duration: index * 95
                    }
                    NumberAnimation {
                        target: bar
                        property: "animHeight"
                        to: 18
                        duration: 360
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        target: bar
                        property: "animHeight"
                        to: 6
                        duration: 360
                        easing.type: Easing.InOutSine
                    }
                    PauseAnimation {
                        duration: (3 - index) * 95
                    }
                }
            }
        }
    }

    // Horizontal bars only: the title, clipped rather than ellipsised.
    Item {
        visible: !root.vertical
        x: 26
        y: 0
        width: root.textLen
        height: root.height
        clip: true

        P5Text {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            text: root.artist ? `${root.title}  ·  ${root.artist}` : root.title
            color: Colours.ink
            font.pixelSize: Config.bar.fontSize
            elide: Text.ElideRight
            width: parent.width
        }
    }

    TextMetrics {
        id: metrics

        font.family: label.font.family
        font.pixelSize: Config.bar.fontSize
        text: root.artist ? `${root.title}  ·  ${root.artist}` : root.title
    }

    // Track position — MPRIS is a poll, not a stream, so ask once a second
    // while something plays and the entry is actually on screen.
    property real pos: 0

    readonly property real frac: (root.player && root.player.length > 0)
        ? Math.max(0, Math.min(1, root.pos / root.player.length))
        : 0

    Timer {
        interval: 1000
        repeat: true
        running: root.has && root.playing && root.visible
        onTriggered: {
            const p = root.player;
            if (!p)
                return;
            p.positionChanged();
            root.pos = p.position ?? 0;
        }
    }

    // A hairline of progress along the leading edge — the track draining in
    // the accent, so the song's position reads at a glance.
    Rectangle {
        visible: !root.vertical && root.playing
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: root.width * root.frac
        height: 2
        radius: 1
        color: Colours.accent

        Behavior on width {
            NumberAnimation {
                duration: 950
                easing.type: Easing.Linear
            }
        }
    }

    Rectangle {
        visible: root.vertical && root.playing
        anchors.right: parent.right
        anchors.top: parent.top
        width: 2
        height: root.height * root.frac
        radius: 1
        color: Colours.accent

        Behavior on height {
            NumberAnimation {
                duration: 950
                easing.type: Easing.Linear
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: event => {
            if (!root.player)
                return;
            Sfx.cursor();
            if (event.button === Qt.MiddleButton)
                root.player.next();
            else
                root.player.togglePlaying();
        }
    }

    WheelHandler {
        onWheel: event => {
            if (!root.player)
                return;
            if (event.angleDelta.y > 0)
                root.player.next();
            else
                root.player.previous();
        }
    }
}
