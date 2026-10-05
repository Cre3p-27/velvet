//  VELVET  ·  modules/bar/popouts/TrayMenu.qml
//  A tray item's own menu, drawn in our type instead of the platform's.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick

Item {
    id: root

    readonly property int pad: Appearance.padding.small

    implicitWidth: Math.max(200, Math.min(340, column.implicitWidth + pad * 2))
    implicitHeight: column.implicitHeight + pad * 2 + header.height

    QsMenuOpener {
        id: opener
        menu: Popout.trayItem?.menu ?? null
    }

    Item {
        id: header

        width: root.width
        height: title.text ? 30 : 0

        P5Text {
            id: title

            anchors.left: parent.left
            anchors.leftMargin: root.pad + 6
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: (Popout.trayItem?.title ?? "").toUpperCase()
            color: Colours.accent
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
            width: parent.width - root.pad * 2 - 12
        }
    }

    Column {
        id: column

        x: root.pad
        y: header.height
        width: root.width - root.pad * 2

        Repeater {
            model: opener.children

            Item {
                id: entry

                required property var modelData

                width: column.width
                height: modelData.isSeparator ? 9 : 32

                Rectangle {
                    visible: entry.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width - 12
                    height: 1
                    color: Colours.alpha(Colours.ink, 0.14)
                }

                Slash {
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: !entry.modelData.isSeparator && itemArea.containsMouse
                    shear: Appearance.skew
                    color: Colours.alpha(Colours.accent, 0.9)
                }

                Row {
                    visible: !entry.modelData.isSeparator
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entry.modelData.icon !== ""
                        implicitSize: 16
                        source: entry.modelData.icon
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.text ?? ""
                        color: itemArea.containsMouse ? Colours.on(Colours.accent) : (entry.modelData.enabled ? Colours.ink : Colours.alpha(Colours.inkDim, 0.5))
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, column.width - 40)
                    }
                }

                Icon {
                    visible: !entry.modelData.isSeparator && entry.modelData.hasChildren
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevron_right"
                    font.pixelSize: Appearance.font.size.normal
                    color: itemArea.containsMouse ? Colours.on(Colours.accent) : Colours.inkDim
                }

                MouseArea {
                    id: itemArea

                    anchors.fill: parent
                    enabled: !entry.modelData.isSeparator && entry.modelData.enabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    onClicked: {
                        Sfx.select();
                        entry.modelData.triggered();
                        Popout.close();
                    }
                }
            }
        }
    }
}
