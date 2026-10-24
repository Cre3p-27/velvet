//  VELVET  ·  modules/wallpaper/DesktopMenu.qml
//  The overlay behind a right-click on the desktop: a scrim that closes on any
//  click, and the menu card floated at the pointer — the desktop's own
//  (DesktopMenuCard) on bare desk, the widget's (WidgetMenuCard) on a widget.
//  Wallpaper.qml opens it through Panels.openDeskMenu() / openWidgetMenu(); it
//  holds the keyboard only while it is up.
import qs.config
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    property bool rendered: false
    property bool entered: false
    property var shown: null
    // the widget this menu is about, kept while it fades out ("" = the desk)
    property string widgetId: ""

    readonly property string want: Panels.deskMenuScreen

    screen: root.shown ?? Hypr.focusedScreen
    visible: root.rendered
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-deskmenu"
    WlrLayershell.keyboardFocus: root.entered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onWantChanged: {
        if (root.want !== "") {
            const list = Quickshell.screens;
            for (let i = 0; i < list.length; i++)
                if (list[i].name === root.want)
                    root.shown = list[i];
            root.widgetId = Panels.deskMenuWidget;
            exitTimer.stop();
            root.rendered = true;
            enterTimer.restart();
            Sfx.open();
        } else {
            root.entered = false;
            exitTimer.restart();
        }
    }

    Timer {
        id: enterTimer

        interval: 1
        onTriggered: {
            root.entered = true;
            keys.forceActiveFocus();
        }
    }

    Timer {
        id: exitTimer

        interval: Appearance.anim.normal
        onTriggered: root.rendered = false
    }

    Item {
        id: keys

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Panels.closeAll()

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: Panels.closeAll()
        }

        Item {
            id: card

            readonly property real wantX: Panels.deskMenuX
            readonly property real wantY: Panels.deskMenuY
            readonly property Item face: root.widgetId !== "" ? widgetCard : deskCard

            width: card.face.width
            height: card.face.height
            x: Math.max(12, Math.min(root.width - width - 12, wantX))
            y: Math.max(12, Math.min(root.height - height - 12, wantY))
            opacity: root.entered ? 1 : 0
            scale: root.entered ? 1 : 0.94
            transformOrigin: Item.TopLeft

            DesktopMenuCard {
                id: deskCard

                visible: root.widgetId === ""
                entered: root.entered && root.widgetId === ""
                atX: root.width > 0 ? Panels.deskMenuX / root.width : 0.5
                atY: root.height > 0 ? Panels.deskMenuY / root.height : 0.5
                onDone: Panels.closeAll()
            }

            WidgetMenuCard {
                id: widgetCard

                visible: root.widgetId !== ""
                widgetId: root.widgetId
                entered: root.entered && root.widgetId !== ""
                onDone: Panels.closeAll()
            }

            Behavior on y {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.4
                }
            }

            // A click on the card is the card's, not the scrim's.
            MouseArea {
                z: -1
                anchors.fill: parent
            }
        }
    }

    // Panels are loaded on demand (shell.qml, Parked): when this window is created by
    // its own flag the change signal has already gone by, so say it once more.
    Timer {
        running: true
        interval: 1
        onTriggered: {
            if (root.want !== "")
                root.wantChanged();
        }
    }
}
