//  VELVET  ·  components/SoftChip.qml
//  The soft looks' choice pill: quiet outline at rest, filled with the
//  accent when chosen, a soft lift under the pointer, a squash on press.
import qs.config
import qs.services
import QtQuick

Plate {
    id: root

    property string text: ""
    property string icon: ""
    property bool on: false
    property bool dim: false
    property real u: 1
    property string family: Appearance.fontFamily.soft
    property color accent: Colours.accent

    signal clicked

    readonly property bool hot: hover.hovered

    implicitWidth: row.implicitWidth + 26 * root.u
    implicitHeight: 30 * root.u
    radius: Appearance.pill(height)
    color: root.on ? root.accent : (root.hot ? Colours.alpha(Colours.ink, 0.1) : Colours.alpha(Colours.ink, 0.03))
    border.width: root.on ? 0 : 1
    border.color: Colours.alpha(Colours.ink, root.hot ? 0.16 : 0.08)
    opacity: root.dim ? 0.4 : 1
    scale: tap.pressed ? 0.94 : 1
    antialiasing: true

    Behavior on color {
        ColorAnimation {
            duration: 140
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: 110
            easing.type: Easing.OutQuad
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 6 * root.u

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon !== ""
            name: root.icon
            color: root.on ? Colours.on(root.accent) : Colours.ink
            font.pixelSize: 15 * root.u
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.text !== ""
            text: root.text
            color: root.on ? Colours.on(root.accent) : Colours.alpha(Colours.ink, 0.88)
            font.family: root.family
            font.pixelSize: 13 * root.u
            font.weight: root.on ? Font.DemiBold : Font.Medium
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tap

        onTapped: {
            Sfx.select();
            root.clicked();
        }
    }
}
