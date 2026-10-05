//  VELVET  ·  components/Halftone.qml
//  Comic-print dot texture. White dots at low opacity over whatever is behind,
//  which reads as ink on paper without needing a shader or an effects module.
import qs.config
import QtQuick

Item {
    id: root

    property real density: 1.0      // 1 = coarse dots, 2 = fine
    property real strength: 0.05
    property real angle: -18
    property bool diagonal: false   // swap dots for speed hatching

    visible: Config.appearance.halftone && strength > 0
    clip: true

    Image {
        anchors.centerIn: parent
        // Oversized so rotation never exposes an edge.
        width: parent.width * 1.6
        height: parent.height * 1.6
        source: root.diagonal ? Qt.resolvedUrl("../assets/scanline.svg") : (root.density > 1.4 ? Qt.resolvedUrl("../assets/halftone-fine.svg") : Qt.resolvedUrl("../assets/halftone.svg"))
        fillMode: Image.Tile
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
        opacity: root.strength
        rotation: root.angle
        smooth: true
        cache: true
    }
}
