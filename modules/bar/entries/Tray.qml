//  VELVET  ·  modules/bar/entries/Tray.qml
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    property bool vertical: true
    property int span: 30
    property var win: null

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight
    visible: SystemTray.items.values.length > 0

    Grid {
        id: grid

        flow: root.vertical ? Grid.TopToBottom : Grid.LeftToRight
        columns: root.vertical ? 1 : 99
        rows: root.vertical ? 99 : 1
        spacing: Math.round(Config.bar.spacing * 0.6)
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Repeater {
            model: SystemTray.items

            Item {
                id: entry

                required property SystemTrayItem modelData

                implicitWidth: Config.bar.iconSize + 8
                implicitHeight: Config.bar.iconSize + 8

                scale: area.pressed ? 0.88 : (area.containsMouse ? 1.12 : 1.0)

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                        easing.overshoot: 2.6
                    }
                }

                Plate {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    visible: Config.bar.tray.background
                    color: Colours.alpha(Colours.ink, area.containsMouse ? 0.16 : 0.07)

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: Config.bar.iconSize
                    source: entry.modelData.icon
                    asynchronous: true
                }

                // Attention marker — a hard little accent notch, not a badge.
                Rectangle {
                    visible: entry.modelData.status === SystemTrayItem.NeedsAttention
                    width: 5
                    height: 5
                    radius: 2.5
                    color: Colours.accent
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 1
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor

                    onClicked: event => {
                        Sfx.cursor();
                        if (event.button === Qt.MiddleButton) {
                            entry.modelData.secondaryActivate();
                            return;
                        }
                        if (event.button === Qt.RightButton || entry.modelData.isMenu) {
                            if (entry.modelData.hasMenu) {
                                Popout.trayItem = entry.modelData;
                                Popout.pin("tray", entry, root.win);
                            }
                            return;
                        }
                        entry.modelData.activate();
                    }
                }
            }
        }
    }
}
