//  VELVET  ·  modules/settings/InsChip.qml
//  One inspector chip: a label (and glyph), lit when chosen, red on hover
//  when it destroys something.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: cp

    property string text: ""
    property string glyph: ""
    property bool lit: false
    property bool danger: false

    signal clicked

    implicitWidth: cpRow.implicitWidth + 20
    implicitHeight: 28
    width: implicitWidth
    height: implicitHeight

    Plate {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: {
            if (cp.lit)
                return Colours.alpha(Colours.accent, cpArea.containsMouse ? 1 : 0.88);
            if (cp.danger && cpArea.containsMouse)
                return Colours.alpha(Colours.danger, 0.8);
            return Colours.alpha(Colours.ink, cpArea.pressed ? 0.2 : (cpArea.containsMouse ? 0.13 : 0.06));
        }
        border.width: 1
        border.color: cp.lit ? Colours.alpha(Colours.accent, 0.4) : Colours.alpha(Colours.ink, 0.1)
        antialiasing: true

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    Row {
        id: cpRow

        anchors.centerIn: parent
        spacing: 5

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: cp.glyph !== ""
            name: cp.glyph
            color: cp.lit ? Colours.on(Colours.accent) : (cp.danger && cpArea.containsMouse ? Colours.on(Colours.danger) : Colours.inkDim)
            font.pixelSize: 14
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            text: cp.text
            color: cp.lit ? Colours.on(Colours.accent) : (cp.danger && cpArea.containsMouse ? Colours.on(Colours.danger) : Colours.ink)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.2
        }
    }

    MouseArea {
        id: cpArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cp.clicked()
    }
}
