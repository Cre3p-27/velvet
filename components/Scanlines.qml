//  VELVET  ·  components/Scanlines.qml
//  CRT lines laid over a surface — VISUALS → SCANLINES. Draws nothing at 0,
//  takes no clicks, and sits above whatever it covers.
import qs.config
import QtQuick

Item {
    id: root

    property real strength: Config.appearance.scanlines

    visible: root.strength > 0.01
    enabled: false
    clip: true

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("../assets/crt.svg")
        fillMode: Image.Tile
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
        opacity: Math.min(0.75, root.strength * 0.7)
        smooth: false
        cache: true
    }
}
