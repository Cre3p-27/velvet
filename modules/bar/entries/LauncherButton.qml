//  VELVET  ·  LauncherButton — same thing Super+Space does, for the mouse.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    padding: 4
    active: Panels.launcher
    visible: Config.launcher.enabled
    tip: "LAUNCHER  ·  RIGHT-CLICK FOR ITS SETTINGS"

    onClicked: {
        Sfx.open();
        Panels.toggleLauncher();
    }
    onRightClicked: Panels.openSettingsKey("launcher.maxShown")

    Icon {
        name: "search"
        font.pixelSize: Config.bar.iconSize
        color: root.active ? Colours.on(Colours.accent) : (root.containsMouse ? Colours.accent : Colours.inkDim)
        // Leans into the click like the rest of the shell leans.
        rotation: root.containsMouse ? -8 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutBack
                easing.overshoot: 3
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }
}
