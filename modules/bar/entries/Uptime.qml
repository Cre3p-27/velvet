//  VELVET  ·  Uptime — how long since the last reboot.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    padding: 4
    tip: `UPTIME  ·  ${SysInfo.uptimeText || "JUST BOOTED"}  ·  CLICK FOR THE MACHINE`

    onClicked: {
        Sfx.cursor();
        Popout.pin("quick", root, root.win);
    }

    implicitWidth: vertical ? span : row.implicitWidth
    implicitHeight: vertical ? col.implicitHeight : span

    // One frame sized by whichever of the two is showing: centring them in
    // the button's own content box (which sizes itself by its children)
    // was a loop Qt warned about on every start.
    Item {
        width: root.vertical ? col.implicitWidth : row.implicitWidth
        height: root.vertical ? col.implicitHeight : row.implicitHeight

        Column {
            id: col

            visible: root.vertical
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "timer"
                font.pixelSize: Config.bar.iconSize * 0.85
                color: Colours.alpha(Colours.inkDim, 0.85)
            }

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: SysInfo.uptimeText
                color: Colours.inkDim
                font.pixelSize: Config.bar.fontSize * 0.72
            }
        }

        Row {
            id: row

            visible: !root.vertical
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "timer"
                font.pixelSize: Config.bar.iconSize * 0.85
                color: Colours.alpha(Colours.inkDim, 0.85)
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: SysInfo.uptimeText
                color: Colours.inkDim
                font.pixelSize: Config.bar.fontSize * 0.86
            }
        }
    }
}
