//  VELVET  ·  modules/lock/LockChip.qml
//  The glass chip every lock module rides in — one container language for
//  the whole lock, like a Material pill and its surfaces:
//  a soft fill, a hairline of accent, and a quiet shadow, so modules read
//  as objects resting on the glass rather than text floating in space.
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick
import QtQuick.Effects

Item {
    id: root

    default property alias content: inner.data

    property real pad: 16
    property real radius: 22
    property color fill: Colours.alpha(Colours.surface, 0.55)
    property color border: Colours.alpha(Colours.accent, 0.28)

    implicitWidth: inner.childrenRect.width + root.pad * 2
    implicitHeight: inner.childrenRect.height + root.pad * 2

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.fill
        border.width: 1
        border.color: root.border
        antialiasing: true

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 32
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowBlur: 0.6
            shadowVerticalOffset: 6
        }
    }

    Item {
        id: inner

        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }
}
