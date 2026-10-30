//  VELVET  ·  modules/island/IslandScratch.qml
//  The island's SCRATCHPAD module: the endless sheet (modules/scratch/
//  ScratchBoard) right in the capsule. The island feeds it the keyboard,
//  waits for it (`busy`) before a hand on it may close anything, and takes
//  the keys back when a text or a note has been written (`doneTyping`).
import qs.config
import qs.services
import qs.modules.scratch
import QtQuick

Item {
    id: root

    property bool live: false
    property bool keys: false
    property color ground: Colours.surface

    readonly property bool busy: board.busy

    signal poked
    signal doneTyping

    function handleKey(event: var): bool {
        return board.handleKey(event);
    }

    ScratchBoard {
        id: board

        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 4
        anchors.bottomMargin: 10
        live: root.live
        keys: root.keys
        ground: root.ground
        onPoked: root.poked()
        onDoneTyping: root.doneTyping()
    }
}
