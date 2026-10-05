//  VELVET  ·  components/Ripple.qml
//  A press wave. Drop one into any clickable surface and call pop(x, y) from
//  the click handler — it expands from exactly where you hit, which is what
//  makes a click feel like it landed rather than merely registered.
import qs.config
import QtQuick

Item {
    id: root

    property color color: Colours.ink
    property real maxOpacity: 0.28

    clip: true

    function pop(px: real, py: real): void {
        wave.x = px;
        wave.y = py;
        wave.width = 0;
        wave.opacity = root.maxOpacity;
        grow.restart();
    }

    Rectangle {
        id: wave

        readonly property real reach: Math.max(root.width, root.height) * 2.2

        width: 0
        height: width
        radius: width / 2
        color: root.color
        opacity: 0
        transformOrigin: Item.TopLeft
        // Grows from the point it was given, not from a corner.
        transform: Translate {
            x: -wave.width / 2
            y: -wave.width / 2
        }
    }

    ParallelAnimation {
        id: grow

        NumberAnimation {
            target: wave
            property: "width"
            from: 0
            to: wave.reach
            duration: Appearance.anim.slow
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: wave
            property: "opacity"
            from: root.maxOpacity
            to: 0
            duration: Appearance.anim.slow
            easing.type: Easing.OutQuad
        }
    }
}
