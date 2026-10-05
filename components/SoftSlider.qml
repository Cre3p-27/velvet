//  VELVET  ·  components/SoftSlider.qml
//  The soft looks' slider: a rounded track strung with little dots — the
//  filled part in the accent, the rest dark — and a slim upright knob.
//  Drag or click anywhere on it; the wheel nudges it by one step. It only
//  reports (`moved`); the owner writes the setting, so a slider can never
//  fight the value it shows.
import qs.config
import qs.services
import QtQuick

Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property real step: 0
    // The look's unit — the lock passes its screen scale.
    property real u: 1
    property color accent: Colours.accent
    property color ground: Colours.alpha(Colours.paper, 0.6)

    signal moved(real value)

    // A range may run backwards (from 2 to 0.25: "faster" to the right).
    readonly property real span: Math.abs(root.to - root.from) < 1e-6 ? 1e-6 : root.to - root.from
    readonly property real frac: Math.max(0, Math.min(1, (root.value - root.from) / root.span))
    readonly property real pitch: 7 * root.u

    implicitWidth: 220 * root.u
    implicitHeight: 22 * root.u

    function valueAt(x: real): real {
        let v = root.from + Math.max(0, Math.min(1, x / Math.max(1, root.width))) * (root.to - root.from);
        if (root.step > 0)
            v = Math.round(v / root.step) * root.step;
        return Math.max(Math.min(root.from, root.to), Math.min(Math.max(root.from, root.to), v));
    }

    Plate {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 10 * root.u
        radius: Appearance.pill(height)
        color: root.ground
        antialiasing: true
    }

    Plate {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(track.height, root.frac * track.width)
        height: track.height
        radius: Appearance.pill(height)
        color: root.accent
        antialiasing: true
    }

    // The string of dots — dark on the fill, light on the empty track.
    Repeater {
        model: Math.max(0, Math.floor((root.width - 6 * root.u) / root.pitch))

        Rectangle {
            required property int index

            readonly property real cx: 6 * root.u + index * root.pitch

            x: cx - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 2.6 * root.u
            height: width
            radius: width / 2
            color: cx < root.frac * root.width ? Colours.alpha(Colours.on(root.accent), 0.4) : Colours.alpha(Colours.ink, 0.4)
            antialiasing: true
        }
    }

    Rectangle {
        x: Math.max(0, Math.min(root.width - width, root.frac * root.width - width / 2))
        anchors.verticalCenter: parent.verticalCenter
        width: 4 * root.u
        height: 22 * root.u
        radius: width / 2
        color: Colours.ink
        antialiasing: true
        scale: drag.pressed ? 1.15 : 1

        Behavior on scale {
            NumberAnimation {
                duration: 120
            }
        }
    }

    MouseArea {
        id: drag

        anchors.fill: parent
        anchors.topMargin: -6 * root.u
        anchors.bottomMargin: -6 * root.u
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => root.moved(root.valueAt(mouse.x))
        onPositionChanged: mouse => {
            if (drag.pressed)
                root.moved(root.valueAt(mouse.x));
        }
        onWheel: wheel => {
            const s = (root.step > 0 ? root.step : Math.abs(root.span) / 20) * (root.span < 0 ? -1 : 1);
            root.moved(Math.max(Math.min(root.from, root.to), Math.min(Math.max(root.from, root.to), root.value + (wheel.angleDelta.y > 0 ? s : -s))));
        }
    }
}
