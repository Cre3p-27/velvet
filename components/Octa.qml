//  VELVET  ·  components/Octa.qml
//  An octagonal frame with something inside it.
//
//  There is no cheap way to clip an arbitrary polygon in QtQuick, and the ways
//  that exist all pull in an effects module that may or may not be built. So
//  this does it the old way: draw the content square, then cover the four
//  corners with triangles in the surrounding colour and lay eight thin bars
//  along the edges for the outline. Exact, cheap, and it cannot fail to load.
//
//  `ground` therefore has to match whatever is actually behind the item.
import qs.config
import qs.services
import QtQuick

Item {
    id: root

    // Corner cut, as a share of the shorter side. 0.29 is the regular octagon.
    property real cut: 0.29
    property color ground: Colours.paper
    property color borderColor: "transparent"
    property real borderWidth: 0
    // `default`, and it matters: without it a child written inside an Octa is
    // appended to the root's own `data` and therefore drawn AFTER the corner
    // covers — a perfect square with an octagonal outline floating over it.
    default property alias content: holder.data

    readonly property real side: Math.min(width, height)
    readonly property real chamfer: root.side * root.cut

    Item {
        id: holder

        anchors.fill: parent
    }

    // ── the four corners, cut away
    Repeater {
        model: 4

        Item {
            id: corner

            required property int index

            // Not `right`/`bottom`: Item already has those as anchor lines
            // (that is what `parent.right` is), they are FINAL, and shadowing
            // one makes QML refuse the file.
            readonly property bool atRight: index === 1 || index === 2
            readonly property bool atBottom: index >= 2

            x: atRight ? root.width - root.chamfer : 0
            y: atBottom ? root.height - root.chamfer : 0
            width: root.chamfer
            height: root.chamfer
            clip: true

            Rectangle {
                // A square turned 45° covers exactly the triangle outside the
                // chamfer and nothing else, once it is clipped to the corner.
                // The 0.2071 is what puts its diagonal on the chamfer line
                // rather than through the middle of the corner.
                readonly property real nudge: root.chamfer * 0.2071

                width: root.chamfer * 1.4143
                height: root.chamfer * 1.4143
                x: (corner.atRight ? 0 : -width / 2) + (corner.atRight ? -nudge : nudge)
                y: (corner.atBottom ? 0 : -height / 2) + (corner.atBottom ? -nudge : nudge)
                transformOrigin: Item.Center
                rotation: 45
                color: root.ground
                antialiasing: true
            }
        }
    }

    // ── the outline: four straight edges and four diagonals
    Item {
        anchors.fill: parent
        visible: root.borderWidth > 0

        Rectangle {
            x: root.chamfer
            width: root.width - root.chamfer * 2
            height: root.borderWidth
            color: root.borderColor
        }
        Rectangle {
            x: root.chamfer
            y: root.height - root.borderWidth
            width: root.width - root.chamfer * 2
            height: root.borderWidth
            color: root.borderColor
        }
        Rectangle {
            y: root.chamfer
            width: root.borderWidth
            height: root.height - root.chamfer * 2
            color: root.borderColor
        }
        Rectangle {
            x: root.width - root.borderWidth
            y: root.chamfer
            width: root.borderWidth
            height: root.height - root.chamfer * 2
            color: root.borderColor
        }

        Repeater {
            model: 4

            Rectangle {
                required property int index

                readonly property bool atRight: index === 1 || index === 2
                readonly property bool atBottom: index >= 2

                width: root.chamfer * 1.4143
                height: root.borderWidth
                color: root.borderColor
                antialiasing: true

                transformOrigin: Item.Center
                rotation: (atRight === atBottom) ? 45 : -45

                x: (atRight ? root.width - root.chamfer : 0) + root.chamfer / 2 - width / 2
                y: (atBottom ? root.height - root.chamfer : 0) + root.chamfer / 2 - height / 2
            }
        }
    }
}
