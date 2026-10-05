//  VELVET  ·  MapButton — opens the window map without reaching for the edge.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    padding: 4
    active: Panels.windowMap
    visible: Config.map.enabled
    tip: `WINDOW MAP  ·  ${Desk.windows.length} WINDOWS  ·  OR JUST REACH FOR THE TOP EDGE`

    onClicked: {
        Sfx.open();
        Panels.toggleWindowMap();
    }
    onRightClicked: Panels.openSettingsKey("map.enabled")

    Icon {
        name: "grid_view"
        font.pixelSize: Config.bar.iconSize
        color: root.active ? Colours.on(Colours.accent) : (root.containsMouse ? Colours.accent : Colours.inkDim)

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }
}
