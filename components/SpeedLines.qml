//  VELVET  ·  components/SpeedLines.qml
//  Radial burst behind the settings overlay. Wedges, not lines, so they read
//  the way a comic panel does — thick at the rim, vanishing at the origin.
import qs.config
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property color color: "#ffffff"
    property int count: 18
    property real originX: 0.14      // 0..1 across the item
    property real originY: 0.5
    property real strength: 0.06
    property real spin: 0

    readonly property real _ox: width * originX
    readonly property real _oy: height * originY
    readonly property real _reach: Math.max(width, height) * 2.0

    opacity: strength
    clip: true

    Repeater {
        model: root.count

        Shape {
            id: wedge

            required property int index

            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property real a0: (index / root.count) * Math.PI * 2 + root.spin * Math.PI / 180
            // Irregular wedge widths — an even fan looks mechanical.
            readonly property real span: 0.006 + ((index * 37) % 11) / 11 * 0.03

            ShapePath {
                fillColor: root.color
                strokeWidth: 0

                PathPolyline {
                    path: [Qt.point(root._ox, root._oy), Qt.point(root._ox + Math.cos(wedge.a0 - wedge.span) * root._reach, root._oy + Math.sin(wedge.a0 - wedge.span) * root._reach), Qt.point(root._ox + Math.cos(wedge.a0 + wedge.span) * root._reach, root._oy + Math.sin(wedge.a0 + wedge.span) * root._reach), Qt.point(root._ox, root._oy)]
                }
            }
        }
    }
}
