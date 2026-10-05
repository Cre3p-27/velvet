//  VELVET  ·  modules/settings/WinFrame11.qml
//  The settings window of Windows 11: rounded, on a soft mica ground, a title
//  strip with the rooms as a small segmented control, a navigation column with
//  a rounded search field and a pill beside the chosen entry, a profile card
//  and rounded tiles on the front page.
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
    readonly property bool dark: WinTheme.dark
    readonly property color wash: root.dark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.05)
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ═══ behind the lists: the window
    Item {
        anchors.fill: parent
        visible: root.back

        Repeater {
            model: 6

            Rectangle {
                required property int index

                x: root.fx - index * 3
                y: root.fy + 8 + index * 2
                width: root.fw + index * 6
                height: root.fh + index * 6 - 6
                radius: 10 + index * 3
                color: Qt.rgba(0, 0, 0, 0.13 - index * 0.02)
            }
        }
        Rectangle {
            x: root.fx
            y: root.fy
            width: root.fw
            height: root.fh
            radius: 10
            color: WinTheme.face
            border.width: 1
            border.color: root.dark ? "#3a3a3a" : "#d6d6d6"
        }
    }

    // ═══ above them
    Item {
        anchors.fill: parent
        visible: !root.back

        // ── the title strip
        Row {
            x: root.fx + 16
            y: root.fy
            height: 44
            spacing: 10

            Item {
                id: backBtn

                anchors.verticalCenter: parent.verticalCenter
                width: 32
                height: 32

                readonly property bool active: root.host.zone === 1 && !root.host.home

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: backArea.containsMouse && backBtn.active ? root.wash : "transparent"
                }
                Icon {
                    anchors.centerIn: parent
                    name: "arrow_back"
                    color: backBtn.active ? WinTheme.text : WinTheme.dim
                    opacity: backBtn.active ? 1 : 0.5
                    font.pixelSize: 18
                }
                MouseArea {
                    id: backArea

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (backBtn.active)
                        root.host.stepBack()
                }
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "settings"
                color: WinTheme.accent
                font.pixelSize: 18
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Settings"
                color: WinTheme.text
                font.pixelSize: 12
            }
        }

        // the rooms: a small segmented control
        Item {
            id: seg

            x: root.fx + 210
            y: root.fy + 8
            width: segRow.implicitWidth + 8
            height: 30

            Rectangle {
                anchors.fill: parent
                radius: 6
                color: root.wash
            }
            Rectangle {
                readonly property var cell: segRow.children[root.zoneSel] ?? null

                y: 3
                height: parent.height - 6
                x: 4 + (cell ? cell.x : 0)
                width: cell ? cell.width : 60
                radius: 4
                color: root.dark ? "#3a3a3a" : "#ffffff"
                border.width: 1
                border.color: root.dark ? "#444444" : "#e4e4e4"

                Behavior on x {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Row {
                id: segRow

                x: 4
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: root.host.zones

                    Item {
                        id: ztab

                        required property var modelData
                        required property int index

                        readonly property bool sel: ztab.index === root.zoneSel

                        width: zt.implicitWidth + 28
                        height: 24

                        P5Text {
                            id: zt

                            anchors.centerIn: parent
                            text: Appearance.sentence(ztab.modelData.name)
                            color: ztab.sel ? WinTheme.text : WinTheme.dim
                            font.pixelSize: 12
                            font.weight: ztab.sel ? Font.DemiBold : Font.Normal
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.host.setZone(ztab.index)
                        }
                    }
                }
            }
        }

        // caption buttons
        Row {
            x: root.fx + root.fw - width - 6
            y: root.fy + 6
            spacing: 0

            Repeater {
                model: ["remove", "crop_square", "close"]

                Item {
                    id: cap

                    required property string modelData

                    readonly property bool close: cap.modelData === "close"

                    width: 46
                    height: 32

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: capArea.containsMouse ? (cap.close ? "#c42b1c" : root.wash) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: 80
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

        // ── the navigation column
        Item {
            id: nav

            visible: root.host.zone === 1
            x: root.host.railX
            y: root.host.bodyY
            width: root.host.railW
            height: root.host.bodyH
            opacity: root.host.flipping ? 0 : 1

            // the account
            Item {
                width: parent.width
                height: 64

                Rectangle {
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    height: 46
                    radius: 23
                    color: WinTheme.accent

                    P5Text {
                        anchors.centerIn: parent
                        text: "V"
                        color: WinTheme.selText
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                }
                Column {
                    x: 64
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    P5Text {
                        text: "Velvet"
                        color: WinTheme.text
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                    P5Text {
                        text: `${root.total} settings`
                        color: WinTheme.dim
                        font.pixelSize: 12
                    }
                }
            }

            // find a setting
            Item {
                y: 70
                width: parent.width
                height: 34

                WinBox {
                    anchors.fill: parent
                    kind: "field"
                    focused: sArea.containsMouse
                }
                P5Text {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Find a setting"
                    color: WinTheme.dim
                    font.pixelSize: 13
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    color: WinTheme.dim
                    font.pixelSize: 17
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
                y: 114
                width: parent.width
                spacing: 1

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool sel: row.index === root.host.tabIndex

                        width: nav.width
                        height: Math.min(40, (nav.height - 118) / Schema.tabs.length)

                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            color: row.sel ? (root.host.column === 0 ? (root.dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.07)) : root.wash) : (rma.containsMouse ? WinTheme.hover : "transparent")

                            Behavior on color {
                                ColorAnimation {
                                    duration: 90
                                }
                            }
                        }
                        Rectangle {
                            x: 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: row.sel ? 16 : 0
                            radius: 1.5
                            color: WinTheme.accent

                            Behavior on height {
                                NumberAnimation {
                                    duration: 120
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                        Icon {
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.icon
                            color: row.sel ? WinTheme.accent : WinTheme.text
                            font.pixelSize: 19
                        }
                        P5Text {
                            x: 46
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 50
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

        // ── the front page: rounded tiles
        Item {
            id: front

            visible: root.host.zone === 1 && root.host.home
            x: root.host.listX + 8
            y: root.host.bodyY
            width: root.host.listW - 16
            height: root.host.bodyH
            opacity: root.host.entered && !root.host.flipping ? 1 : 0
            clip: true

            P5Text {
                y: 8
                text: "Home"
                color: WinTheme.text
                font.pixelSize: 26
                font.weight: Font.DemiBold
            }

            Grid {
                y: 64
                width: parent.width
                columns: Math.max(1, Math.floor(parent.width / 330))
                columnSpacing: 8
                rowSpacing: 8

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: tile

                        required property var modelData
                        required property int index

                        width: Math.floor((front.width - 8 * (Math.max(1, Math.floor(front.width / 330)) - 1)) / Math.max(1, Math.floor(front.width / 330)))
                        height: 74

                        WinBox {
                            anchors.fill: parent
                            kind: "panel"
                            fill: tma.containsMouse ? (root.dark ? "#323232" : "#f9f9f9") : "transparent"
                        }
                        Icon {
                            x: 18
                            anchors.verticalCenter: parent.verticalCenter
                            name: tile.modelData.icon
                            color: WinTheme.accent
                            font.pixelSize: 28
                        }
                        Column {
                            x: 62
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 72
                            spacing: 2

                            P5Text {
                                text: Appearance.sentence(tile.modelData.name)
                                color: WinTheme.text
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
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
            x: root.fx + 20
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
