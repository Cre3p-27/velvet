//  VELVET  ·  modules/bar/popouts/WorkspacePeek.qml
//  What is actually on that workspace, before you switch to it.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Widgets
import QtQuick

Item {
    id: root

    readonly property var windows: Hypr.windowList(Popout.wsId)
    readonly property int pad: Appearance.padding.normal

    implicitWidth: 330
    implicitHeight: column.implicitHeight + pad * 2

    Column {
        id: column

        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        spacing: 6

        Row {
            spacing: 10

            Slash {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                shear: Appearance.skew
                color: Colours.accent

                P5Text {
                    anchors.centerIn: parent
                    display: true
                    text: `${Popout.wsId}`
                    color: Colours.on(Colours.accent)
                    font.pixelSize: Appearance.font.size.normal
                    tracking: 0
                }
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: root.windows.length === 0 ? "EMPTY" : `${root.windows.length} WINDOW${root.windows.length === 1 ? "" : "S"}`
                color: Colours.ink
                font.pixelSize: Appearance.font.size.normal
            }
        }

        // Fixed slot count on purpose: a model binding of `windows.slice(…)
        // would rebuild every row and replay their entrance whenever the
        // list changed. The rows read by index instead and stay put.
        Repeater {
            model: 7

            // An Item, not a Row: the click area fills the whole line, and a
            // Row refuses children with fill anchors (it stopped laying the
            // icon and the title out at all).
            Item {
                id: entry

                required property int index

                readonly property var w: index < root.windows.length ? root.windows[index] : null

                width: column.width
                height: 26
                visible: entry.w !== null

                // Each line slides in a beat after the one above it.
                opacity: 0
                Component.onCompleted: reveal.start()

                SequentialAnimation {
                    id: reveal

                    PauseAnimation {
                        duration: entry.index * 35
                    }
                    NumberAnimation {
                        target: entry
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Appearance.anim.fast
                    }
                }

                MouseArea {
                    id: rowArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sfx.select();
                        if (entry.w?.address)
                            Hypr.focusWindow(entry.w.address);
                        Popout.close();
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 16
                        source: entry.w?.appId ? Quickshell.iconPath(entry.w.appId, "application-x-executable") : ""
                        asynchronous: true
                    }

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: column.width - 24
                        text: entry.w ? (entry.w.title || entry.w.appId || "") : ""
                        color: rowArea.containsMouse ? Colours.accent : Colours.inkDim
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                }
            }
        }

        P5Text {
            visible: root.windows.length > 7
            text: `+ ${root.windows.length - 7} MORE`
            color: Colours.alpha(Colours.inkDim, 0.7)
            font.pixelSize: Appearance.font.size.tiny
            tracking: 1.6
        }
    }
}
