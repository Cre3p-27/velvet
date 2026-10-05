//  VELVET  ·  components/Gauge.qml
//  Sheared micro meter for CPU / RAM in the bar. Reads at a glance, costs
//  almost nothing to draw.
import qs.config
import qs.services
import QtQuick

Item {
    id: root

    property bool vertical: true
    property real length: 26
    property real value: 0          // 0..1
    property string label: ""
    property color tint: Colours.accent
    property real thickness: 5

    readonly property real clamped: Math.max(0, Math.min(1, value))

    implicitWidth: vertical ? length : (letter.implicitWidth + 4 + length)
    implicitHeight: vertical ? (letter.implicitHeight + 2 + thickness) : Math.max(thickness + 2, letter.implicitHeight)

    P5Text {
        id: letter

        display: true
        text: root.label
        color: Colours.alpha(Colours.inkDim, 0.85)
        font.pixelSize: Config.bar.fontSize * 0.72
        tracking: 0

        x: root.vertical ? (root.width - implicitWidth) / 2 : 0
        y: root.vertical ? 0 : (root.height - implicitHeight) / 2
    }

    // The terminal, the arcade and the HUD draw a meter out of blocks.
    readonly property bool blocky: ["console", "arcade", "hud"].indexOf(Appearance.skin) >= 0

    Item {
        id: track

        width: root.length
        height: root.blocky ? root.thickness + 1 : (Appearance.skin === "poster" ? root.thickness + 1 : root.thickness)
        x: root.vertical ? 0 : letter.implicitWidth + 4
        y: root.vertical ? letter.implicitHeight + 2 : (root.height - height) / 2

        // blocks
        Row {
            visible: root.blocky
            spacing: 1

            Repeater {
                model: 6

                Rectangle {
                    required property int index

                    width: (track.width - 5) / 6
                    height: track.height
                    color: index < Math.round(root.clamped * 6) ? (root.clamped > 0.88 ? Colours.danger : root.tint) : Colours.alpha(Colours.ink, 0.16)
                }
            }
        }

        // the bar
        Slash {
            visible: !root.blocky
            anchors.fill: parent
            shear: Appearance.skew * 2
            color: Colours.alpha(Colours.ink, 0.14)
        }

        Slash {
            visible: !root.blocky
            width: Math.max(2, parent.width * root.clamped)
            height: parent.height
            shear: Appearance.skew * 2
            color: root.clamped > 0.88 ? Colours.danger : root.tint

            Behavior on width {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
