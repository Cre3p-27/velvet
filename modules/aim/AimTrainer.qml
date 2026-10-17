//  VELVET  ·  modules/aim/AimTrainer.qml
//  The overlay the secret aim trainer plays in: full screen, above
//  everything, with the keyboard. The game itself is AimGame.qml.
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    screen: Hypr.focusedScreen ?? Quickshell.screens[0]
    color: "transparent"
    WlrLayershell.namespace: "velvet-aim"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusiveZone: -1

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    AimGame {
        id: game

        anchors.fill: parent
        onQuit: Panels.aim = false
    }

    // a PanelWindow root has no Component.onCompleted (shell rule)
    Timer {
        running: true
        interval: 1
        onTriggered: {
            game.forceActiveFocus();
            Sfx.open();
        }
    }
}
