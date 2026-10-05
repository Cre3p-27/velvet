//  VELVET  ·  modules/wallpaper/Sheen.qml
//  The pointer's light on a rounded card: a soft radial highlight clipped
//  exactly to the card's corners. The SHAPES silhouettes carry their own
//  (M3Shape.sheen); this is the same light for the cards and the pill.
//  Drawn only while it is lit.
import qs.services
import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    property real radius: 0
    property real strength: 0
    property real lightX: root.width / 2
    property real lightY: root.height / 2
    property color tint: "white"

    visible: root.strength > 0.003
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: "transparent"
        strokeWidth: 0
        fillGradient: RadialGradient {
            centerX: root.lightX
            centerY: root.lightY
            focalX: root.lightX
            focalY: root.lightY
            centerRadius: Math.max(root.width, root.height) * 0.7
            focalRadius: 0

            GradientStop {
                position: 0
                color: Colours.alpha(root.tint, root.strength)
            }
            GradientStop {
                position: 0.45
                color: Colours.alpha(root.tint, root.strength * 0.35)
            }
            GradientStop {
                position: 1
                color: Colours.alpha(root.tint, 0)
            }
        }

        PathRectangle {
            x: 0
            y: 0
            width: root.width
            height: root.height
            radius: Math.min(root.radius, root.width / 2, root.height / 2)
        }
    }
}
