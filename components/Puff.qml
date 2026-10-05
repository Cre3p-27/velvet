//  VELVET  ·  components/Puff.qml
//  A moulded surface for the soft-depth looks: a neumorphic plate that rises
//  out of its ground (two shadows, one light one dark) or sinks into it, and a
//  claymorphic lump (lit top, shaded belly, a fat tinted shadow). The shadows
//  are stacks of rounded rectangles, so they look soft in any renderer.
//  Children go inside it like in a Rectangle.
import qs.config
import qs.services
import QtQuick

Item {
    id: root

    // raised | inset (neumorphism) · clay · plain
    property string kind: "raised"
    property color color: Colours.surface
    property real radius: 14
    // how far the shadows reach
    property real depth: 6
    property color tint: Colours.clay
    default property alias content: slot.data

    // the look's own depth dial (VISUALS → THIS LOOK) on top of what the caller asked for
    readonly property real d: root.depth * Appearance.depth
    readonly property real sx: Appearance.lightSign.x
    readonly property real sy: Appearance.lightSign.y

    readonly property bool light: Colours.light
    readonly property color dark: root.light ? Qt.rgba(0.36, 0.42, 0.58, 1) : Qt.rgba(0, 0, 0, 1)
    readonly property color lite: root.light ? Qt.rgba(1, 1, 1, 1) : Qt.rgba(1, 1, 1, 1)
    readonly property real darkA: root.light ? 0.085 : 0.16
    readonly property real liteA: root.light ? 0.5 : 0.035

    // ── neumorphism, raised: dark below-right, light above-left
    Repeater {
        model: root.kind === "raised" ? 4 : 0

        Item {
            required property int index

            readonly property real g: (index + 1) / 4
            readonly property real e: g * root.d * 0.9

            Rectangle {
                x: root.d * 0.7 * root.sx - parent.e / 2
                y: root.d * 0.7 * root.sy - parent.e / 2
                width: root.width + parent.e
                height: root.height + parent.e
                radius: root.radius + parent.e / 2
                color: Qt.rgba(root.dark.r, root.dark.g, root.dark.b, root.darkA * (1.15 - parent.g * 0.7))
            }
            Rectangle {
                x: -root.d * 0.7 * root.sx - parent.e / 2
                y: -root.d * 0.7 * root.sy - parent.e / 2
                width: root.width + parent.e
                height: root.height + parent.e
                radius: root.radius + parent.e / 2
                color: Qt.rgba(root.lite.r, root.lite.g, root.lite.b, root.liteA * (1.15 - parent.g * 0.7))
            }
        }
    }

    // ── clay: a fat shadow straight down, tinted
    Repeater {
        model: root.kind === "clay" ? 5 : 0

        Rectangle {
            required property int index

            readonly property real g: (index + 1) / 5
            readonly property real e: g * root.d * 0.8

            x: -e / 2
            y: root.d * 0.6 - e * 0.25
            width: root.width + e
            height: root.height + e * 0.6
            radius: root.radius + e / 2
            color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.13 * (1.2 - g * 0.8))
        }
    }

    // ── the body
    Rectangle {
        id: body

        anchors.fill: parent
        radius: root.radius
        color: root.kind === "inset" ? Qt.rgba(root.color.r * 0.965, root.color.g * 0.965, root.color.b * 0.965, root.color.a) : root.color
        gradient: root.kind === "clay" ? clayFill : null

        Gradient {
            id: clayFill

            GradientStop { position: 0.0; color: Qt.lighter(root.color, 1 + 0.1 * Math.min(1.5, Appearance.gloss)) }
            GradientStop { position: 0.55; color: root.color }
            GradientStop { position: 1.0; color: Qt.darker(root.color, 1 + 0.09 * Math.min(1.5, Appearance.gloss)) }
        }
    }

    // the pit of a pressed-in plate: shaded where the light comes from, lit on
    // the far side (turned half a circle when the light is below)
    Rectangle {
        anchors.fill: parent
        visible: root.kind === "inset"
        radius: root.radius
        rotation: root.sy > 0 ? 0 : 180

        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root.dark.r, root.dark.g, root.dark.b, root.light ? 0.2 : 0.35) }
            GradientStop { position: 0.3; color: Qt.rgba(root.dark.r, root.dark.g, root.dark.b, 0.0) }
            GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, root.light ? 0.6 : 0.06) }
        }
    }

    // the lit top of the clay
    Rectangle {
        visible: root.kind === "clay" && root.height > 18
        x: Math.min(6, root.radius * 0.35)
        y: 2
        width: root.width - x * 2
        height: Math.max(4, root.height * 0.34)
        radius: height / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, Math.min(0.9, 0.55 * Appearance.gloss)) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
        }
    }

    Item {
        id: slot

        anchors.fill: parent
    }
}
