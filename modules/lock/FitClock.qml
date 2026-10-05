//  VELVET  ·  modules/lock/FitClock.qml
//  A clock's digits that never leave their frame. `want` is the size the face
//  would like (its own size times the user's CLOCK SIZE); when the text is
//  wider than `maxWidth` — seconds, 12 hours with AM / PM, a big scale — the
//  size shrinks until it fits. A hidden copy at `want` measures the text.
import qs.config
import qs.components
import QtQuick

P5Text {
    id: root

    property real want: 100
    property real maxWidth: 0

    font.pixelSize: root.maxWidth > 0 && ref.implicitWidth > root.maxWidth ? Math.max(8, root.want * root.maxWidth / ref.implicitWidth) : root.want

    P5Text {
        id: ref

        visible: false
        display: root.display
        text: root.text
        font.family: root.font.family
        font.weight: root.font.weight
        font.italic: root.font.italic
        font.letterSpacing: root.font.letterSpacing
        font.capitalization: root.font.capitalization
        font.pixelSize: root.want
    }
}
