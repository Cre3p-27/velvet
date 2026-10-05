//  VELVET  ·  KeysButton — every shortcut in the shell, one click away.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    padding: 4
    active: Panels.keys
    tip: "SHORTCUTS  ·  SUPER+SHIFT+K"

    onClicked: {
        Sfx.open();
        Panels.toggleKeys();
    }

    Icon {
        name: "keyboard"
        font.pixelSize: Config.bar.iconSize
        color: root.active ? Colours.on(Colours.accent) : (root.containsMouse ? Colours.accent : Colours.inkDim)

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }
}
