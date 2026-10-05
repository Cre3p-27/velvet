//  VELVET  ·  modules/lock/LockWall.qml
//  The picture behind a vibe's lock: the wallpaper, blurred and dimmed as far as
//  the face wants, or a plain ground when there is none (or in the settings'
//  preview). Faces put it at the bottom of their stack.
import qs.config
import qs.services
import QtQuick
import QtQuick.Effects

Item {
    id: root

    // 0 = sharp, 1 = frosted
    property real blur: 0.6
    // how much of the ground colour lies over it, 0..1
    property real dim: 0.35
    property color ground: Colours.paper
    // false: the ground only
    property bool picture: true
    // a slow drift, so a screen that stays locked is never quite still
    property bool drift: true

    readonly property bool has: root.picture && Config.wallpaper.current !== "" && wp.status === Image.Ready

    Rectangle {
        anchors.fill: parent
        color: root.ground
    }

    Item {
        id: holder

        anchors.fill: parent
        visible: root.has
        layer.enabled: root.blur > 0.02 && root.has
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 56
            autoPaddingEnabled: false
        }

        Image {
            id: wp

            anchors.fill: parent
            source: root.picture && Config.wallpaper.current !== "" ? "file://" + Config.wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            scale: 1.06

            SequentialAnimation on scale {
                running: root.drift && root.has && root.visible
                loops: Animation.Infinite
                NumberAnimation { from: 1.06; to: 1.1; duration: 45000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.1; to: 1.06; duration: 45000; easing.type: Easing.InOutSine }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Colours.alpha(root.ground, root.has ? root.dim : 0)
    }
}
