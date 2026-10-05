//  VELVET  ·  modules/lock/PassMask.qml
//  What typing a password looks like, for the lock faces of the vibes. Every
//  face used to draw its own row of dots; this draws the alternatives the user
//  can choose (LOCK SCREEN → VIBE FACES → TYPING): stars, a filling bar, a
//  count — and nothing at all. "dots" is each face's own way and is left to
//  the face: it hides this and draws its own.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var kit: null
    // what to draw it in
    property color colour: Colours.ink
    property color track: Colours.alpha(Colours.ink, 0.15)
    property real size: 14
    property string family: Appearance.fontFamily.mono
    property bool centered: true

    readonly property string mode: root.kit ? root.kit.mask : "dots"
    readonly property int length: root.kit ? root.kit.length : 0
    readonly property bool custom: root.mode !== "dots"

    visible: root.custom && root.mode !== "none"
    implicitWidth: root.mode === "bar" ? root.size * 14 : label.implicitWidth
    implicitHeight: root.mode === "bar" ? Math.max(4, root.size * 0.4) : label.implicitHeight

    Text {
        id: label

        anchors.horizontalCenter: root.centered ? parent.horizontalCenter : undefined
        visible: root.mode === "stars" || root.mode === "count"
        text: root.mode === "count" ? (root.length > 0 ? `${root.length}` : "") : "✱".repeat(Math.min(root.length, 28))
        color: root.colour
        font.family: root.family
        font.pixelSize: root.mode === "count" ? root.size * 1.5 : root.size * 1.25
        font.letterSpacing: root.mode === "stars" ? root.size * 0.18 : 0
    }

    Rectangle {
        visible: root.mode === "bar"
        anchors.fill: parent
        radius: height / 2
        color: root.track

        Rectangle {
            height: parent.height
            width: parent.width * Math.min(1, root.length / 16)
            radius: height / 2
            color: root.colour

            Behavior on width {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
