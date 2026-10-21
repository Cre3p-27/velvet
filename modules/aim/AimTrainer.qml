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
    // Parked keeps a closed window loaded for a while: it has to hide itself,
    // or Esc left the trainer on screen — and holding the keyboard — for 10 s
    visible: Panels.aim
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

    // a PanelWindow root has no Component.onCompleted (shell rule); opened
    // again while still loaded, it takes the keys back the same way
    function present(): void {
        game.forceActiveFocus();
        Sfx.open();
    }

    Timer {
        running: true
        interval: 1
        onTriggered: root.present()
    }

    Timer {
        id: again

        interval: 1
        onTriggered: root.present()
    }

    Connections {
        target: Panels

        function onAimChanged(): void {
            if (Panels.aim)
                again.restart();
        }
    }
}
