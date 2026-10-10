//  VELVET  ·  modules/island/IslandMap.qml
//  The island's DESKTOP module: the infinite canvas (modules/map/MapCanvas)
//  right inside the capsule, on the island's own ground — no hand-off to a
//  second window any more. The island feeds it the keyboard and waits for
//  it (`busy`) before it lets a drag's pointer close anything.
import qs.config
import qs.services
import qs.modules.map
import QtQuick

Item {
    id: root

    property bool live: false
    property bool keys: false
    property color ground: Colours.surface

    readonly property bool busy: canvas.busy

    signal poked

    function handleKey(event: var): bool {
        return canvas.handleKey(event);
    }

    MapCanvas {
        id: canvas

        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 4
        anchors.bottomMargin: 10
        live: root.live
        keys: root.keys
        ground: root.ground
        onPoked: root.poked()
    }
}
