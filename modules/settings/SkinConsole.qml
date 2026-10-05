//  VELVET  ·  modules/settings/SkinConsole.qml
//  The settings as a terminal, kept quiet: a prompt with the path you are in,
//  the categories as a numbered tree, key = value lines, an editor's status
//  line at the bottom. Nothing here is a card.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var host: null

    readonly property real fs: 14
    readonly property bool inRail: root.host.zone === 1 && root.host.column === 0
    readonly property string path: String(root.host.breadcrumb ?? "").toLowerCase().replace(/ › /g, "/").replace(/ /g, "_")
    readonly property color rule: Colours.alpha(Colours.ink, 0.12)
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ── the prompt line, and the rooms as tabs
    Item {
        x: root.host.insetL
        y: root.host.insetT
        width: root.host.fieldW
        height: root.host.headH

        Rectangle {
            anchors.fill: parent
            color: Colours.alpha(Colours.surface, 0.94)
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: root.rule
        }

        Row {
            x: root.host.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            P5Text {
                text: "velvet"
                color: Colours.accent
                font.pixelSize: root.fs
                font.weight: Font.Bold
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.closeSettings()
                }
            }
            P5Text {
                text: ` ~/${root.path} `
                color: Colours.inkDim
                font.pixelSize: root.fs
            }
            P5Text {
                text: "❯ "
                color: Colours.accent
                font.pixelSize: root.fs
                font.weight: Font.Bold
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 8
                height: root.fs + 2
                color: Colours.alpha(Colours.ink, 0.75)

                SequentialAnimation on opacity {
                    running: root.host.entered
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.1
                        duration: 600
                    }
                    NumberAnimation {
                        to: 1
                        duration: 600
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: root.host.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 20

            Repeater {
                model: root.host.zones

                Item {
                    id: ztab

                    required property var modelData
                    required property int index

                    readonly property bool sel: ztab.index === (root.host.flipTarget >= 0 ? root.host.flipTarget : root.host.zone)

                    width: zt.implicitWidth
                    height: root.fs + 12

                    P5Text {
                        id: zt

                        anchors.centerIn: parent
                        text: String(ztab.modelData.name).toLowerCase()
                        color: ztab.sel ? Colours.accent : (zma.containsMouse ? Colours.ink : Colours.inkDim)
                        font.pixelSize: root.fs
                        font.weight: ztab.sel ? Font.Bold : Font.Normal
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: -3
                        width: parent.width
                        height: 2
                        color: Colours.accent
                        opacity: ztab.sel ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
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

    // ── the category tree
    Item {
        id: tree

        visible: root.host.zone === 1
        x: root.host.railX
        y: root.host.bodyY
        width: root.host.railW
        height: root.host.bodyH
        opacity: root.host.flipping ? 0 : 1

        P5Text {
            text: "categories"
            color: Colours.inkDim
            font.pixelSize: root.fs - 2
        }

        Column {
            y: 26
            width: parent.width

            Repeater {
                model: Schema.tabs

                Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool sel: row.index === root.host.tabIndex
                    readonly property int count: root.host.countOf(row.modelData.items ?? [])

                    width: tree.width
                    height: Math.round(root.fs * 2.1)

                    Rectangle {
                        anchors.fill: parent
                        color: row.sel ? Colours.alpha(Colours.accent, root.inRail ? 0.16 : 0.08) : (rma.containsMouse ? Colours.alpha(Colours.ink, 0.05) : "transparent")

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
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        text: `${row.index + 1}`
                        color: row.sel ? Colours.accent : Colours.inkDim
                        font.pixelSize: root.fs - 1
                    }
                    P5Text {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(row.modelData.name).toLowerCase()
                        color: row.sel ? Colours.ink : Colours.alpha(Colours.ink, 0.82)
                        font.pixelSize: root.fs
                        font.weight: row.sel ? Font.Bold : Font.Normal
                        elide: Text.ElideRight
                        width: tree.width - 40 - 44
                    }
                    P5Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.count > 0
                        text: `${row.count}`
                        color: Colours.inkDim
                        font.pixelSize: root.fs - 3
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

    // the rule between the tree and the list
    Rectangle {
        visible: root.host.zone === 1
        x: root.host.listX - root.host.sg.gap / 2
        y: root.host.bodyY
        width: 1
        height: root.host.bodyH
        color: root.rule
    }

    // ── the front page: a few lines, like the first thing a shell prints
    Column {
        visible: root.host.zone === 1 && root.host.home
        x: root.host.listX
        y: root.host.bodyY + 6
        spacing: 4
        opacity: root.host.entered && !root.host.flipping ? 1 : 0

        P5Text {
            text: "velvet shell · settings"
            color: Colours.accent
            font.pixelSize: root.fs + 2
            font.weight: Font.Bold
        }
        P5Text {
            text: `${Schema.tabs.length} categories · ${root.total} settings`
            color: Colours.inkDim
            font.pixelSize: root.fs
        }
        Item {
            width: 1
            height: 10
        }
        P5Text {
            text: "pick a category on the left (up/down, enter)."
            color: Colours.ink
            font.pixelSize: root.fs
        }
        P5Text {
            text: "type / to search every setting · f1 lists every key · esc closes."
            color: Colours.inkDim
            font.pixelSize: root.fs
        }
    }

    // ── the status line
    Item {
        x: root.host.insetL
        y: root.host.insetT + root.host.fieldH - root.host.footH
        width: root.host.fieldW
        height: root.host.footH

        Rectangle {
            anchors.fill: parent
            color: Colours.alpha(Colours.surface, 0.94)
        }
        Rectangle {
            width: parent.width
            height: 1
            color: root.rule
        }

        Row {
            x: root.host.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.host.zone !== 1 ? "room" : (root.host.home ? "menu" : (root.host.column === 0 ? "tree" : "normal"))
                color: Colours.accent
                font.pixelSize: root.fs - 2
                font.weight: Font.Bold
            }

            Repeater {
                model: root.host.hintList

                Row {
                    required property var modelData

                    spacing: 5

                    P5Text {
                        text: modelData.k
                        color: Colours.alpha(Colours.ink, 0.9)
                        font.pixelSize: root.fs - 2
                        font.weight: Font.Bold
                    }
                    P5Text {
                        text: modelData.v
                        color: Colours.inkDim
                        font.pixelSize: root.fs - 2
                    }
                }
            }
        }

        P5Text {
            anchors.right: parent.right
            anchors.rightMargin: root.host.pad
            anchors.verticalCenter: parent.verticalCenter
            visible: root.host.zone === 1 && !root.host.home && !root.host.isPane
            text: `${root.host.itemIndex + 1}/${root.host.rows.length}`
            color: Colours.inkDim
            font.pixelSize: root.fs - 2
        }
    }
}
