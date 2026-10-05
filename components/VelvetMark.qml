//  VELVET  ·  components/VelvetMark.qml
//  The mark.
//
//  Two sheared bars meeting at a point make the V; a rotated square holds it;
//  a hairline cuts the whole thing on the same angle everything else in this
//  shell is cut on. Built out of rectangles rather than an SVG so it takes the
//  wallpaper's accent with it and can be animated a piece at a time.
import qs.config
import qs.services
import QtQuick

Item {
    id: root

    property color tint: Colours.accent
    property color ink: Colours.ink
    // 0 → assembled off screen, 1 → landed. Animate this, not the children.
    property real reveal: 1
    property bool spin: false

    implicitWidth: 120
    implicitHeight: 120

    readonly property real unit: Math.min(width, height)
    readonly property real bar: root.unit * 0.13

    function land(): void {
        landing.restart();
    }

    NumberAnimation {
        id: landing

        target: root
        property: "reveal"
        from: 0
        to: 1
        duration: Appearance.anim.entrance
        easing.type: Easing.OutExpo
    }

    // ── the frame: a square on its corner, drawn as four bars
    Item {
        id: frame

        anchors.centerIn: parent
        width: root.unit * 0.82
        height: root.unit * 0.82
        rotation: 45 + (1 - root.reveal) * 40
        opacity: root.reveal
        scale: 0.72 + root.reveal * 0.28

        Repeater {
            model: 4

            Rectangle {
                required property int index

                readonly property bool vertical: index % 2 === 1

                width: vertical ? root.unit * 0.055 : frame.width
                height: vertical ? frame.height : root.unit * 0.055
                x: index === 1 ? frame.width - width : 0
                y: index === 2 ? frame.height - height : 0
                color: root.tint
                antialiasing: true
            }
        }
    }

    // ── the V
    Item {
        id: vee

        anchors.centerIn: parent
        width: root.unit * 0.5
        height: root.unit * 0.46

        // Each stroke arrives from its own side, so the mark assembles rather
        // than fading up.
        Rectangle {
            id: left

            width: root.bar
            height: vee.height * 1.16
            color: root.ink
            antialiasing: true
            transformOrigin: Item.Center
            rotation: -20
            x: vee.width * 0.2 - width / 2 - (1 - root.reveal) * root.unit * 0.5
            y: -vee.height * 0.08
            opacity: root.reveal
        }

        Rectangle {
            id: right

            width: root.bar
            height: vee.height * 1.16
            color: root.ink
            antialiasing: true
            transformOrigin: Item.Center
            rotation: 20
            x: vee.width * 0.8 - width / 2 + (1 - root.reveal) * root.unit * 0.5
            y: -vee.height * 0.08
            opacity: root.reveal
        }

        // The joint at the bottom of the V, so the two strokes read as one
        // letter rather than as two sticks.
        Rectangle {
            width: root.bar * 1.35
            height: root.bar
            color: root.ink
            antialiasing: true
            x: vee.width / 2 - width / 2
            y: vee.height * 0.92
            opacity: root.reveal
            scale: root.reveal
        }
    }

    // ── the cut
    Rectangle {
        anchors.centerIn: parent
        width: root.unit * 1.24 * root.reveal
        height: Math.max(1, root.unit * 0.014)
        color: root.tint
        antialiasing: true
        transformOrigin: Item.Center
        rotation: -Appearance.skew - 8
        opacity: 0.9 * root.reveal
    }

    // ── a slow turn, for the places that want the mark alive
    RotationAnimation {
        target: frame
        property: "rotation"
        running: root.spin && root.reveal >= 1
        from: 45
        to: 405
        duration: 26000
        loops: Animation.Infinite
    }
}
