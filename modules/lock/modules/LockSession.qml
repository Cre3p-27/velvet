//  VELVET  ·  modules/lock/modules/LockSession.qml
//  The fluid lock's fetch card, in velvet's voice: a prompt chip, mono lines
//  for OS, WM, user, uptime and battery, and a colour row of the shell's
//  own palette in its 28px boxes. Its 12px corners, its quiet mono look.
//  In a pill it shrinks to the glyph and the uptime.
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

    implicitHeight: root.compact ? 24 : 206
    implicitWidth: root.compact ? row.width : 340

    ModuleCard {
        anchors.fill: parent
        glyphKind: 6
        radius: 12
        carded: root.carded
        visible: !root.compact
    }

    // ── the island rendering: terminal glyph and uptime
    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        visible: root.compact
        spacing: 7

        ShapeBadge {
            size: 26
            kind: 6
            hoverKind: -1
            col: Colours.alpha(Colours.accent, 0.16)
            icon: "terminal"
            iconCol: Colours.accent
            iconSize: 14
        }

        P5Text {
            anchors.verticalCenter: parent.verticalCenter
            display: true
            text: SysInfo.uptimeText ? `UP ${SysInfo.uptimeText}` : "SESSION"
            color: Colours.ink
            font.pixelSize: Appearance.font.size.small
        }
    }

    // ── the card: the fetch, the fluid lock's order
    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10
        visible: !root.compact

        Row {
            spacing: 8

            ShapeBadge {
                size: 28
                kind: 6
                hoverKind: -1
                col: Colours.accent
                text: ">"
            }

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "velvet-fetch"
                color: Colours.inkDim
                font.family: Appearance.fontFamily.mono
                font.pixelSize: 14
            }
        }

        Column {
            width: parent.width
            spacing: 5

            Line {
                label: "OS"
                value: SysInfo.osPrettyName || "UNKNOWN"
            }

            Line {
                label: "WM"
                value: "HYPRLAND"
            }

            Line {
                label: "USER"
                value: SysInfo.hostname ? `${Locker.user || "?"}@${SysInfo.hostname}` : (Locker.user || "?")
            }

            Line {
                label: "UP"
                value: SysInfo.uptimeText || "—"
            }

            // A desktop has no battery — say which shell it is instead of
            // a lonely dash.
            Line {
                label: Battery.available ? "BATT" : "SHELL"
                value: Battery.available ? `${Battery.percent}%${Battery.charging ? " (+)" : ""}` : Build.label
            }
        }

        // The fluid lock's colour row — the shell's own palette, straight from
        // the current wallpaper, in its 28px boxes.
        Row {
            spacing: 12

            Repeater {
                model: [Colours.accent, Colours.accentAlt, Colours.ink, Colours.inkDim, Colours.surfaceHigh, Colours.warning, Colours.danger, Colours.paper]

                Rectangle {
                    required property var modelData

                    width: 28
                    height: 28
                    radius: 12
                    color: modelData
                    // A hairline, so the swatches as dark as the card stay
                    // swatches instead of holes in the row.
                    border.width: 1
                    border.color: Colours.alpha(Colours.ink, 0.14)
                    antialiasing: true
                }
            }
        }
    }

    // One mono line of the fetch: label padded, value in ink.
    component Line: Row {
        id: line

        required property string label
        required property string value

        spacing: 12

        P5Text {
            width: 52
            text: line.label
            color: Colours.alpha(Colours.inkDim, 0.65)
            font.family: Appearance.fontFamily.mono
            font.pixelSize: 13
        }

        P5Text {
            text: line.value
            color: Colours.ink
            font.family: Appearance.fontFamily.mono
            font.pixelSize: 13
            elide: Text.ElideRight
            width: Math.max(120, root.width - 32 - 52 - 12)
        }
    }
}
