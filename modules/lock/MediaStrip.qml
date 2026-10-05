//  VELVET  ·  modules/lock/MediaStrip.qml
//  What's playing, on the lock screen. Loaded by path from LockScreen.qml so
//  that a Quickshell build without the MPRIS service costs us this strip and
//  nothing else.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

Item {
    id: root

    readonly property var player: {
        // One choice for the whole shell (services/MprisBridge.qml): it
        // remembers the last player that played, so a pause never hands
        // the controls to a browser tab. The scan below is the fallback.
        if (Lyrics.bridge)
            return Lyrics.bridge.player;
        const list = Mpris.players?.values ?? [];
        // Prefer whatever is actually playing.
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i];
        return list.length > 0 ? list[0] : null;
    }

    readonly property string title: root.player?.trackTitle ?? ""
    readonly property string artist: root.player?.trackArtist ?? ""

    implicitHeight: 74
    // Fades out rather than popping when the track ends.
    visible: root.opacity > 0.01
    opacity: root.title.length > 0 ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.anim.normal
        }
    }

    Slash {
        anchors.fill: parent
        shear: Appearance.skew
        color: Colours.alpha(Colours.surfaceHigh, 0.55)
        borderColor: Colours.alpha(Colours.accent, 0.4)
        borderWidth: 1
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 26
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        // A tiny four-bar visualiser. It isn't reading the audio — it just
        // says "something is playing", which is all this needs to say.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            width: 26

            Repeater {
                model: 4

                Rectangle {
                    required property int index

                    width: 4
                    height: 8
                    radius: 1
                    color: Colours.accent
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on height {
                        running: root.player?.isPlaying ?? false
                        loops: Animation.Infinite
                        PauseAnimation {
                            duration: index * 90
                        }
                        NumberAnimation {
                            to: 24
                            duration: 380
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 7
                            duration: 380
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -1
            width: parent.width - 26 - 16

            P5Text {
                display: true
                width: parent.width
                text: root.title
                color: Colours.ink
                font.pixelSize: Appearance.font.size.normal + 1
                elide: Text.ElideRight
            }

            P5Text {
                width: parent.width
                text: root.artist.toUpperCase()
                color: Colours.accentInk
                font.pixelSize: Appearance.font.size.tiny
                tracking: 2
                elide: Text.ElideRight
            }
        }
    }
}
