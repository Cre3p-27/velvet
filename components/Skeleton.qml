//  VELVET  ·  components/Skeleton.qml
//  Placeholder rows while a list is still coming (networks being searched,
//  devices being found …): soft bars in the shape of what will be there, and
//  one light that sweeps across them all, row after row. It moves only while
//  it is on screen.
//
//      Skeleton { width: parent.width; count: 4; visible: Net.scanning }
import qs.config
import qs.services
import QtQuick

Column {
    id: root

    property int count: 4
    property real rowHeight: 44
    property bool icon: true
    property color tint: Colours.ink
    property real radius: Appearance.rounding.normal

    // 0 → 1 → 0 … the sweep; each row trails the one above it a little
    property real sweep: 0

    spacing: 6

    NumberAnimation on sweep {
        running: root.visible && root.count > 0
        loops: Animation.Infinite
        from: 0
        to: 1
        duration: 1400
    }

    Repeater {
        model: root.count

        Item {
            id: row

            required property int index
            // the rows fade towards the bottom: "more may be coming"
            readonly property real fade: 1 - row.index * 0.18
            readonly property real at: ((root.sweep - row.index * 0.12) % 1 + 1) % 1

            width: root.width
            height: root.rowHeight
            opacity: Math.max(0.25, row.fade)

            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: Colours.alpha(root.tint, 0.04)
                border.width: 1
                border.color: Colours.alpha(root.tint, 0.08)
            }

            Rectangle {
                visible: root.icon
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 9
                color: Colours.alpha(root.tint, 0.12)
            }

            Column {
                x: root.icon ? 42 : 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Rectangle {
                    // a different length per row, as real names would be
                    width: (root.width - 60) * [0.46, 0.62, 0.38, 0.54, 0.42][row.index % 5]
                    height: 8
                    radius: 4
                    color: Colours.alpha(root.tint, 0.13)
                }
                Rectangle {
                    width: (root.width - 60) * [0.22, 0.18, 0.26, 0.2, 0.24][row.index % 5]
                    height: 6
                    radius: 3
                    color: Colours.alpha(root.tint, 0.08)
                }
            }

            // the light passing over the row
            Item {
                anchors.fill: parent
                clip: true

                Rectangle {
                    width: parent.width * 0.42
                    height: parent.height
                    x: -width + (parent.width + width) * row.at
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: "transparent"
                        }
                        GradientStop {
                            position: 0.5
                            color: Colours.alpha(root.tint, 0.07)
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }
                }
            }
        }
    }
}
