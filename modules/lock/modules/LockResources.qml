//  VELVET  ·  modules/lock/modules/LockResources.qml
//  The machine's vitals, the fluid lock's way: three resource cells filling
//  the card's whole width — CPU in a pentagon, RAM in a diamond, disk in
//  a pill — each filled from the bottom with a wavy liquid edge, its
//  icon above a big number. The CPU's temperature rides a circle at the
//  pentagon's corner, turning red past 90°. The pill rendering keeps two
//  small glyph cells with the numbers beside them.
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

    implicitWidth: root.compact ? compactRow.width : 340
    implicitHeight: root.compact ? 28 : 190

    readonly property real cell: Math.max(40, Math.min(160, (root.width - 32 - 32) / 3))

    // ── the pill rendering: two small glyph cells with the numbers beside
    Row {
        id: compactRow

        anchors.verticalCenter: parent.verticalCenter
        visible: root.compact
        spacing: 6

        ShapeBadge {
            size: 26
            kind: 6
            hoverKind: -1
            col: Colours.alpha(Colours.accent, 0.16)
            icon: "memory"
            iconCol: Colours.accent
            iconSize: 13
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: `${Math.round(SysInfo.cpuPercent)}%`
            color: Colours.accent
            font.pixelSize: Appearance.font.size.tiny
        }

        ShapeBadge {
            size: 26
            kind: 4
            hoverKind: -1
            col: Colours.alpha(Colours.accentAlt, 0.16)
            icon: "memory_alt"
            iconCol: Colours.accentAlt
            iconSize: 13
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: `${Math.round(SysInfo.memoryPercent)}%`
            color: Colours.accentAlt
            font.pixelSize: Appearance.font.size.tiny
        }
    }

    // ── the card rendering: the cells fill the fluid lock's row
    ModuleCard {
        anchors.fill: parent
        glyphKind: 6
        radius: 28
        carded: root.carded
        visible: !root.compact
    }

    Row {
        anchors.centerIn: parent
        visible: !root.compact
        spacing: 16

        Item {
            id: cpuCell

            width: root.cell
            height: root.cell

            ShapeBadge {
                anchors.fill: parent
                kind: 6
                hoverKind: -1
                col: Colours.alpha(Colours.accent, 0.14)
                fill: SysInfo.cpuPercent / 100
                fillColour: Colours.alpha(Colours.accent, 0.28)
                waveFill: true
                icon: "memory"
                iconCol: Colours.accent
                iconSize: Math.max(16, root.cell * 0.16)
                text: `${Math.round(SysInfo.cpuPercent)}`
            }

            // The fluid lock's touch: the temperature rides a circle at the
            // pentagon's corner, turning danger-red past 90°.
            Item {
                id: tempBadge

                width: Math.max(30, root.cell * 0.34)
                height: width
                x: parent.width - width * 0.55
                y: -height * 0.2
                z: 2
                visible: SysInfo.temperature > 0

                ShapeBadge {
                    anchors.fill: parent
                    kind: 0
                    hoverKind: -1
                    col: SysInfo.temperature > 90 ? Colours.alpha(Colours.danger, 0.95) : Colours.alpha(Colours.accentAlt, 0.95)
                }

                P5Text {
                    anchors.centerIn: parent
                    display: true
                    text: `${Math.round(SysInfo.temperature)}`
                    color: SysInfo.temperature > 90 ? Colours.on(Colours.danger) : Colours.on(Colours.accentAlt)
                    font.pixelSize: Math.max(14, root.cell * 0.14)
                }
            }
        }

        Item {
            width: root.cell
            height: root.cell

            ShapeBadge {
                anchors.fill: parent
                kind: 4
                hoverKind: -1
                col: Colours.alpha(Colours.accentAlt, 0.14)
                fill: SysInfo.memoryPercent / 100
                fillColour: Colours.alpha(Colours.accentAlt, 0.28)
                waveFill: true
                icon: "memory_alt"
                iconCol: Colours.accentAlt
                iconSize: Math.max(16, root.cell * 0.16)
                text: `${Math.round(SysInfo.memoryPercent)}`
            }
        }

        Item {
            width: root.cell
            height: root.cell
            visible: Config.lock.resourcesDisk

            ShapeBadge {
                anchors.fill: parent
                kind: 2
                hoverKind: -1
                col: Colours.alpha(Colours.ink, 0.09)
                fill: SysInfo.storagePercent / 100
                fillColour: Colours.alpha(Colours.inkDim, 0.35)
                waveFill: true
                icon: "hard_drive"
                iconCol: Colours.inkDim
                iconSize: Math.max(16, root.cell * 0.16)
                text: `${Math.round(SysInfo.storagePercent)}`
            }
        }
    }
}
