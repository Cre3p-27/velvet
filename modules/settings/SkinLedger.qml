//  VELVET  ·  modules/settings/SkinLedger.qml
//  The settings as a printed page, kept light: a masthead with a date line, the
//  categories as a section bar, one ruled column, a contents page on the front
//  and a folio at the foot. Hairline rules, no boxes.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var host: null

    readonly property real x0: root.host.insetL + root.host.pad
    readonly property real span: root.host.fieldW - root.host.pad * 2
    readonly property string today: Qt.formatDate(new Date(), "dddd, d MMMM yyyy")
    readonly property color rule: Colours.alpha(Colours.ink, 0.3)
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ── the masthead
    Item {
        x: root.x0
        y: root.host.insetT + 12
        width: root.span
        height: root.host.headH - 12

        // date line
        Item {
            width: parent.width
            height: 18

            P5Text {
                text: `Settings`
                color: Colours.inkDim
                font.pixelSize: 12
                font.italic: true
            }
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.today
                color: Colours.inkDim
                font.pixelSize: 12
                font.italic: true
            }
            P5Text {
                anchors.right: parent.right
                text: `${Schema.tabs.length} sections · ${root.total} items`
                color: Colours.inkDim
                font.pixelSize: 12
                font.italic: true
            }
        }

        Rectangle {
            y: 22
            width: parent.width
            height: 1
            color: Colours.ink
        }

        // the name of the paper
        Item {
            y: 28
            width: parent.width
            height: 60

            P5Text {
                id: nameText

                anchors.centerIn: parent
                display: true
                text: "The Velvet Gazette"
                color: Colours.ink
                font.pixelSize: 40
                tracking: 1
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.closeSettings()
                }
            }
        }

        // the rooms, as links under the name
        Row {
            y: 94
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            height: 24

            Repeater {
                model: root.host.zones

                Row {
                    id: zt

                    required property var modelData
                    required property int index

                    readonly property bool sel: zt.index === (root.host.flipTarget >= 0 ? root.host.flipTarget : root.host.zone)

                    spacing: 0

                    P5Text {
                        visible: zt.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "   ·   "
                        color: Colours.alpha(Colours.ink, 0.4)
                        font.pixelSize: 12
                    }
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: zl.implicitWidth
                        height: 22

                        P5Text {
                            id: zl

                            anchors.centerIn: parent
                            text: zt.modelData.name
                            color: zt.sel || zma.containsMouse ? Colours.accent : Colours.ink
                            font.pixelSize: 12
                            font.weight: zt.sel ? Font.Bold : Font.Medium
                            tracking: 2
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Colours.accent
                            visible: zt.sel
                        }
                        MouseArea {
                            id: zma

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.host.setZone(zt.index)
                        }
                    }
                }
            }
        }
    }

    // ── the sections
    Item {
        id: sections

        visible: root.host.zone === 1
        x: root.x0
        y: root.host.roomY
        width: root.span
        height: root.host.railStripH
        opacity: root.host.flipping ? 0 : 1

        Rectangle {
            width: parent.width
            height: 1
            color: root.rule
        }
        Rectangle {
            y: parent.height - 1
            width: parent.width
            height: 1
            color: root.rule
        }

        Row {
            anchors.centerIn: parent
            spacing: 0

            Repeater {
                model: Schema.tabs

                Row {
                    id: sec

                    required property var modelData
                    required property int index

                    readonly property bool sel: sec.index === root.host.tabIndex

                    spacing: 0

                    P5Text {
                        visible: sec.index > 0
                        anchors.verticalCenter: parent.verticalCenter
                        text: "   "
                        font.pixelSize: 12
                    }
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: st.implicitWidth + 16
                        height: 30

                        Rectangle {
                            anchors.fill: parent
                            color: sec.sel ? Colours.alpha(Colours.accent, root.host.column === 0 ? 0.14 : 0.07) : (sma.containsMouse ? Colours.alpha(Colours.ink, 0.05) : "transparent")

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }
                        P5Text {
                            id: st

                            anchors.centerIn: parent
                            text: sec.modelData.name
                            color: sec.sel || sma.containsMouse ? Colours.accent : Colours.ink
                            font.pixelSize: 12
                            font.weight: sec.sel ? Font.Bold : Font.Medium
                            tracking: 1.4
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 2
                            color: Colours.accent
                            visible: sec.sel
                        }
                        MouseArea {
                            id: sma

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.host.enterTab(sec.index)
                        }
                    }
                }
            }
        }
    }

    // ── the front page: what is in this issue
    Item {
        id: toc

        visible: root.host.zone === 1 && root.host.home
        x: root.host.listX
        y: root.host.bodyY
        width: root.host.listW
        height: root.host.bodyH
        opacity: root.host.entered && !root.host.flipping ? 1 : 0

        Column {
            width: parent.width
            spacing: 6

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: "In this issue"
                color: Colours.ink
                font.pixelSize: 30
                font.italic: true
            }
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Choose a section from the bar above, or just begin to type."
                color: Colours.inkDim
                font.pixelSize: 14
                font.italic: true
            }
            Rectangle {
                width: parent.width
                height: 1
                color: root.rule
            }
        }

        Grid {
            y: 92
            width: parent.width
            columns: 2
            columnSpacing: 56
            rowSpacing: 2

            Repeater {
                model: Schema.tabs

                Item {
                    id: entry

                    required property var modelData
                    required property int index

                    width: (toc.width - 56) / 2
                    height: 40

                    Rectangle {
                        anchors.fill: parent
                        color: ema.containsMouse || entry.index === root.host.tabIndex ? Colours.alpha(Colours.accent, 0.08) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                    P5Text {
                        id: en

                        anchors.verticalCenter: parent.verticalCenter
                        x: 6
                        text: entry.modelData.name
                        color: entry.index === root.host.tabIndex || ema.containsMouse ? Colours.accent : Colours.ink
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: en.x + en.implicitWidth + 10
                        width: Math.max(0, pn.x - x - 10)
                        clip: true
                        text: ". . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . ."
                        color: Colours.alpha(Colours.ink, 0.25)
                        font.family: Appearance.fontFamily.body
                        font.pixelSize: 13
                    }
                    P5Text {
                        id: pn

                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        text: `${entry.index + 1}`
                        color: Colours.inkDim
                        font.pixelSize: 14
                        font.italic: true
                    }
                    MouseArea {
                        id: ema

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.host.enterTab(entry.index)
                    }
                }
            }
        }
    }

    // ── the folio
    Item {
        x: root.x0
        y: root.host.insetT + root.host.fieldH - root.host.footH
        width: root.span
        height: root.host.footH

        Rectangle {
            width: parent.width
            height: 1
            color: root.rule
        }
        Row {
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.host.hintList

                Row {
                    required property var modelData
                    required property int index

                    spacing: 6

                    P5Text {
                        visible: index > 0
                        text: "·"
                        color: Colours.alpha(Colours.ink, 0.4)
                        font.pixelSize: 12
                    }
                    P5Text {
                        text: modelData.k
                        color: Colours.accent
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                    P5Text {
                        text: modelData.v
                        color: Colours.inkDim
                        font.pixelSize: 11
                        font.italic: true
                    }
                }
            }
        }
        P5Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.host.zone === 1
            text: `${root.host.tabIndex + 1}`
            color: Colours.inkDim
            font.pixelSize: 12
            font.italic: true
        }
    }
}
