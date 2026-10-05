//  VELVET  ·  FocusToggle — one press for "leave me alone", one to come back.
//  While it is on, a ring breathes around the icon so a silenced desktop can
//  never be mistaken for a quiet one.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    readonly property bool on: Focus.active

    padding: 4
    active: root.on
    tip: root.on ? `FOCUS ON  ·  ${Focus.summary}` : "FOCUS MODE  ·  RIGHT-CLICK TO CHOOSE WHAT IT DOES"

    onClicked: {
        // Focus mode can mute the shell's own sounds, so the click has to be
        // played on the right side of the toggle: last thing you hear going
        // in, first thing you hear coming out.
        const goingOn = !Focus.active;
        if (goingOn)
            Sfx.toggle();
        Focus.toggle();
        if (!goingOn)
            Sfx.toggle();
    }
    onRightClicked: Panels.openSettingsKey("services.focusMode")

    Item {
        implicitWidth: root.span
        implicitHeight: root.span

        // The ring. Only drawn while focus mode is on, and it never stops
        // moving, because the whole risk of this feature is forgetting it.
        Rectangle {
            id: ring

            anchors.centerIn: parent
            width: root.span * 0.94
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 2
            // On the accent plate: ink that reads on it, not accent-on-accent.
            border.color: Colours.on(Colours.accent)
            antialiasing: true
            visible: root.on
            opacity: 0

            SequentialAnimation on opacity {
                running: root.on
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.85
                    duration: 1500
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0.18
                    duration: 1500
                    easing.type: Easing.InOutSine
                }
            }

            SequentialAnimation on scale {
                running: root.on
                loops: Animation.Infinite
                NumberAnimation {
                    to: 1.12
                    duration: 1500
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 0.94
                    duration: 1500
                    easing.type: Easing.InOutSine
                }
            }
        }

        Icon {
            anchors.centerIn: parent
            name: root.on ? "do_not_disturb_on" : "do_not_disturb_off"
            font.pixelSize: Config.bar.iconSize
            color: root.on ? Colours.on(Colours.accent) : (root.containsMouse ? Colours.accent : Colours.inkDim)

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        // How much you missed while it was on, in the corner of the icon.
        Slash {
            anchors.right: parent.right
            anchors.top: parent.top
            width: 16
            height: 12
            shear: Appearance.skew * 2
            color: Colours.warning
            visible: root.on && Focus.missed > 0

            P5Text {
                anchors.centerIn: parent
                display: true
                text: Focus.missed > 9 ? "9+" : `${Focus.missed}`
                color: Colours.paper
                font.pixelSize: 9
                tracking: 0
            }
        }
    }
}
