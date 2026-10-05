//  VELVET  ·  modules/lock/modules/LockUser.qml
//  Who is coming back — a card with a circle watermark, the living glyph
//  and the name. In a pill it shrinks to the glyph and the name.
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import Quickshell
import QtQuick

Item {
    id: root

    property bool compact: false
    property bool carded: true

    implicitHeight: root.compact ? 24 : 84
    implicitWidth: root.compact ? row.width : 340

    ModuleCard {
        anchors.fill: parent
        glyphKind: 0
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
            kind: 0
            hoverKind: -1
            col: Colours.alpha(Colours.accent, 0.16)
            icon: "account_circle"
            iconCol: Colours.accent
            iconSize: root.compact ? 14 : 17
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: Locker.user || "USER"
            color: Colours.ink
            font.pixelSize: root.compact ? Appearance.font.size.small : Appearance.font.size.normal
            elide: Text.ElideRight
            width: root.compact ? 90 : 180
        }
    }
}
