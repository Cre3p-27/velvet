//  VELVET  ·  NotifBell — unread count, and it rings when one arrives.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    readonly property int unread: Notifs.unread
    readonly property bool dnd: Config.notifs.doNotDisturb

    padding: 4
    active: Panels.notifCentre
    tip: "NOTIFICATIONS  ·  RIGHT-CLICK SILENCES"

    onClicked: {
        Sfx.open();
        Panels.toggleNotifCentre();
    }
    onRightClicked: {
        Sfx.toggle();
        Config.toggle("notifs.doNotDisturb");
    }

    onUnreadChanged: {
        if (unread > 0)
            ring.restart();
    }

    Item {
        implicitWidth: Config.bar.iconSize + 6
        implicitHeight: Config.bar.iconSize + 6

        Icon {
            id: glyph

            anchors.centerIn: parent
            name: root.dnd ? "notifications_off" : "notifications"
            font.pixelSize: Config.bar.iconSize
            color: root.dnd ? Colours.alpha(Colours.inkDim, 0.5) : (root.unread > 0 ? Colours.accent : (root.containsMouse ? Colours.accent : Colours.inkDim))

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        // Swings twice, like a bell that was actually struck.
        SequentialAnimation {
            id: ring

            NumberAnimation {
                target: glyph
                property: "rotation"
                to: -16
                duration: 70
            }
            NumberAnimation {
                target: glyph
                property: "rotation"
                to: 13
                duration: 100
            }
            NumberAnimation {
                target: glyph
                property: "rotation"
                to: -7
                duration: 90
            }
            NumberAnimation {
                target: glyph
                property: "rotation"
                to: 0
                duration: 110
                easing.type: Easing.OutBack
            }
        }

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            width: root.unread > 9 ? 15 : 11
            height: 11
            radius: 5.5
            visible: root.unread > 0 && !root.dnd
            color: Colours.accent
            scale: visible ? 1 : 0

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutBack
                    easing.overshoot: 3.4
                }
            }

            P5Text {
                anchors.centerIn: parent
                display: true
                text: root.unread > 9 ? "9+" : `${root.unread}`
                color: Colours.on(Colours.accent)
                font.pixelSize: 8
                tracking: 0
            }
        }
    }
}
