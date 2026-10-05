//  VELVET  ·  components/DesktopStrip.qml
//  Every desktop as one pill — a click picks it — and the infinite canvas
//  beside them. One strip for the desktop right-click menu and the DESKTOP
//  editor. What a click does is the caller's: the menu goes there and closes,
//  the editor goes there and stays open.
import qs.config
import qs.services
import QtQuick

Flow {
    id: root

    property var model: Desk.cells
    property bool showCanvas: true
    property int pillWidth: 46
    property int pillHeight: 36
    // Which pill is lit, and what the dots under each number count.
    property int current: Hypr.activeWsId
    property var countOf: ws => Hypr.windowsOn(ws)
    // A click on a pill also takes you to that desktop, unless told not to.
    property bool goes: true
    // The desktop a carried thing would land on, lit up (-1: none).
    property int aimed: -1

    signal picked(int ws)
    signal canvasPicked

    spacing: 6

    Repeater {
        model: root.model

        Item {
            id: pill

            required property var modelData

            readonly property bool here: modelData.ws === root.current
            readonly property int count: root.countOf(modelData.ws)
            readonly property bool aim: modelData.ws === root.aimed

            width: root.pillWidth
            height: root.pillHeight
            scale: pill.aim ? 1.18 : (area.pressed ? 0.93 : (area.containsMouse ? 1.07 : 1))

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutBack
                    easing.overshoot: 2
                }
            }

            Slash {
                anchors.fill: parent
                color: pill.here ? Colours.accent : (pill.aim ? Colours.alpha(Colours.accent, 0.6) : area.containsMouse ? Colours.alpha(Colours.accent, 0.28) : Colours.alpha(Colours.surface, 0.85))
                borderColor: pill.here ? "transparent" : Colours.alpha(Colours.accent, pill.aim || area.containsMouse ? 0.9 : 0.4)
                borderWidth: pill.here ? 0 : 1.5
            }

            P5Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: pill.count > 0 ? -2 : 0
                display: true
                text: `${pill.modelData.ws}`
                color: pill.here ? Colours.paper : Colours.ink
                font.pixelSize: Appearance.font.size.normal
            }

            // One dot per window, up to four: a desktop you can see is busy.
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                spacing: 2

                Repeater {
                    model: Math.min(4, pill.count)

                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: pill.here ? Colours.paper : Colours.accent
                    }
                }
            }

            MouseArea {
                id: area

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: Sfx.cursor()
                onClicked: {
                    Sfx.select();
                    if (root.goes)
                        Hypr.focusWorkspace(pill.modelData.ws);
                    root.picked(pill.modelData.ws);
                }
            }
        }
    }

    Item {
        id: canvas

        visible: root.showCanvas
        width: canvasRow.width + 26
        height: root.pillHeight
        scale: canvasArea.pressed ? 0.95 : (canvasArea.containsMouse ? 1.05 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
                easing.overshoot: 2
            }
        }

        Slash {
            anchors.fill: parent
            color: canvasArea.containsMouse ? Colours.accent : Colours.alpha(Colours.accent, 0.16)
            borderColor: Colours.accent
            borderWidth: canvasArea.containsMouse ? 0 : 1.5
        }

        Row {
            id: canvasRow

            anchors.centerIn: parent
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "hub"
                color: canvasArea.containsMouse ? Colours.paper : Colours.accent
                font.pixelSize: 17
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: "CANVAS"
                color: canvasArea.containsMouse ? Colours.paper : Colours.ink
                font.pixelSize: Appearance.font.size.small
            }
        }

        MouseArea {
            id: canvasArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: Sfx.cursor()
            onClicked: {
                Sfx.select();
                root.canvasPicked();
                Panels.toggleWindowMap();
            }
        }
    }
}
