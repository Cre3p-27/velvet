//  VELVET  ·  modules/settings/InsOption.qml
//  One labelled option in an inspector: the name (and a note) above, the
//  choices under it.
import qs.config
import qs.services
import qs.components
import QtQuick

Column {
    id: opt

    property string label: ""
    property string note: ""
    default property alias body: holder.data

    width: parent ? parent.width : 0
    spacing: 6

    Row {
        spacing: 8

        P5Text {
            id: optLabel

            text: opt.label
            color: Colours.inkDim
            font.pixelSize: Appearance.font.size.tiny
            tracking: 2.4
        }

        P5Text {
            visible: opt.note !== ""
            width: Math.max(0, opt.width - optLabel.implicitWidth - 8)
            elide: Text.ElideRight
            text: opt.note
            color: Colours.alpha(Colours.inkDim, 0.5)
            font.pixelSize: Appearance.font.size.tiny - 1
            tracking: 1
        }
    }

    Item {
        id: holder

        width: opt.width
        height: childrenRect.height
    }
}

// Every value visible at once; the one in use is lit.
