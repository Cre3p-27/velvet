//  VELVET  ·  modules/wallpaper/DeskArrange.qml
//  The window ARRANGE lives in: full screen, above everything, with the
//  keyboard (Panels.arrangeScreen). What it shows is ArrangeDesk.qml. It
//  stays up until the desk has settled back onto the screen, then goes.
import qs.config
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    readonly property string want: Panels.arrangeScreen
    property var shown: null

    screen: root.shown ?? Hypr.focusedScreen ?? Quickshell.screens[0]
    visible: root.want !== "" || desk.lift > 0.004
    color: "transparent"
    WlrLayershell.namespace: "velvet-arrange"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.want !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusiveZone: -1

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    onWantChanged: root.follow()

    function follow(): void {
        if (root.want !== "") {
            const list = Quickshell.screens;
            for (let i = 0; i < list.length; i++)
                if (list[i].name === root.want)
                    root.shown = list[i];
            desk.shown = true;
            desk.forceActiveFocus();
            Sfx.open();
        } else {
            desk.shown = false;
            desk.picked = "";
        }
    }

    ArrangeDesk {
        id: desk

        anchors.fill: parent
        onFinished: {
            Panels.closeArrange();
            Sfx.back();
        }
    }

    // a PanelWindow root has no Component.onCompleted (shell rule): the flag
    // that created this window has already changed — say it once more
    Timer {
        running: true
        interval: 1
        onTriggered: root.follow()
    }
}
