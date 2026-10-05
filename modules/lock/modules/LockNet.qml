//  VELVET  ·  modules/lock/modules/LockNet.qml
//  The network — a card with a pentagon watermark; offline it still
//  speaks, dimmed, instead of disappearing.
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import QtQuick

Item {
    id: root

    property bool compact: false
    property bool carded: true

    implicitHeight: root.compact ? 24 : 84
    implicitWidth: root.compact ? row.width : 300

    ModuleCard {
        anchors.fill: parent
        glyphKind: 6
        carded: root.carded
        visible: !root.compact
    }

    Row {
        id: row

        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.compact ? 0 : 10
        spacing: 8

        ShapeBadge {
            size: root.compact ? 26 : 32
            kind: 6
            hoverKind: -1
            col: Colours.alpha(Net.connected ? Colours.accent : Colours.inkDim, 0.16)
            icon: Net.icon
            iconCol: Net.connected ? Colours.accent : Colours.alpha(Colours.inkDim, 0.55)
            iconSize: root.compact ? 14 : 17
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            width: root.compact ? 90 : 170
            text: Net.connected ? Net.label.toUpperCase() : "OFFLINE"
            color: Net.connected ? Colours.ink : Colours.alpha(Colours.inkDim, 0.55)
            font.pixelSize: root.compact ? Appearance.font.size.tiny : Appearance.font.size.normal
            tracking: 1
            elide: Text.ElideRight
        }
    }
}
