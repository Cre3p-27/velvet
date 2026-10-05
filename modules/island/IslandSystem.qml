//  VELVET  ·  modules/island/IslandSystem.qml
//  The SYSTEM body of the Dynamic Island — CPU (with its little history
//  spark), memory, temperature, storage and uptime, straight from SysInfo.
//
//  The island is ALWAYS black, whatever the wallpaper: all text rides on
//  ink (the palette's light text) and never on paper (its dark one).
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    anchors.fill: parent

    readonly property int labelW: 76
    readonly property int valueW: 96
    readonly property int barX: 24 + root.labelW
    readonly property int barW: Math.max(40, root.width - root.barX - root.valueW - 36)

    // ── CPU
    P5Text {
        x: 24
        y: 22
        width: root.labelW
        display: true
        text: "CPU"
        color: Colours.alpha(Colours.ink, 0.8)
        font.pixelSize: Appearance.font.size.tiny
        tracking: 1.4
    }

    Rectangle {
        x: root.barX
        y: 30
        width: root.barW
        height: 5
        radius: 2.5
        color: Colours.alpha(Colours.ink, 0.15)
    }

    Rectangle {
        x: root.barX
        y: 30
        width: root.barW * Math.max(0, Math.min(1, SysInfo.cpuPercent / 100))
        height: 5
        radius: 2.5
        color: Colours.accent
    }

    P5Text {
        anchors.right: parent.right
        anchors.rightMargin: 24
        y: 22
        width: root.valueW
        horizontalAlignment: Text.AlignRight
        text: `${Math.round(SysInfo.cpuPercent)}%`
        color: Colours.ink
        font.family: Appearance.fontFamily.mono
        font.pixelSize: Appearance.font.size.tiny
    }

    // The last eighty seconds, forty samples — a spark, not a chart.
    Item {
        x: root.barX
        y: 46
        width: root.barW
        height: 30
        clip: true

        // Fixed slot row: the bars stay put and only their heights change
        // when the history rolls, instead of the spark being rebuilt every
        // sample (which would also kill any animation on the delegates).
        Repeater {
            model: 40

            Rectangle {
                required property int index

                readonly property real v: {
                    const h = SysInfo.cpuHistory;
                    const i = h.length - 40 + index;
                    return i >= 0 ? h[i] : 0;
                }

                x: index * (parent.width / 40)
                y: parent.height - Math.max(2, v * 0.28)
                width: Math.max(1.5, parent.width / 40 - 1.2)
                height: Math.max(2, v * 0.28)
                radius: 1
                color: Colours.alpha(Colours.accent, 0.75)
            }
        }
    }

    // ── MEM
    P5Text {
        x: 24
        y: 92
        width: root.labelW
        display: true
        text: "MEM"
        color: Colours.alpha(Colours.ink, 0.8)
        font.pixelSize: Appearance.font.size.tiny
        tracking: 1.4
    }

    Rectangle {
        x: root.barX
        y: 100
        width: root.barW
        height: 5
        radius: 2.5
        color: Colours.alpha(Colours.ink, 0.15)
    }

    Rectangle {
        x: root.barX
        y: 100
        width: root.barW * Math.max(0, Math.min(1, SysInfo.memoryPercent / 100))
        height: 5
        radius: 2.5
        color: Colours.accentAlt
    }

    P5Text {
        anchors.right: parent.right
        anchors.rightMargin: 24
        y: 92
        width: root.valueW
        horizontalAlignment: Text.AlignRight
        text: `${SysInfo.memoryUsedGb.toFixed(1)} / ${SysInfo.memoryTotalGb.toFixed(0)}G`
        color: Colours.ink
        font.family: Appearance.fontFamily.mono
        font.pixelSize: Appearance.font.size.tiny
    }

    // ── TEMP
    P5Text {
        x: 24
        y: 132
        width: root.labelW
        display: true
        text: "TEMP"
        color: Colours.alpha(Colours.ink, 0.8)
        font.pixelSize: Appearance.font.size.tiny
        tracking: 1.4
    }

    Rectangle {
        x: root.barX
        y: 140
        width: root.barW
        height: 5
        radius: 2.5
        color: Colours.alpha(Colours.ink, 0.15)
    }

    Rectangle {
        x: root.barX
        y: 140
        width: root.barW * Math.max(0, Math.min(1, SysInfo.temperature / 95))
        height: 5
        radius: 2.5
        color: SysInfo.temperature > 85 ? Colours.danger : (SysInfo.temperature > 70 ? Colours.warning : Colours.accent)
    }

    P5Text {
        anchors.right: parent.right
        anchors.rightMargin: 24
        y: 132
        width: root.valueW
        horizontalAlignment: Text.AlignRight
        text: `${Math.round(SysInfo.temperature)}°C`
        color: Colours.ink
        font.family: Appearance.fontFamily.mono
        font.pixelSize: Appearance.font.size.tiny
    }

    // ── STORAGE
    P5Text {
        x: 24
        y: 172
        width: root.labelW
        display: true
        text: "DISK"
        color: Colours.alpha(Colours.ink, 0.8)
        font.pixelSize: Appearance.font.size.tiny
        tracking: 1.4
    }

    Rectangle {
        x: root.barX
        y: 180
        width: root.barW
        height: 5
        radius: 2.5
        color: Colours.alpha(Colours.ink, 0.15)
    }

    Rectangle {
        x: root.barX
        y: 180
        width: root.barW * Math.max(0, Math.min(1, SysInfo.storagePercent / 100))
        height: 5
        radius: 2.5
        color: Colours.alpha(Colours.ink, 0.6)
    }

    P5Text {
        anchors.right: parent.right
        anchors.rightMargin: 24
        y: 172
        width: root.valueW
        horizontalAlignment: Text.AlignRight
        text: `${SysInfo.storageUsedGb.toFixed(0)} / ${SysInfo.storageTotalGb.toFixed(0)}G`
        color: Colours.ink
        font.family: Appearance.fontFamily.mono
        font.pixelSize: Appearance.font.size.tiny
    }

    // ── UPTIME
    P5Text {
        x: 24
        y: 212
        width: root.labelW
        display: true
        text: "UP"
        color: Colours.alpha(Colours.ink, 0.8)
        font.pixelSize: Appearance.font.size.tiny
        tracking: 1.4
    }

    P5Text {
        anchors.right: parent.right
        anchors.rightMargin: 24
        y: 212
        width: root.valueW
        horizontalAlignment: Text.AlignRight
        text: SysInfo.uptimeText
        color: Colours.ink
        font.family: Appearance.fontFamily.mono
        font.pixelSize: Appearance.font.size.tiny
    }
}
