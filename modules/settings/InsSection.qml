//  VELVET  ·  modules/settings/InsSection.qml
//  An inspector heading: an accent tick, a title, a quiet note under it.
import qs.config
import qs.services
import qs.components
import QtQuick

Column {
    id: sec

    property string title: ""
    property string note: ""

    width: parent ? parent.width : 0
    spacing: 2
    topPadding: 2

    Row {
        spacing: 8

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 12
            radius: 1.5
            color: Colours.accent
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: sec.title
            color: Colours.ink
            font.pixelSize: Appearance.font.size.small
            tracking: 1.6
        }
    }

    P5Text {
        width: parent.width
        visible: sec.note !== ""
        text: sec.note
        wrapMode: Text.WordWrap
        color: Colours.alpha(Colours.inkDim, 0.7)
        font.pixelSize: Appearance.font.size.tiny - 1
        tracking: 1.2
    }
}

// A labelled option: the name above, the choices under it.
