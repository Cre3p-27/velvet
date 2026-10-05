//  VELVET  ·  components/SoftSwitch.qml
//  The soft looks' switch: a small accent track with a knob that slides.
import qs.config
import qs.services
import QtQuick

Plate {
    id: sw

    property bool on: false
    property real u: 1
    property bool interactive: true
    property color accent: Colours.accent

    signal clicked

    implicitWidth: 40 * sw.u
    implicitHeight: 22 * sw.u
    radius: Appearance.pill(height)
    color: sw.on ? sw.accent : Colours.alpha(Colours.ink, 0.14)
    antialiasing: true

    Behavior on color {
        ColorAnimation {
            duration: 160
        }
    }

    Rectangle {
        x: sw.on ? sw.width - width - 3 * sw.u : 3 * sw.u
        anchors.verticalCenter: parent.verticalCenter
        width: 16 * sw.u
        height: width
        radius: width / 2
        color: sw.on ? Colours.on(sw.accent) : Colours.ink
        antialiasing: true

        Behavior on x {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
    }

    TapHandler {
        enabled: sw.interactive
        onTapped: {
            Sfx.toggle();
            sw.clicked();
        }
    }
    HoverHandler {
        enabled: sw.interactive
        cursorShape: Qt.PointingHandCursor
    }
}
