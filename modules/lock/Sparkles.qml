//  VELVET  ·  modules/lock/Sparkles.qml
//  Ambient accent dust for the lock: a field of tiny stars that twinkle on
//  their own unharmonic periods. Nothing moves position — only brightness —
//  so the screen stays calm but never dead. Positions are seeded per index,
//  so the field looks the same on every lock.
//
//  Loaded by path from FluidLock.qml like every other decorative layer:
//  if this file ever fails, the lock loses its dust and nothing else.
import qs.services
import QtQuick

Item {
    id: root

    clip: true

    Repeater {
        model: 26

        Rectangle {
            required property int index

            // Seeded, so the constellation is stable across locks.
            readonly property real fx: ((index * 7919 + 13) % 997) / 997
            readonly property real fy: ((index * 37 + 5) % 89) / 89

            x: fx * (root.width - width)
            y: fy * (root.height - height)
            width: 2 + ((index * 17) % 5)
            height: width
            radius: width / 2
            color: index % 3 === 0 ? Colours.accentHot : Colours.accent
            opacity: 0.2

            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.6
                    duration: 1300 + index * 173
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0.14
                    duration: 1300 + index * 173
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
