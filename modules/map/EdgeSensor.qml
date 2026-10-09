//  VELVET  ·  modules/map/EdgeSensor.qml
//  The invisible strip at the top of each screen that opens the island.
//
//  It exists as its own tiny window for one reason: every attempt to give
//  the full-screen map window a strip-shaped input mask while it was closed
//  delivered ZERO hover events on this machine — the mask worked, but the
//  pointer never arrived. The bar's geometry is the proven pattern here:
//  a small window that is exactly the size of the strip, with the listener
//  on the window itself and no mask trickery at all.
//
//  The strip listens across the whole top edge, but only its middle raises
//  the island — the pointer position decides, not a region. With the island
//  switched off (map.island), it keeps its old job and opens the map
//  directly.
import qs.config
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property int stripW: Math.max(80, Config.map.edgeWidth)
    readonly property int stripH: Math.max(10, Config.map.edgeHeight)

    screen: modelData
    // Away while the island or the map itself is up: both need the top
    // edge, and the strip must not steal from it.
    // Only while the island lives on the top edge: on a side edge its own
    // strip there (EdgeSensorSide) raises it.
    visible: Config.map.enabled && Config.map.hoverEdge && Appearance.islandEdge === "top" && !Panels.windowMap && Panels.mapHover === "" && (Config.map.island ? Panels.islandScreen === "" : true)
    color: "transparent"
    WlrLayershell.namespace: "velvet-map-edge"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: -1

    anchors {
        left: true
        right: true
        top: true
    }

    implicitHeight: root.stripH

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered)
                root.reschedule();
            else
                openTimer.stop();
        }

        onPointChanged: root.reschedule()
    }

    function reschedule(): void {
        if (!hover.hovered)
            return;
        // Middle of the top edge only — measured from the pointer position.
        const pt = hover.point ? hover.point.position : null;
        if (pt && pt.x >= 0) {
            // The position arrives in the compositor's global scene, not in
            // this window's coordinates — bring it home via the screen's
            // origin in the layout.
            const sx = root.modelData?.x ?? 0;
            const localX = pt.x - sx;
            // the zone stands where the pill rests (SHIFT SIDEWAYS moves both)
            const centre = root.width / 2 + Config.map.islandShift;
            const dx = Math.abs(localX - Math.max(root.stripW / 2, Math.min(root.width - root.stripW / 2, centre)));
            if (dx <= root.stripW / 2)
                openTimer.restart();
            else
                openTimer.stop();
            return;
        }
        // No position to measure — accept the hover as-is rather than
        // letting the map stay dead.
        openTimer.restart();
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
