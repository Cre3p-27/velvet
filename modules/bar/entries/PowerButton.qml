//  VELVET  ·  modules/bar/entries/PowerButton.qml
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    padding: 4
    active: Panels.session
    tip: "SESSION  ·  RIGHT-CLICK LOCKS"

    onClicked: {
        Sfx.open();
        Panels.toggleSession();
    }
    onRightClicked: Actions.lock()

    Icon {
        name: "power_settings_new"
        font.pixelSize: Config.bar.iconSize
        color: root.active ? Colours.on(Colours.accent) : (root.containsMouse ? Colours.accent : Colours.inkDim)

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }
}
