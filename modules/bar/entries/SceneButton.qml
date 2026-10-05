//  VELVET  ·  SceneButton — the desktop you arranged, one click away.
//
//  Click opens the designer; middle-click brings up whatever is not already
//  running. A dot in the corner says the scene is fully open, so you can tell
//  at a glance whether anything is missing.
import qs.config
import qs.services
import qs.components
import QtQuick

BarButton {
    id: root

    readonly property int total: Scenes.count
    readonly property int live: Scenes.liveCount
    readonly property bool complete: root.total > 0 && root.live >= root.total

    padding: 4
    active: root.complete
    tip: root.total === 0 ? "DESKTOP  ·  NOTHING ARRANGED YET  ·  CLICK TO BUILD ONE" : `DESKTOP  ·  ${root.live} OF ${root.total} OPEN  ·  MIDDLE-CLICK OPENS THE REST`

    onClicked: {
        Sfx.open();
        Panels.openSettingsTabNamed("DESKTOP");
    }
    onMiddleClicked: {
        Sfx.select();
        Scenes.launchAll(false);
    }
    onRightClicked: Panels.openSettingsKey("scene.autostart")

    Icon {
        name: "space_dashboard"
        font.pixelSize: Config.bar.iconSize
        color: root.active ? Colours.on(Colours.accent) : (root.containsMouse ? Colours.accent : Colours.inkDim)

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 2
        width: 5
        height: 5
        radius: 2.5
        visible: root.total > 0 && !root.complete
        color: Colours.accent
        antialiasing: true
    }
}
