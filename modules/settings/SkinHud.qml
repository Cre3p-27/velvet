//  VELVET  ·  modules/settings/SkinHud.qml
//  The settings as an interface from a sci-fi game, kept calm: small corner
//  marks, a slim header, a column of numbered sectors, notched plates and a
//  status line with key caps. Cyan only where something is active.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var host: null

    readonly property real x0: root.host.insetL + root.host.pad
    readonly property real span: root.host.fieldW - root.host.pad * 2
    readonly property color line: Colours.alpha(Colours.ink, 0.14)
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ── the corners of the screen
    Repeater {
        model: [{ ax: 0, ay: 0 }, { ax: 1, ay: 0 }, { ax: 0, ay: 1 }, { ax: 1, ay: 1 }]

        Item {
            required property var modelData

            x: root.host.insetL + modelData.ax * (root.host.fieldW - 30) + (modelData.ax === 0 ? 10 : 0) - (modelData.ax === 1 ? 10 : 0)
            y: root.host.insetT + modelData.ay * (root.host.fieldH - 30) + (modelData.ay === 0 ? 10 : 0) - (modelData.ay === 1 ? 10 : 0)
            width: 30
            height: 30

            Rectangle {
                x: modelData.ax === 0 ? 0 : 30 - 1
                width: 1
                height: 30
                color: Colours.alpha(Colours.accent, 0.55)
            }
            Rectangle {
                y: modelData.ay === 0 ? 0 : 30 - 1
                width: 30
                height: 1
                color: Colours.alpha(Colours.accent, 0.55)
            }
        }
    }

    // ── the header
    Item {
        x: root.x0
        y: root.host.insetT + 12
        width: root.span
        height: root.host.headH - 14

        // the mark
        Item {
            id: mark

            width: 30
            height: 30
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 18
                rotation: 45
                color: "transparent"
                border.width: 1.5
                border.color: Colours.accent
            }
            Rectangle {
                anchors.centerIn: parent
                width: 6
                height: 6
                rotation: 45
                color: Colours.accent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.closeSettings()
            }
        }

        Column {
            x: mark.width + 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            P5Text {
                display: true
                text: "SETTINGS"
                color: Colours.ink
                font.pixelSize: 19
                tracking: 5
            }
            P5Text {
                text: String(root.host.breadcrumb ?? "").replace(/ › /g, "  /  ")
                color: Colours.inkDim
                font.pixelSize: 10
                tracking: 2
            }
        }

        // the rooms, as notched plates
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Repeater {
                model: root.host.zones

                Item {
                    id: ztab

                    required property var modelData
                    required property int index

                    readonly property bool sel: ztab.index === (root.host.flipTarget >= 0 ? root.host.flipTarget : root.host.zone)

                    width: zt.implicitWidth + 34
                    height: 32

                    Slash {
                        anchors.fill: parent
                        shear: 0
                        color: ztab.sel ? Colours.alpha(Colours.accent, 0.16) : (zma.containsMouse ? Colours.alpha(Colours.ink, 0.07) : "transparent")
                        borderColor: ztab.sel ? Colours.accent : Colours.alpha(Colours.ink, 0.16)
                        borderWidth: 1
                        outlineWidth: 0
                        shadowKind: "none"

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                    P5Text {
                        id: zt

                        anchors.centerIn: parent
                        text: ztab.modelData.name
                        color: ztab.sel ? Colours.accent : Colours.alpha(Colours.ink, 0.85)
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        tracking: 2.4
                    }
                    MouseArea {
                        id: zma

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.host.setZone(ztab.index)
                    }
                }
            }
        }
    }

    // the line under the header
    Rectangle {
        x: root.x0
        y: root.host.insetT + root.host.headH - 2
        width: root.span
        height: 1
        color: root.line
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

        P5Text {
            text: "SECTORS"
            color: Colours.inkDim
            font.pixelSize: 10
            tracking: 4
        }

        Column {
            y: 24
            width: parent.width
            spacing: 2

            Repeater {
                model: Schema.tabs

                Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool sel: row.index === root.host.tabIndex
                    readonly property int count: root.host.countOf(row.modelData.items ?? [])

                    width: nav.width
                    height: Math.min(40, (nav.height - 30) / Schema.tabs.length - 2)

                    Slash {
                        anchors.fill: parent
                        shear: 0
                        color: row.sel ? Colours.alpha(Colours.accent, root.host.column === 0 ? 0.2 : 0.1) : (rma.containsMouse ? Colours.alpha(Colours.ink, 0.06) : "transparent")
                        outlineWidth: 0
                        shadowKind: "none"

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                    Rectangle {
                        width: 2
                        height: parent.height
                        color: Colours.accent
                        opacity: row.sel ? 1 : 0
                    }
                    P5Text {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(row.index + 1).padStart(2, "0")
                        color: row.sel ? Colours.accent : Colours.inkDim
                        font.family: Appearance.fontFamily.mono
                        font.pixelSize: 10
                    }
                    P5Text {
                        x: 42
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.name
                        color: row.sel ? Colours.ink : Colours.alpha(Colours.ink, 0.8)
                        font.pixelSize: 12
                        font.weight: row.sel ? Font.DemiBold : Font.Normal
                        tracking: 2
                        elide: Text.ElideRight
                        width: nav.width - 42 - 40
                    }
                    P5Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.count > 0
                        text: `${row.count}`
                        color: Colours.inkDim
                        font.family: Appearance.fontFamily.mono
                        font.pixelSize: 10
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

    // ── the front page: still rings, one dot per sector
    Item {
        visible: root.host.zone === 1 && root.host.home
        x: root.host.listX
        y: root.host.bodyY
        width: root.host.listW
        height: root.host.bodyH
        opacity: root.host.entered && !root.host.flipping ? 1 : 0

        Item {
            id: radar

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -24
            width: Math.min(parent.height * 0.52, 300)
            height: width

            Repeater {
                model: 3

                Rectangle {
                    required property int index

                    anchors.centerIn: parent
                    width: radar.width * (index + 1) / 3
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: Colours.alpha(Colours.ink, 0.1 + index * 0.03)
                }
            }
            Repeater {
                model: Schema.tabs.length

                Rectangle {
                    required property int index

                    readonly property real a: index * 2.399963
                    readonly property real r: radar.width * (0.12 + 0.34 * ((index * 0.37) % 1))

                    x: radar.width / 2 + Math.cos(a) * r - width / 2
                    y: radar.height / 2 + Math.sin(a) * r - width / 2
                    width: index === root.host.tabIndex ? 8 : 4
                    height: width
                    color: index === root.host.tabIndex ? Colours.accent : Colours.alpha(Colours.ink, 0.35)
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: radar.bottom
            anchors.topMargin: 22
            spacing: 6

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: "SELECT A SECTOR"
                color: Colours.ink
                font.pixelSize: 20
                tracking: 7
            }
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `${root.total} SETTINGS    ·    ↑ ↓ NAVIGATE    ENTER OPEN    / SEARCH`
                color: Colours.inkDim
                font.pixelSize: 11
                tracking: 2
            }
        }
    }

    // ── the status bar
    Item {
        x: root.x0
        y: root.host.insetT + root.host.fieldH - root.host.footH
        width: root.span
        height: root.host.footH - 10

        Rectangle {
            width: parent.width
            height: 1
            color: root.line
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            spacing: 20

            Repeater {
                model: root.host.hintList

                Row {
                    required property var modelData

                    spacing: 7

                    Slash {
                        anchors.verticalCenter: parent.verticalCenter
                        width: kc.implicitWidth + 14
                        height: 20
                        shear: 0
                        color: "transparent"
                        borderColor: Colours.alpha(Colours.ink, 0.22)
                        borderWidth: 1
                        outlineWidth: 0
                        shadowKind: "none"

                        P5Text {
                            id: kc

                            anchors.centerIn: parent
                            text: modelData.k
                            color: Colours.alpha(Colours.ink, 0.9)
                            font.pixelSize: 10
                            tracking: 1
                        }
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.v
                        color: Colours.inkDim
                        font.pixelSize: 10
                        tracking: 1.4
                    }
                }
            }
        }

        P5Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 2
            visible: root.host.zone === 1
            text: `${String(root.host.tabIndex + 1).padStart(2, "0")} / ${String(Schema.tabs.length).padStart(2, "0")}`
            color: Colours.inkDim
            font.family: Appearance.fontFamily.mono
            font.pixelSize: 10
            tracking: 2
        }
    }
}
