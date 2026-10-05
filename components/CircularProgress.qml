//  VELVET  ·  components/CircularProgress.qml
//  A Material-3-style progress ring — the Material signature: a full track, a
//  rounded cap that sweeps to the value, a small centred label. Pure
//  QtQuick.Shapes like the rest of the shell, so it follows the palette
//  live (wallpaper switch recolours it with everything else).
import qs.config
import qs.services
import Quickshell
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property real value: 0                 // 0..1
    property real thickness: 4
    property color color: Colours.accent
    property color trackColor: Colours.alpha(Colours.ink, 0.12)
    property string text: ""
    property real textSize: Appearance.font.size.small

    implicitWidth: 46
    implicitHeight: 46

    // The sweep glides to its target instead of jumping.
    Behavior on value {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutCubic
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Appearance.anim.normal
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        // The full track.
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness / 2
                radiusY: root.height / 2 - root.thickness / 2
                startAngle: -90
                sweepAngle: 360
            }
        }

        // The value sweep, from twelve o'clock clockwise.
        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root.width / 2
                centerY: root.height / 2
                radiusX: root.width / 2 - root.thickness / 2
                radiusY: root.height / 2 - root.thickness / 2
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, root.value))
            }
        }
    }

    P5Text {
        anchors.centerIn: parent
        display: true
        text: root.text
        color: Colours.ink
        font.pixelSize: root.textSize
    }
}
