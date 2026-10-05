//  VELVET  ·  modules/settings/WinFrame7.qml
//  The settings window of Windows 7: a glass frame with a soft shine, back and
//  forward buttons beside an address bar and a search box, a command bar with
//  the rooms, a pale navigation pane, a white client, a details strip.
import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property var host: null
    property bool back: false

    readonly property real fx: root.host.frameX
    readonly property real fy: root.host.frameY
    readonly property real fw: root.host.frameW
    readonly property real fh: root.host.frameH
    readonly property int zoneSel: root.host.flipTarget >= 0 ? root.host.flipTarget : root.host.zone
    readonly property real navH: 38
    readonly property real cmdY: root.fy + 30 + root.navH
    readonly property color ink: "#1e395b"
    readonly property color link: "#0066cc"
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ═══ behind the lists: glass, client, panes
    Item {
        anchors.fill: parent
        visible: root.back

        // what it casts
        Repeater {
            model: 6

            Rectangle {
                required property int index

                x: root.fx - index * 2
                y: root.fy + 6 + index * 2
                width: root.fw + index * 4
                height: root.fh + index * 4
                radius: 9 + index * 2
                color: Qt.rgba(0, 0, 0, 0.1 - index * 0.015)
            }
        }
        // the glass
        Rectangle {
            x: root.fx
            y: root.fy
            width: root.fw
            height: root.fh
            radius: 8
            border.width: 1
            border.color: Qt.rgba(0.1, 0.17, 0.3, 0.9)

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(0.55, 0.72, 0.92, 0.94)
                }
                GradientStop {
                    position: 0.5
                    color: Qt.rgba(0.36, 0.55, 0.82, 0.92)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0.28, 0.47, 0.74, 0.94)
                }
            }
        }
        Rectangle {
            x: root.fx + 1
            y: root.fy + 1
            width: root.fw - 2
            height: root.fh - 2
            radius: 7
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.55)
        }
        // the shine: two pale diagonal bands
        Shape {
            x: root.fx + 2
            y: root.fy + 2
            width: root.fw - 4
            height: 150
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: Qt.rgba(1, 1, 1, 0.16)
                strokeColor: "transparent"

                PathPolyline {
                    path: [Qt.point(8, 0), Qt.point(root.fw * 0.42, 0), Qt.point(root.fw * 0.26, 130), Qt.point(0, 130), Qt.point(0, 8), Qt.point(8, 0)]
                }
            }
            ShapePath {
                fillColor: Qt.rgba(1, 1, 1, 0.09)
                strokeColor: "transparent"

                PathPolyline {
                    path: [Qt.point(root.fw * 0.48, 0), Qt.point(root.fw * 0.74, 0), Qt.point(root.fw * 0.58, 130), Qt.point(root.fw * 0.32, 130), Qt.point(root.fw * 0.48, 0)]
                }
            }
        }
        // the address field and the search box sit in the glass
        Rectangle {
            x: root.fx + 84
            y: root.fy + 36
            width: root.fw - 84 - 260
            height: 24
            radius: 2
            color: "#ffffff"
            border.width: 1
            border.color: "#5e7ca0"
        }
        Rectangle {
            x: root.fx + root.fw - 12 - 232
            y: root.fy + 36
            width: 232
            height: 24
            radius: 2
            color: "#ffffff"
            border.width: 1
            border.color: "#5e7ca0"
        }
        // the white client
        Rectangle {
            x: root.fx + 8
            y: root.cmdY
            width: root.fw - 16
            height: root.fh - (root.cmdY - root.fy) - 8
            color: "#ffffff"
            border.width: 1
            border.color: Qt.rgba(0.1, 0.17, 0.3, 0.75)
        }
        // the command bar
        Rectangle {
            x: root.fx + 9
            y: root.cmdY + 1
            width: root.fw - 18
            height: 30

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#fcfdfe"
                }
                GradientStop {
                    position: 0.5
                    color: "#f1f5fb"
                }
                GradientStop {
                    position: 1
                    color: "#e3ebf6"
                }
            }
        }
        Rectangle {
            x: root.fx + 9
            y: root.cmdY + 30
            width: root.fw - 18
            height: 1
            color: "#cfd9e6"
        }
        // the navigation pane
        Rectangle {
            visible: root.host.zone === 1
            x: root.fx + 9
            y: root.host.roomY + 1
            width: root.host.railX + root.host.railW + 6 - root.fx - 9
            height: root.fh - (root.host.roomY - root.fy) - 9 - root.host.footH

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: "#ffffff"
                }
                GradientStop {
                    position: 1
                    color: "#eaf1fa"
                }
            }
        }
        Rectangle {
            visible: root.host.zone === 1
            x: root.host.railX + root.host.railW + 6
            y: root.host.roomY + 1
            width: 1
            height: root.fh - (root.host.roomY - root.fy) - 9 - root.host.footH
            color: "#d4deec"
        }
        // the details strip
        Rectangle {
            x: root.fx + 9
            y: root.fy + root.fh - 8 - root.host.footH
            width: root.fw - 18
            height: root.host.footH - 1

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "#f6f9fd"
                }
                GradientStop {
                    position: 1
                    color: "#e6edf7"
                }
            }
        }
        Rectangle {
            x: root.fx + 9
            y: root.fy + root.fh - 8 - root.host.footH
            width: root.fw - 18
            height: 1
            color: "#cfd9e6"
        }
    }

    // ═══ above them
    Item {
        anchors.fill: parent
        visible: !root.back

        // ── the title, with the white glow Aero gave it
        Row {
            x: root.fx + 10
            y: root.fy + 5
            height: 22
            spacing: 6

            WinLogo {
                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: tt.implicitWidth
                height: tt.implicitHeight

                Repeater {
                    model: [[-1, 0], [1, 0], [0, -1], [0, 1]]

                    P5Text {
                        required property var modelData

                        x: modelData[0]
                        y: modelData[1]
                        text: tt.text
                        color: "#ffffff"
                        opacity: 0.55
                        font.pixelSize: 12
                    }
                }
                P5Text {
                    id: tt

                    text: "Velvet Settings"
                    color: "#000000"
                    font.pixelSize: 12
                }
            }
        }
        // caption buttons
        Row {
            x: root.fx + root.fw - width - 8
            y: root.fy + 1
            spacing: 0

            Repeater {
                model: ["min", "max", "close"]

                Item {
                    id: cap

                    required property string modelData

                    readonly property bool close: cap.modelData === "close"

                    width: close ? 47 : 28
                    height: 19

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        border.width: 1
                        border.color: Qt.rgba(0.1, 0.17, 0.3, 0.85)

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: cap.close ? (capArea.containsMouse ? "#f1a7a1" : "#e3b4af") : (capArea.containsMouse ? "#dff0fb" : "#cfe0f2")
                            }
                            GradientStop {
                                position: 0.5
                                color: cap.close ? (capArea.containsMouse ? "#d9483a" : "#c4503f") : (capArea.containsMouse ? "#a6d4f5" : "#9cbbd9")
                            }
                            GradientStop {
                                position: 1
                                color: cap.close ? (capArea.containsMouse ? "#bd2a18" : "#a3301e") : (capArea.containsMouse ? "#72b4e5" : "#7fa2c8")
                            }
                        }
                    }
                    Rectangle {
                        visible: cap.modelData === "min"
                        x: 10
                        y: 11
                        width: 8
                        height: 3
                        color: "#ffffff"
                        border.width: 1
                        border.color: "#2b3f5e"
                    }
                    Rectangle {
                        visible: cap.modelData === "max"
                        anchors.centerIn: parent
                        width: 11
                        height: 9
                        color: "transparent"
                        border.width: 2
                        border.color: "#ffffff"
                    }
                    P5Text {
                        visible: cap.close
                        anchors.centerIn: parent
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

        // ── back and forward, the address, the search
        Row {
            x: root.fx + 14
            y: root.fy + 33
            spacing: 4

            Repeater {
                model: ["back", "forward"]

                Item {
                    id: nb

                    required property string modelData

                    readonly property bool active: nb.modelData === "back" && root.host.zone === 1 && !root.host.home

                    width: 28
                    height: 28

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        border.width: 1
                        border.color: Qt.rgba(0.1, 0.17, 0.3, 0.8)
                        opacity: nb.active ? 1 : 0.55

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: nbArea.containsMouse && nb.active ? "#e6f6ff" : "#d4e3f4"
                            }
                            GradientStop {
                                position: 0.5
                                color: nbArea.containsMouse && nb.active ? "#9fd3f3" : "#8eb0d4"
                            }
                            GradientStop {
                                position: 1
                                color: nbArea.containsMouse && nb.active ? "#5db3e6" : "#6f95bd"
                            }
                        }
                    }
                    Icon {
                        anchors.centerIn: parent
                        name: nb.modelData === "back" ? "arrow_back" : "arrow_forward"
                        color: "#ffffff"
                        opacity: nb.active ? 1 : 0.7
                        font.pixelSize: 17
                    }
                    MouseArea {
                        id: nbArea

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (nb.active)
                            root.host.stepBack()
                    }
                }
            }
        }
        Row {
            x: root.fx + 90
            y: root.fy + 36
            height: 24
            spacing: 4

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "settings"
                color: root.ink
                font.pixelSize: 16
            }
            Repeater {
                model: String(root.host.breadcrumb ?? "SETTINGS").split(" › ")

                Row {
                    required property string modelData
                    required property int index

                    spacing: 5

                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "▸"
                        color: "#5a6e8a"
                        font.pixelSize: 9
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Appearance.sentence(modelData)
                        color: "#000000"
                        font.pixelSize: 12
                    }
                }
            }
        }
        Item {
            x: root.fx + root.fw - 12 - 232
            y: root.fy + 36
            width: 232
            height: 24

            P5Text {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "Search settings"
                color: "#7a7a7a"
                font.pixelSize: 12
                font.italic: true
            }
            Icon {
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                color: root.ink
                font.pixelSize: 17
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: root.host.searching = true
            }
        }

        // ── the command bar: the rooms
        Row {
            x: root.fx + 12
            y: root.cmdY + 3
            spacing: 2

            Repeater {
                model: root.host.zones

                Item {
                    id: ztab

                    required property var modelData
                    required property int index

                    readonly property bool sel: ztab.index === root.zoneSel

                    width: zt.implicitWidth + 24
                    height: 25

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        visible: ztab.sel || zma.containsMouse
                        border.width: 1
                        border.color: ztab.sel ? "#7da2ce" : "#b8d6f5"

                        gradient: Gradient {
                            GradientStop {
                                position: 0
                                color: ztab.sel ? "#e1effb" : "#f4f9fe"
                            }
                            GradientStop {
                                position: 1
                                color: ztab.sel ? "#bcd9f3" : "#dcebf9"
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: 2
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.8)
                        }
                    }
                    P5Text {
                        id: zt

                        anchors.centerIn: parent
                        text: Appearance.sentence(ztab.modelData.name)
                        color: "#1e395b"
                        font.pixelSize: 12
                        font.weight: ztab.sel ? Font.Bold : Font.Normal
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

        // ── the navigation pane
        Item {
            id: nav

            visible: root.host.zone === 1
            x: root.host.railX
            y: root.host.bodyY + 6
            width: root.host.railW
            height: root.host.bodyH - 6
            opacity: root.host.flipping ? 0 : 1

            P5Text {
                x: 4
                text: "▾ Categories"
                color: root.ink
                font.pixelSize: 12
                font.weight: Font.Bold
            }
            Column {
                y: 24
                width: parent.width

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool sel: row.index === root.host.tabIndex

                        width: parent.width
                        height: Math.min(28, (nav.height - 30) / Schema.tabs.length)

                        Rectangle {
                            anchors.fill: parent
                            anchors.leftMargin: 2
                            anchors.rightMargin: 4
                            radius: 3
                            visible: row.sel || rma.containsMouse
                            border.width: 1
                            border.color: row.sel ? "#7da2ce" : "#b8d6f5"

                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: row.sel ? (root.host.column === 0 ? "#dcebfa" : "#eaf3fc") : "#f4f9fe"
                                }
                                GradientStop {
                                    position: 1
                                    color: row.sel ? (root.host.column === 0 ? "#b3d3f2" : "#d2e4f6") : "#dcebf9"
                                }
                            }
                        }
                        Icon {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.icon
                            color: "#2f6db5"
                            font.pixelSize: 17
                        }
                        P5Text {
                            x: 38
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 44
                            elide: Text.ElideRight
                            text: Appearance.sentence(row.modelData.name)
                            color: "#000000"
                            font.pixelSize: 12
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

        // ── the front page: the old control panel's "adjust your settings"
        Item {
            id: front

            visible: root.host.zone === 1 && root.host.home
            x: root.host.listX + 8
            y: root.host.bodyY
            width: root.host.listW - 16
            height: root.host.bodyH
            opacity: root.host.entered && !root.host.flipping ? 1 : 0
            clip: true

            Column {
                y: 14
                spacing: 4

                P5Text {
                    text: "Adjust your shell's settings"
                    color: "#003399"
                    font.pixelSize: 19
                }
                P5Text {
                    text: `${root.total} settings in ${Schema.tabs.length} categories`
                    color: "#6d6d6d"
                    font.pixelSize: 12
                }
            }

            Grid {
                y: 84
                width: parent.width
                columns: Math.max(1, Math.floor(parent.width / 300))
                columnSpacing: 8
                rowSpacing: 4

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: tile

                        required property var modelData
                        required property int index

                        width: 292
                        height: 58

                        Rectangle {
                            anchors.fill: parent
                            radius: 3
                            visible: tma.containsMouse
                            border.width: 1
                            border.color: "#b8d6f5"

                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: "#f4f9fe"
                                }
                                GradientStop {
                                    position: 1
                                    color: "#dcebf9"
                                }
                            }
                        }
                        Rectangle {
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 40
                            radius: 5
                            border.width: 1
                            border.color: "#3a6ea8"

                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: "#8cc2f2"
                                }
                                GradientStop {
                                    position: 0.5
                                    color: "#3d8fe0"
                                }
                                GradientStop {
                                    position: 1
                                    color: "#2d6fbf"
                                }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: tile.modelData.icon
                                color: "#ffffff"
                                font.pixelSize: 24
                            }
                        }
                        Column {
                            x: 58
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 64
                            spacing: 1

                            P5Text {
                                text: Appearance.sentence(tile.modelData.name)
                                color: tma.containsMouse ? "#3399ff" : "#0066cc"
                                font.pixelSize: 14
                                font.underline: tma.containsMouse
                            }
                            P5Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: Appearance.sentence(tile.modelData.sub ?? "")
                                color: "#6d6d6d"
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

        // ── the details strip: the keys
        Row {
            x: root.fx + 20
            y: root.fy + root.fh - 8 - root.host.footH + 1
            height: root.host.footH - 2
            spacing: 18

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "keyboard"
                color: "#5a7ca8"
                font.pixelSize: 18
            }
            Repeater {
                model: root.host.hintList

                Row {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    P5Text {
                        text: modelData.k
                        color: "#1e395b"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                    P5Text {
                        text: Appearance.sentence(modelData.v)
                        color: "#5a5a5a"
                        font.pixelSize: 11
                    }
                }
            }
        }
        P5Text {
            x: root.fx + root.fw - 20 - 140
            y: root.fy + root.fh - 8 - root.host.footH + (root.host.footH - height) / 2
            width: 140
            horizontalAlignment: Text.AlignRight
            text: root.host.zone === 1 && !root.host.home && !root.host.isPane ? `${root.host.itemIndex + 1} of ${root.host.rows.length}` : `${root.total} settings`
            color: "#5a5a5a"
            font.pixelSize: 11
        }
    }
}
