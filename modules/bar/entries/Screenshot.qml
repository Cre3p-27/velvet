//  VELVET  ·  Screenshot — drag a region, it lands on the clipboard.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    padding: 4
    tip: "SCREENSHOT A REGION  ·  RIGHT-CLICK FOR THE WHOLE SCREEN"

    property bool flashing: false

    onClicked: {
        Sfx.select();
        root.flashing = true;
        flashOff.restart();
        Actions.run(Config.services.screenshotCommand);
    }

    onRightClicked: {
        Sfx.select();
        Actions.run("grim - | wl-copy");
    }

    Timer {
        id: flashOff
        interval: 260
        onTriggered: root.flashing = false
    }

    Icon {
        name: "photo_camera"
        font.pixelSize: Config.bar.iconSize
        color: root.flashing ? Colours.ink : (root.containsMouse ? Colours.accent : Colours.inkDim)
        scale: root.flashing ? 1.35 : 1.0

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
                easing.overshoot: 3
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }
}
