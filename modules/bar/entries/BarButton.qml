//  VELVET  ·  modules/bar/entries/BarButton.qml
//  Shared hit target for bar entries: hover lift, press squash, accent wash.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property bool vertical: true
    property int span: 30
    property real padding: 4
    property bool active: false
    property bool hoverable: true
    // Shown next to the bar after a beat of hovering. Empty means no tip.
    property string tip: ""
    property var win: null
    default property alias content: holder.data

    property alias containsMouse: mouse.containsMouse
    signal clicked(var mouseEvent)
    signal rightClicked(var mouseEvent)
    signal middleClicked(var mouseEvent)

    implicitWidth: (holder.childrenRect.width || span) + padding * 2
    implicitHeight: (holder.childrenRect.height || span) + padding * 2

    scale: mouse.pressed ? 0.9 : (mouse.containsMouse && hoverable ? 1.09 : 1.0)

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.anim.fast
            easing.type: Easing.OutBack
            easing.overshoot: 2.4
        }
    }

    // Soft halo that swells under the pointer before the plate itself reacts.
    Plate {
        anchors.centerIn: parent
        width: parent.width + (mouse.containsMouse && root.hoverable ? 10 : 0)
        height: parent.height + (mouse.containsMouse && root.hoverable ? 10 : 0)
        radius: Appearance.rounding.normal
        color: Colours.alpha(Colours.accent, mouse.containsMouse && root.hoverable ? 0.14 : 0)
        antialiasing: true
        z: -1

        Behavior on width {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutBack
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutBack
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.normal
            }
        }
    }

    Plate {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: root.active ? Colours.alpha(Colours.accent, 0.9) : Colours.alpha(Colours.accent, mouse.containsMouse && root.hoverable ? 0.22 : 0.0)
        antialiasing: true
        clip: true

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        Ripple {
            id: ripple

            anchors.fill: parent
            color: root.active ? Colours.paper : Colours.accent
        }
    }

    Item {
        id: holder

        anchors.centerIn: parent
        width: childrenRect.width
        height: childrenRect.height
    }

    Timer {
        id: tipTimer
        interval: 550
        onTriggered: {
            if (mouse.containsMouse && root.tip !== "")
                Popout.tip(root.tip, root, root.win);
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true

        onEntered: tipTimer.restart()
        onExited: {
            tipTimer.stop();
            Popout.release("tip");
        }
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: event => {
            ripple.pop(event.x, event.y);
            if (event.button === Qt.RightButton)
                root.rightClicked(event);
            else if (event.button === Qt.MiddleButton)
                root.middleClicked(event);
            else
                root.clicked(event);
        }
    }
}
