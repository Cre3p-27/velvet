//  VELVET  ·  modules/map/EdgeSensorSide.qml
//  The hot zone for an island on the LEFT or RIGHT screen edge (MODULES →
//  DYNAMIC ISLAND → POSITION). Its top-edge twin (EdgeSensor.qml) listens
//  across the whole top edge; this one is only as long as the zone itself
//  (HOT ZONE WIDTH), at the island's height — a strip the full height of the
//  edge would sit on every scrollbar there. A few pixels thin for the same
//  reason: the pointer pushed against the edge always lands in it.
//
//  With the island switched off it opens the map instead, which then slides
//  in from the same edge.
import qs.config
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property string edge: Appearance.islandEdge
    readonly property int zoneLen: Math.max(80, Config.map.edgeWidth)
    readonly property int thick: Math.max(3, Math.min(12, Config.map.edgeHeight))
    readonly property real screenH: root.modelData?.height ?? 1080
    // centred on where the pill rests
    readonly property int zoneTop: Math.round(Math.max(0, Math.min(root.screenH - root.zoneLen, Appearance.edgeY(root.screenH, 38, 38) + 19 - root.zoneLen / 2)))

    screen: modelData
    visible: Config.map.enabled && Config.map.hoverEdge && root.edge !== "top" && !Panels.windowMap && Panels.mapHover === "" && (Config.map.island ? Panels.islandScreen === "" : true)
    color: "transparent"
    WlrLayershell.namespace: "velvet-map-edge"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: -1

    anchors {
        top: true
        left: root.edge === "left"
        right: root.edge !== "left"
    }

    margins {
        top: root.zoneTop
    }

    implicitWidth: root.thick
    implicitHeight: root.zoneLen

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                openTimer.restart();
            else
                openTimer.stop();
        }
    }

    Timer {
        id: openTimer

        interval: Config.map.openDelay
        onTriggered: {
            if (Config.map.island)
                Panels.islandScreen = root.modelData.name;
            else
                Panels.mapHover = root.modelData.name;   // hover-open: no keyboard
        }
    }
}
