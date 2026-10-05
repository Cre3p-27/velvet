//  VELVET  ·  modules/settings/WinFrame10.qml
//  The settings window of Windows 10: flat and sharp-cornered, a thin title
//  bar with flat caption buttons, the rooms as a pivot with a sliding
//  underline, a navigation column with a search box and an accent bar on the
//  chosen entry, a home of plain tiles.
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
    readonly property real titleH: 32
    readonly property real pivotH: 40
    readonly property bool dark: WinTheme.dark
    readonly property color wash: root.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ═══ behind the lists: the window and its navigation column
    Item {
        anchors.fill: parent
        visible: root.back

        Repeater {
            model: 5

            Rectangle {
                required property int index

                x: root.fx - index * 2
                y: root.fy + 4 + index * 2
                width: root.fw + index * 4
                height: root.fh + index * 4
                color: Qt.rgba(0, 0, 0, 0.16 - index * 0.03)
            }
        }
        Rectangle {
            x: root.fx
            y: root.fy
            width: root.fw
            height: root.fh
            color: WinTheme.face
            border.width: 1
            border.color: WinTheme.accent
        }
        Rectangle {
            visible: root.host.zone === 1
            x: root.fx + 1
            y: root.host.roomY
            width: root.host.railW
            height: root.fh - root.host.headH - root.host.footH - 1
            color: WinTheme.nav
        }
        Rectangle {
            x: root.fx + 1
            y: root.fy + root.fh - root.host.footH - 1
            width: root.fw - 2
            height: 1
            color: WinTheme.rule
        }
    }

    // ═══ above them
    Item {
        anchors.fill: parent
        visible: !root.back

        // ── the title bar
        Row {
            x: root.fx + 12
            y: root.fy
            height: root.titleH
            spacing: 10

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "settings"
                color: WinTheme.accent
                font.pixelSize: 17
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Settings"
                color: WinTheme.text
                font.pixelSize: 12
            }
        }
        Row {
            x: root.fx + root.fw - width - 1
            y: root.fy + 1
            spacing: 0

            Repeater {
                model: ["remove", "crop_square", "close"]

                Item {
                    id: cap

                    required property string modelData

                    readonly property bool close: cap.modelData === "close"

                    width: 46
                    height: root.titleH - 1

                    Rectangle {
                        anchors.fill: parent
                        color: capArea.containsMouse ? (cap.close ? "#e81123" : root.wash) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 70
                            }
                        }
                    }
                    Icon {
                        anchors.centerIn: parent
                        name: cap.modelData
                        color: capArea.containsMouse && cap.close ? "#ffffff" : WinTheme.text
                        font.pixelSize: 16
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

        // ── the pivot: the rooms
        Item {
            id: pivot

            x: root.fx + 12
            y: root.fy + root.titleH
            width: pivotRow.implicitWidth
            height: root.pivotH

            Row {
                id: pivotRow

                spacing: 6

                Repeater {
                    model: root.host.zones

                    Item {
                        id: ztab

                        required property var modelData
                        required property int index

                        readonly property bool sel: ztab.index === root.zoneSel

                        width: zt.implicitWidth + 24
                        height: root.pivotH

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 4
                            anchors.bottomMargin: 4
                            color: zma.containsMouse && !ztab.sel ? root.wash : "transparent"
                        }
                        P5Text {
                            id: zt

                            anchors.centerIn: parent
                            text: Appearance.sentence(ztab.modelData.name)
                            color: ztab.sel ? WinTheme.text : WinTheme.dim
                            font.pixelSize: 14
                            font.weight: Font.Light

                            Behavior on color {
                                ColorAnimation {
                                    duration: 90
                                }
                            }
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
            Rectangle {
                readonly property var cell: pivotRow.children[root.zoneSel] ?? null

                y: parent.height - 6
                height: 2
                x: cell ? cell.x + 12 : 0
                width: cell ? cell.width - 24 : 0
                color: WinTheme.accent

                Behavior on x {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        // ── the navigation column
        Item {
            id: nav

            visible: root.host.zone === 1
            x: root.fx + 1
            y: root.host.roomY
            width: root.host.railW
            height: root.fh - root.host.headH - root.host.footH - 1
            opacity: root.host.flipping ? 0 : 1

            // find a setting
            Item {
                x: 14
                y: 12
                width: parent.width - 28
                height: 34

                WinBox {
                    anchors.fill: parent
                    kind: "field"
                    hot: sArea.containsMouse
                }
                P5Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Find a setting"
                    color: WinTheme.dim
                    font.pixelSize: 13
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 9
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    color: WinTheme.dim
                    font.pixelSize: 18
                }
                MouseArea {
                    id: sArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                    onClicked: root.host.searching = true
                }
            }

            Column {
                y: 58
                width: parent.width

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool sel: row.index === root.host.tabIndex

                        width: nav.width
                        height: Math.min(46, (nav.height - 62) / Schema.tabs.length)

                        Rectangle {
                            anchors.fill: parent
                            color: row.sel ? (root.host.column === 0 ? (root.dark ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(0, 0, 0, 0.1)) : root.wash) : (rma.containsMouse ? WinTheme.hover : "transparent")

                            Behavior on color {
                                ColorAnimation {
                                    duration: 80
                                }
                            }
                        }
                        Rectangle {
                            y: row.sel ? 8 : parent.height / 2
                            width: 3
                            height: row.sel ? parent.height - 16 : 0
                            color: WinTheme.accent

                            Behavior on height {
                                NumberAnimation {
                                    duration: 110
                                }
                            }
                            Behavior on y {
                                NumberAnimation {
                                    duration: 110
                                }
                            }
                        }
                        Icon {
                            x: 18
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.icon
                            color: WinTheme.text
                            font.pixelSize: 20
                        }
                        P5Text {
                            x: 52
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 56
                            elide: Text.ElideRight
                            text: Appearance.sentence(row.modelData.name)
                            color: WinTheme.text
                            font.pixelSize: 14
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

        // ── the front page: plain tiles
        Item {
            id: front

            visible: root.host.zone === 1 && root.host.home
            x: root.host.listX + 24
            y: root.host.bodyY
            width: root.host.listW - 48
            height: root.host.bodyH
            opacity: root.host.entered && !root.host.flipping ? 1 : 0
            clip: true

            Column {
                y: 14
                spacing: 4

                P5Text {
                    text: "Settings"
                    color: WinTheme.text
                    font.pixelSize: 30
                    font.weight: Font.Light
                }
                P5Text {
                    text: `${root.total} settings in ${Schema.tabs.length} categories`
                    color: WinTheme.dim
                    font.pixelSize: 13
                }
            }

            Grid {
                y: 96
                width: parent.width
                columns: Math.max(1, Math.floor(parent.width / 300))
                columnSpacing: 0
                rowSpacing: 4

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: tile

                        required property var modelData
                        required property int index

                        width: Math.floor(front.width / Math.max(1, Math.floor(front.width / 300)))
                        height: 72

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            color: tma.containsMouse ? root.wash : "transparent"
                            border.width: tma.containsMouse ? 2 : 0
                            border.color: Qt.rgba(WinTheme.text.r, WinTheme.text.g, WinTheme.text.b, 0.35)
                        }
                        Icon {
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            name: tile.modelData.icon
                            color: WinTheme.accent
                            font.pixelSize: 32
                        }
                        Column {
                            x: 62
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 70
                            spacing: 2

                            P5Text {
                                text: Appearance.sentence(tile.modelData.name)
                                color: WinTheme.text
                                font.pixelSize: 16
                            }
                            P5Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: Appearance.sentence(tile.modelData.sub ?? "")
                                color: WinTheme.dim
                                font.pixelSize: 12
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

        // ── the foot
        Row {
            x: root.fx + 16
            y: root.fy + root.fh - root.host.footH
            height: root.host.footH
            spacing: 18

            Repeater {
                model: root.host.hintList

                Row {
                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    P5Text {
                        text: modelData.k
                        color: WinTheme.text
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                    P5Text {
                        text: Appearance.sentence(modelData.v)
                        color: WinTheme.dim
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
