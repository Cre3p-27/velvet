//  VELVET  ·  Microphone — mute state at a glance, gain on the wheel.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    readonly property bool muted: Audio.micMuted

    padding: 4
    tip: "MICROPHONE  ·  WHEEL CHANGES GAIN  ·  RIGHT-CLICK FOR AUDIO"

    onClicked: {
        Sfx.toggle();
        Audio.toggleMicMute();
    }
    onRightClicked: Panels.openSettingsKey("services.volumeStep")

    Icon {
        name: root.muted ? "mic_off" : "mic"
        font.pixelSize: Config.bar.iconSize
        color: root.muted ? Colours.danger : (root.containsMouse ? Colours.accent : Colours.ink)

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        // A slow pulse while the mic is live, so an open mic is never a
        // surprise.
        SequentialAnimation on opacity {
            running: !root.muted
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.55
                duration: 1400
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1.0
                duration: 1400
                easing.type: Easing.InOutSine
            }
        }
    }

    WheelHandler {
        onWheel: event => Audio.setMicVolume(Audio.micVolume + (event.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
