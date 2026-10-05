//  VELVET  ·  modules/settings/WinFrameXp.qml
//  The settings window of Windows XP: a bright blue rounded title bar, the
//  rooms as the tabs of a property sheet, a blue task pane for the
//  categories, a white page for the settings, a cream status line.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var host: null
    property bool back: false

    readonly property real fx: root.host.frameX
    readonly property real fy: root.host.frameY
    readonly property real fw: root.host.frameW
    readonly property real fh: root.host.frameH
    readonly property int zoneSel: root.host.flipTarget >= 0 ? root.host.flipTarget : root.host.zone
    readonly property real titleH: 30
    readonly property real pageTop: root.fy + 61
    readonly property real pageBottom: root.fy + root.fh - root.host.footH + 5
    readonly property color link: "#215dc6"
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ═══ behind the lists: the window, its page, the task pane, the white list
    Item {
        anchors.fill: parent
        visible: root.back

        // what it casts
        Repeater {
            model: 4

            Rectangle {
                required property int index

                x: root.fx - index * 2 + 3
                y: root.fy + 6 + index
                width: root.fw + index * 4 - 2
                height: root.fh + index * 4 - 2
                radius: 9 + index * 2
                color: Qt.rgba(0, 0, 0, 0.1 - index * 0.02)
            }
        }
        // the frame: blue edge, rounded at the top
        Rectangle {
            x: root.fx
            y: root.fy
            width: root.fw
            height: root.fh
            radius: 8
            color: "#0831d9"
        }
        // title bar
        Item {
            x: root.fx
            y: root.fy
            width: root.fw
            height: root.titleH
            clip: true

            Rectangle {
                width: parent.width
                height: root.titleH + 10
                radius: 8

                gradient: Gradient {
                    GradientStop {
                        position: 0
                        color: "#0997ff"
                    }
                    GradientStop {
                        position: 0.1
                        color: "#0a5de6"
                    }
                    GradientStop {
                        position: 0.45
                        color: "#0054e3"
                    }
                    GradientStop {
                        position: 0.9
                        color: "#0050d6"
                    }
                    GradientStop {
                        position: 1
                        color: "#003dd7"
                    }
                }
            }
        }
        // the window's face
        Rectangle {
            x: root.fx + 3
            y: root.fy + root.titleH
            width: root.fw - 6
            height: root.fh - root.titleH - 3
            color: "#ece9d8"
        }
        // the page of the property sheet
        Rectangle {
            x: root.fx + 9
            y: root.pageTop
            width: root.fw - 18
            height: root.pageBottom - root.pageTop
            color: "#fcfcfe"
            border.width: 1
            border.color: "#919b9c"
        }
        // the task pane
        Rectangle {
            visible: root.host.zone === 1
            x: root.host.railX
            y: root.host.bodyY
            width: root.host.railW
            height: root.host.bodyH
            radius: 4

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: WinTheme.paneA
                }
                GradientStop {
                    position: 1
                    color: WinTheme.paneB
                }
            }
        }
        // the white page of settings
        Rectangle {
            visible: root.host.zone === 1
            x: root.host.listX - 2
            y: root.host.bodyY
            width: root.host.listW + 4
            height: root.host.bodyH
            color: "#ffffff"
            border.width: 1
            border.color: "#7f9db9"
        }
        // the status line
        Rectangle {
            x: root.fx + 3
            y: root.fy + root.fh - 26
            width: root.fw - 6
            height: 1
            color: "#aca899"
        }
    }

    // ═══ above them
    Item {
        anchors.fill: parent
        visible: !root.back

        // ── the title
        Row {
            x: root.fx + 9
            y: root.fy + 5
            height: 22
            spacing: 7

            WinLogo {
                anchors.verticalCenter: parent.verticalCenter
                width: 17
                height: 17
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: tt.implicitWidth
                height: tt.implicitHeight

                P5Text {
                    x: 1
                    y: 1
                    text: tt.text
                    color: "#0a246a"
                    opacity: 0.7
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }
                P5Text {
                    id: tt

                    text: "Velvet Settings" + (root.host.zone === 1 && !root.host.home ? " - " + Appearance.titled(root.host.tab?.name ?? "") : "")
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                }
            }
        }
        Row {
            x: root.fx + root.fw - width - 6
            y: root.fy + 5
            spacing: 2

            Repeater {
                model: ["min", "max", "close"]

                Item {
                    id: cap

                    required property string modelData
                    required property int index

                    readonly property bool close: cap.modelData === "close"

                    width: 21
                    height: 21

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        border.width: 1
                        border.color: "#ffffff"

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: cap.close ? (capArea.pressed ? "#c1311b" : "#e8896f") : (capArea.pressed ? "#1f4fbd" : "#6a9bf5")
                            }
                            GradientStop {
                                position: 0.5
                                color: cap.close ? (capArea.containsMouse ? "#e0442a" : "#d6502e") : (capArea.containsMouse ? "#3d78f0" : "#2f66dd")
                            }
                            GradientStop {
                                position: 1
                                color: cap.close ? "#c53a1e" : "#2253c9"
                            }
                        }
                    }
                    // the glyph
                    Rectangle {
                        visible: cap.modelData === "min"
                        x: 6
                        y: 13
                        width: 8
                        height: 3
                        color: "#ffffff"
                    }
                    Rectangle {
                        visible: cap.modelData === "max"
                        anchors.centerIn: parent
                        width: 10
                        height: 9
                        color: "transparent"
                        border.width: 2
                        border.color: "#ffffff"
                    }
                    P5Text {
                        visible: cap.close
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -1
                        text: "✕"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.weight: Font.Black
                    }
                    MouseArea {
                        id: capArea

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (cap.close)
                            Panels.closeSettings()
                    }
                }
            }
        }

        // ── the tabs: the rooms
        Row {
            x: root.fx + 11
            y: root.fy + 34
            spacing: 0

            Repeater {
                model: root.host.zones

                Item {
                    id: ztab

                    required property var modelData
                    required property int index

                    readonly property bool sel: ztab.index === root.zoneSel

                    width: zt.implicitWidth + 30
                    height: ztab.sel ? 28 : 24
                    y: ztab.sel ? -1 : 3

                    Rectangle {
                        anchors.fill: parent
                        anchors.bottomMargin: -2
                        radius: 3
                        border.width: 1
                        border.color: "#919b9c"
                        color: ztab.sel ? "#fcfcfe" : (zma.containsMouse ? "#f4f3ee" : "#ece9d8")
                    }
                    // the orange line over the open tab
                    Rectangle {
                        visible: ztab.sel
                        x: 1
                        y: 0
                        width: parent.width - 2
                        height: 3
                        radius: 1
                        color: "#ffc83c"
                    }
                    Rectangle {
                        visible: ztab.sel
                        x: 1
                        y: parent.height - 1
                        width: parent.width - 2
                        height: 4
                        color: "#fcfcfe"
                    }
                    P5Text {
                        id: zt

                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1
                        text: Appearance.titled(ztab.modelData.name)
                        color: "#000000"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: zma

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.host.setZone(ztab.index)
                    }
                }
            }
        }

        // ── the task pane: the categories
        Item {
            id: nav

            visible: root.host.zone === 1
            x: root.host.railX
            y: root.host.bodyY
            width: root.host.railW
            height: root.host.bodyH
            opacity: root.host.flipping ? 0 : 1

            // the header of the group
            Rectangle {
                x: 10
                y: 10
                width: parent.width - 20
                height: 24
                radius: 4

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: "#ffffff"
                    }
                    GradientStop {
                        position: 1
                        color: "#c6d3f7"
                    }
                }

                P5Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Categories"
                    color: "#215dc6"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }
            // its body
            Rectangle {
                x: 10
                y: 34
                width: parent.width - 20
                height: Math.min(parent.height - 44, Schema.tabs.length * 28 + 14)
                color: "#d6dff7"
                clip: true

                Column {
                    y: 7
                    width: parent.width

                    Repeater {
                        model: Schema.tabs

                        Item {
                            id: row

                            required property var modelData
                            required property int index

                            readonly property bool sel: row.index === root.host.tabIndex

                            width: parent.width
                            height: 28

                            Rectangle {
                                x: 4
                                y: 1
                                width: parent.width - 8
                                height: parent.height - 2
                                radius: 3
                                color: row.sel ? (root.host.column === 0 ? "#316ac5" : "#ffffff") : (rma.containsMouse ? "#eaf0fc" : "transparent")
                                opacity: row.sel && root.host.column !== 0 ? 0.75 : 1
                            }
                            Icon {
                                x: 10
                                anchors.verticalCenter: parent.verticalCenter
                                name: row.modelData.icon
                                color: row.sel && root.host.column === 0 ? "#ffffff" : "#215dc6"
                                font.pixelSize: 17
                            }
                            P5Text {
                                x: 36
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 40
                                elide: Text.ElideRight
                                text: Appearance.titled(row.modelData.name)
                                color: row.sel && root.host.column === 0 ? "#ffffff" : (rma.containsMouse ? "#428eff" : "#215dc6")
                                font.pixelSize: 12
                                font.weight: row.sel ? Font.Bold : Font.Normal
                                font.underline: rma.containsMouse && !row.sel
                            }
                            MouseArea {
                                id: rma

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.host.enterTab(row.index)
                            }
                        }
                    }
                }
            }
        }

        // ── the front page: pick a category, in the old control-panel style
        Item {
            id: front

            visible: root.host.zone === 1 && root.host.home
            x: root.host.listX
            y: root.host.bodyY + 1
            width: root.host.listW
            height: root.host.bodyH - 2
            opacity: root.host.entered && !root.host.flipping ? 1 : 0
            clip: true

            Rectangle {
                width: parent.width
                height: 38

                gradient: Gradient {
                    orientation: Gradient.Horizontal

                    GradientStop {
                        position: 0
                        color: "#f4f6fd"
                    }
                    GradientStop {
                        position: 1
                        color: "#d4dff8"
                    }
                }

                P5Text {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Pick a category"
                    color: "#215dc6"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }
            }

            Grid {
                x: 16
                y: 56
                width: parent.width - 32
                columns: Math.max(1, Math.floor((parent.width - 32) / 280))
                columnSpacing: 10
                rowSpacing: 6

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: tile

                        required property var modelData
                        required property int index

                        width: 270
                        height: 54

                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: tma.containsMouse ? "#e8f0fd" : "transparent"
                            border.width: 1
                            border.color: tma.containsMouse ? "#b4c8ee" : "transparent"
                        }
                        Rectangle {
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 38
                            height: 38
                            radius: 19

                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: "#9fc0f7"
                                }
                                GradientStop {
                                    position: 1
                                    color: "#4a7fe0"
                                }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: tile.modelData.icon
                                color: "#ffffff"
                                font.pixelSize: 22
                            }
                        }
                        Column {
                            x: 56
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 62
                            spacing: 1

                            P5Text {
                                text: Appearance.titled(tile.modelData.name)
                                color: tma.containsMouse ? "#428eff" : "#215dc6"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                font.underline: tma.containsMouse
                            }
                            P5Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: Appearance.sentence(tile.modelData.sub ?? "")
                                color: "#6d6a5f"
                                font.pixelSize: 11
                            }
                        }
                        MouseArea {
                            id: tma

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.host.enterTab(tile.index)
                        }
                    }
                }
            }
        }

        // ── the status line
        P5Text {
            x: root.fx + 12
            y: root.fy + root.fh - 22
            width: root.fw - 24 - 120
            elide: Text.ElideRight
            text: root.host.hintList.map(h => `${h.k} ${Appearance.titled(h.v)}`).join("     ")
            color: "#000000"
            font.pixelSize: 11
        }
        P5Text {
            x: root.fx + root.fw - 12 - 110
            y: root.fy + root.fh - 22
            width: 110
            horizontalAlignment: Text.AlignRight
            text: root.host.zone === 1 && !root.host.home && !root.host.isPane ? `${root.host.itemIndex + 1} of ${root.host.rows.length}` : `${root.total} settings`
            color: "#000000"
            font.pixelSize: 11
        }
    }
}
