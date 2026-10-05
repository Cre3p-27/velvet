//  VELVET  ·  modules/bar/popouts/Tip.qml
//  A one-line label for whatever the pointer is resting on. Small on purpose:
//  a tooltip that needs reading twice has failed.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    implicitWidth: label.implicitWidth + 40
    implicitHeight: 46

    P5Text {
        id: label

        anchors.centerIn: parent
        display: true
        text: Popout.tipText
        color: Colours.ink
        font.pixelSize: Appearance.font.size.normal
        tracking: 1.4
    }
}
