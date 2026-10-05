//  VELVET  ·  modules/lock/modules/LockBattery.qml
//  The battery — a card with a pill watermark; without a battery it still
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

    // the Material low-battery voice: the number and the glyph go red when the
    // battery is genuinely hurting.
    readonly property bool danger: Battery.available && Battery.critical && !Battery.charging

    ModuleCard {
        anchors.fill: parent
        glyphKind: 2
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
            kind: 2
            hoverKind: -1
            col: Colours.alpha(root.danger ? Colours.danger : (Battery.available ? Colours.accent : Colours.inkDim), 0.16)
            icon: Battery.charging ? "battery_charging_full" : "battery_full"
            iconCol: root.danger ? Colours.danger : (Battery.available ? Colours.accent : Colours.alpha(Colours.inkDim, 0.55))
            iconSize: root.compact ? 14 : 17
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: Battery.available ? `${Battery.percent}%` : "—"
            color: root.danger ? Colours.danger : (Battery.available ? Colours.ink : Colours.alpha(Colours.inkDim, 0.55))
            font.pixelSize: root.compact ? Appearance.font.size.small : Appearance.font.size.normal
        }
    }
}
