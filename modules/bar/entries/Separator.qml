//  VELVET  ·  Separator — a hairline you can drop anywhere in the bar.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property bool vertical: true
    property int span: 30
    property var win: null

    implicitWidth: vertical ? span : 2
    implicitHeight: vertical ? 2 : span

    Slash {
        anchors.centerIn: parent
        width: root.vertical ? root.span * 0.7 : 2
        height: root.vertical ? 2 : root.span * 0.7
        shear: root.vertical ? Appearance.skew * 3 : 0
        color: Colours.alpha(Colours.ink, 0.22)
    }
}
