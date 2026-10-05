//  VELVET  ·  modules/settings/WinFrame95.qml
//  The settings window of Windows 95: a grey bevelled dialog with a navy
//  title bar, the rooms as the tabs of a property sheet, the categories in a
//  white list box, the settings in a white list view, a status bar.
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
    readonly property real pageTop: root.fy + 54
    readonly property real pageH: root.fh - 54 - root.host.footH + 4
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ═══ behind the lists: the dialog, its page, the white boxes
    Item {
        anchors.fill: parent
        visible: root.back

        WinBox {
            x: root.fx
            y: root.fy
            width: root.fw
            height: root.fh
            kind: "panel"
        }
        // the title bar
        Rectangle {
            x: root.fx + 3
            y: root.fy + 3
            width: root.fw - 6
            height: 20

            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: "#000080"
                }
                GradientStop {
                    position: 1
                    color: "#1084d0"
                }
            }
        }
        // the page of the property sheet
        WinBox {
            x: root.fx + 6
            y: root.pageTop
            width: root.fw - 12
            height: root.pageH
            kind: "panel"
        }
        // the category list box and the settings list view
        WinBox {
            visible: root.host.zone === 1
            x: root.host.railX
            y: root.host.bodyY
            width: root.host.railW
            height: root.host.bodyH
            kind: "field"
        }
        WinBox {
            visible: root.host.zone === 1
            x: root.host.listX - 2
            y: root.host.bodyY
            width: root.host.listW + 4
            height: root.host.bodyH
            kind: "field"
        }
        // the status bar: two sunken cells
        WinBox {
            x: root.fx + 6
            y: root.fy + root.fh - 26
            width: root.fw - 12 - 90
            height: 20
            kind: "sunken"
            fill: "#c0c0c0"
        }
        WinBox {
            x: root.fx + root.fw - 6 - 86
            y: root.fy + root.fh - 26
            width: 86
            height: 20
            kind: "sunken"
            fill: "#c0c0c0"
        }
    }

    // ═══ above them
    Item {
        anchors.fill: parent
        visible: !root.back

        // ── the title
        Row {
            x: root.fx + 6
            y: root.fy + 4
            height: 18
            spacing: 6

            WinLogo {
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Velvet Settings" + (root.host.zone === 1 && !root.host.home ? " - " + Appearance.titled(root.host.tab?.name ?? "") : "")
                color: "#ffffff"
                font.pixelSize: 12
                font.weight: Font.Bold
            }
        }
        Row {
            x: root.fx + root.fw - width - 5
            y: root.fy + 5
            spacing: 2

            Repeater {
                model: ["_", "□", "×"]

                Item {
                    id: cap

                    required property string modelData
                    required property int index

                    width: 16
                    height: 14

                    WinBox {
                        anchors.fill: parent
                        hot: capArea.containsMouse
                        pressed: capArea.pressed

                        P5Text {
                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: cap.index === 0 ? -2 : (cap.index === 1 ? 0 : -1)
                            text: cap.modelData
                            color: "#000000"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }
                    MouseArea {
                        id: capArea

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: if (cap.index === 2)
                            Panels.closeSettings()
                    }
                }
            }
        }

        // ── the tabs of the property sheet: the rooms
        Row {
            x: root.fx + 8
            y: root.fy + 29
            spacing: 0

            Repeater {
                model: root.host.zones

                Item {
                    id: ztab

                    required property var modelData
                    required property int index

                    readonly property bool sel: ztab.index === root.zoneSel

                    width: zt.implicitWidth + 30
                    height: ztab.sel ? 26 : 23
                    y: ztab.sel ? -2 : 0

                    WinBox {
                        anchors.fill: parent
                        anchors.bottomMargin: -2
                        kind: "panel"
                    }
                    // the page's top edge does not run under the open tab
                    Rectangle {
                        visible: ztab.sel
                        x: 2
                        y: parent.height - 2
                        width: parent.width - 4
                        height: 4
                        color: "#c0c0c0"
                    }
                    P5Text {
                        id: zt

                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: ztab.sel ? 0 : 1
                        text: Appearance.titled(ztab.modelData.name)
                        color: "#000000"
                        font.pixelSize: 12
                    }
                    // the dotted focus rectangle
                    Rectangle {
                        visible: ztab.sel
                        anchors.centerIn: zt
                        width: zt.implicitWidth + 6
                        height: zt.implicitHeight + 2
                        color: "transparent"
                        border.width: 1
                        border.color: "#000000"
                        opacity: 0.55
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.host.setZone(ztab.index)
                    }
                }
            }
        }

        // ── the category list box
        Item {
            id: nav

            visible: root.host.zone === 1
            x: root.host.railX + 2
            y: root.host.bodyY + 2
            width: root.host.railW - 4
            height: root.host.bodyH - 4
            opacity: root.host.flipping ? 0 : 1
            clip: true

            Column {
                width: parent.width

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool sel: row.index === root.host.tabIndex

                        width: nav.width
                        height: Math.min(24, nav.height / Schema.tabs.length)

                        Rectangle {
                            x: 24
                            width: parent.width - 24
                            height: parent.height
                            color: row.sel ? "#000080" : "transparent"
                        }
                        Rectangle {
                            visible: row.sel && root.host.column === 0
                            x: 25
                            y: 1
                            width: parent.width - 26
                            height: parent.height - 2
                            color: "transparent"
                            border.width: 1
                            border.color: "#ffff00"
                            opacity: 0.8
                        }
                        Icon {
                            x: 4
                            anchors.verticalCenter: parent.verticalCenter
                            name: row.modelData.icon
                            color: "#000080"
                            font.pixelSize: 16
                        }
                        P5Text {
                            x: 28
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 32
                            elide: Text.ElideRight
                            text: Appearance.titled(row.modelData.name)
                            color: row.sel ? "#ffffff" : "#000000"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.host.enterTab(row.index)
                        }
                    }
                }
            }
        }

        // ── the front page: a control panel of icons
        Item {
            id: front

            visible: root.host.zone === 1 && root.host.home
            x: root.host.listX
            y: root.host.bodyY + 2
            width: root.host.listW
            height: root.host.bodyH - 4
            opacity: root.host.entered && !root.host.flipping ? 1 : 0
            clip: true

            Grid {
                x: 10
                y: 12
                width: parent.width - 20
                columns: Math.max(1, Math.floor((parent.width - 20) / 118))
                columnSpacing: 6
                rowSpacing: 10

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: tile

                        required property var modelData
                        required property int index

                        readonly property bool sel: tile.index === root.host.tabIndex

                        width: 112
                        height: 76

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 4
                            name: tile.modelData.icon
                            color: "#000080"
                            font.pixelSize: 36
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 50
                            width: tl.implicitWidth + 6
                            height: tl.implicitHeight + 2
                            color: tma.containsMouse ? "#000080" : "transparent"

                            P5Text {
                                id: tl

                                anchors.centerIn: parent
                                text: Appearance.titled(tile.modelData.name)
                                color: tma.containsMouse ? "#ffffff" : "#000000"
                                font.pixelSize: 12
                            }
                        }
                        MouseArea {
                            id: tma

                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.host.enterTab(tile.index)
                        }
                    }
                }
            }
        }

        // ── the status bar
        P5Text {
            x: root.fx + 12
            y: root.fy + root.fh - 25
            width: root.fw - 12 - 100
            elide: Text.ElideRight
            text: root.host.hintList.map(h => `${h.k} ${Appearance.titled(h.v)}`).join("    ")
            color: "#000000"
            font.pixelSize: 11
        }
        P5Text {
            x: root.fx + root.fw - 6 - 82
            y: root.fy + root.fh - 25
            width: 78
            horizontalAlignment: Text.AlignRight
            text: root.host.zone === 1 && !root.host.home && !root.host.isPane ? `${root.host.itemIndex + 1} of ${root.host.rows.length}` : `${root.total} settings`
            color: "#000000"
            font.pixelSize: 11
        }
    }
}
