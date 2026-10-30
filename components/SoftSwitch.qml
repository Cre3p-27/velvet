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
        id: knob

        // FIDGET FEEL: it overshoots a little and stretches as it flies
        readonly property real stretch: Config.sfx.fidget ? Math.min(0.4, Math.abs(slide.speed) / (700 * sw.u)) : 0

        x: slide.value
        anchors.verticalCenter: parent.verticalCenter
        width: 16 * sw.u
        height: width
        radius: width / 2
        color: sw.on ? Colours.on(sw.accent) : Colours.ink
        antialiasing: true
        transform: Scale {
            origin.x: knob.width / 2
            origin.y: knob.height / 2
            xScale: 1 + knob.stretch
            yScale: 1 - knob.stretch * 0.4
        }

        Spring {
            id: slide

            to: sw.on ? sw.width - knob.width - 3 * sw.u : 3 * sw.u
            spring: Config.sfx.fidget ? 5.5 : 9
            damping: Config.sfx.fidget ? 0.34 : 0.9
            epsilon: 0.2
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
