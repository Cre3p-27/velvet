//  VELVET  ·  modules/bar/popouts/Tip.qml
//  A one-line label for whatever the pointer is resting on. Small on purpose:
//  a tooltip that needs reading twice has failed.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    // One line whenever it fits; a long tip at a big type size wraps onto a
    // second line instead of running out of the card (it used to be cut off
    // at the screen-side edge: "…RIGHT-CLICK FOR CLOCK S").
    readonly property real most: 480

    implicitWidth: label.width + 40
    implicitHeight: Math.max(46, label.height + 22)

    P5Text {
        id: label

        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.most)
        display: true
        text: Popout.tipText
        color: Colours.ink
        font.pixelSize: Appearance.font.size.normal
        tracking: 1.4
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }
}
