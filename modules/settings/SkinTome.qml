//  VELVET  ·  modules/settings/SkinTome.qml
//  The settings as an old book, understated: a title between two thin lines,
//  the rooms as tabs on the edge of the page, the categories as numbered
//  chapters on the left page, the entries on the right with the spine between.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var host: null
    property bool back: false

    readonly property real x0: root.host.insetL + root.host.pad
    readonly property real span: root.host.fieldW - root.host.pad * 2
    readonly property var roman: ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI"]
    readonly property int zoneSel: root.host.flipTarget >= 0 ? root.host.flipTarget : root.host.zone
    readonly property color gold: Colours.accent
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ── the layer behind the lists: the two pages and the spine
    Item {
        anchors.fill: parent
        visible: root.back

        Slash {
            visible: root.host.zone === 1
            opacity: root.host.flipping ? 0 : 1
            x: root.host.railX - 12
            y: root.host.bodyY - 4
            width: root.host.fieldW - root.host.pad * 2 + 24
            height: root.host.bodyH + 8
            shape: "square"
            shear: 0
            color: Colours.alpha(Colours.surface, 0.5)
            borderColor: Colours.alpha(root.gold, 0.4)
            borderWidth: 1
            outlineWidth: 0
            shadowKind: "none"
        }

        // the spine
        Item {
            visible: root.host.zone === 1
            x: root.host.listX - 7
            y: root.host.bodyY
            width: 14
            height: root.host.bodyH

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 1
                height: parent.height
                color: Colours.alpha(root.gold, 0.4)
            }
            Rectangle {
                width: parent.width
                height: parent.height
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: "transparent"
                    }
                    GradientStop {
                        position: 0.5
                        color: Colours.alpha(Colours.ink0, 0.28)
                    }
                    GradientStop {
                        position: 1.0
                        color: "transparent"
                    }
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: !root.back

        // ── the title, between two thin lines
        Item {
            x: root.x0
            y: root.host.insetT + 10
            width: root.span
            height: root.host.headH - 14

            Row {
                anchors.centerIn: parent
                spacing: 18

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 70
                    height: 1
                    color: Colours.alpha(root.gold, 0.6)
                }
                Column {
                    spacing: 1

                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        display: true
                        text: "The Book of Velvet"
                        color: root.gold
                        font.pixelSize: 26
                        tracking: 2
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Panels.closeSettings()
                        }
                    }
                    P5Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.host.zone === 1 ? String(root.host.breadcrumb ?? "").replace(/ › /g, "  ·  ") : root.host.zones[root.host.zone].name
                        color: Colours.inkDim
                        font.pixelSize: 11
                        font.italic: true
                        tracking: 2
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 70
                    height: 1
                    color: Colours.alpha(root.gold, 0.6)
                }
            }

            // the rooms, as tabs on the edge of the page
            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -6
                spacing: 4

                Repeater {
                    model: root.host.zones

                    Item {
                        id: ribbon

                        required property var modelData
                        required property int index

                        readonly property bool sel: ribbon.index === root.zoneSel

                        width: rt.implicitWidth + 26
                        height: ribbon.sel ? 32 : 28
                        anchors.bottom: parent.bottom

                        Behavior on height {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: ribbon.sel ? Colours.alpha(root.gold, 0.18) : (rma.containsMouse ? Colours.alpha(root.gold, 0.08) : Colours.alpha(Colours.surface, 0.6))
                            border.width: 1
                            border.color: Colours.alpha(root.gold, ribbon.sel ? 0.7 : 0.3)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }
                        Rectangle {
                            width: parent.width
                            height: 2
                            color: root.gold
                            opacity: ribbon.sel ? 1 : 0
                        }
                        P5Text {
                            id: rt

                            anchors.centerIn: parent
                            text: ribbon.modelData.name
                            color: ribbon.sel ? root.gold : Colours.alpha(Colours.ink, 0.8)
                            font.pixelSize: 11
                            font.weight: ribbon.sel ? Font.Bold : Font.Medium
                            tracking: 1.6
                        }
                        MouseArea {
                            id: rma

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.host.setZone(ribbon.index)
                        }
                    }
                }
            }
        }

        // ── the chapters
        Item {
            id: chapters

            visible: root.host.zone === 1
            x: root.host.railX + 10
            y: root.host.bodyY + 12
            width: root.host.railW - 22
            height: root.host.bodyH - 24
            opacity: root.host.flipping ? 0 : 1

            P5Text {
                text: "Contents"
                color: Colours.inkDim
                font.pixelSize: 12
                font.italic: true
                tracking: 3
            }
            Rectangle {
                y: 22
                width: parent.width
                height: 1
                color: Colours.alpha(root.gold, 0.35)
            }

            Column {
                y: 30
                width: parent.width

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: ch

                        required property var modelData
                        required property int index

                        readonly property bool sel: ch.index === root.host.tabIndex
                        readonly property int count: root.host.countOf(ch.modelData.items ?? [])

                        width: chapters.width
                        height: Math.min(38, (chapters.height - 40) / Schema.tabs.length)

                        Rectangle {
                            anchors.fill: parent
                            color: ch.sel ? Colours.alpha(root.gold, root.host.column === 0 ? 0.2 : 0.1) : (cma.containsMouse ? Colours.alpha(root.gold, 0.07) : "transparent")

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }
                        Rectangle {
                            width: 2
                            height: parent.height
                            color: root.gold
                            opacity: ch.sel ? 1 : 0
                        }
                        P5Text {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: 36
                            text: root.roman[ch.index]
                            color: ch.sel ? root.gold : Colours.alpha(root.gold, 0.7)
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                        P5Text {
                            x: 52
                            anchors.verticalCenter: parent.verticalCenter
                            text: ch.modelData.name
                            color: ch.sel ? Colours.ink : Colours.alpha(Colours.ink, 0.85)
                            font.pixelSize: 14
                            font.weight: ch.sel ? Font.Bold : Font.Medium
                            elide: Text.ElideRight
                            width: chapters.width - 52 - 40
                        }
                        P5Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: ch.count > 0
                            text: `${ch.count}`
                            color: Colours.inkDim
                            font.pixelSize: 11
                            font.italic: true
                        }
                        MouseArea {
                            id: cma

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.host.enterTab(ch.index)
                        }
                    }
                }
            }
        }

        // ── the first page of the right-hand side, before a chapter is opened
        Item {
            visible: root.host.zone === 1 && root.host.home
            x: root.host.listX + 30
            y: root.host.bodyY
            width: root.host.listW - 60
            height: root.host.bodyH
            opacity: root.host.entered && !root.host.flipping ? 1 : 0

            Column {
                anchors.centerIn: parent
                spacing: 14
                width: parent.width

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    display: true
                    text: "Choose a chapter"
                    color: Colours.ink
                    font.pixelSize: 26
                    tracking: 2
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 90
                    height: 1
                    color: root.gold
                }
                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(parent.width, 460)
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: `${Schema.tabs.length} chapters hold ${root.total} entries. Turn to the one you need on the left page, or begin to write and the book will search itself.`
                    color: Colours.inkDim
                    font.pixelSize: 14
                    font.italic: true
                    lineHeight: 1.25
                }
            }
        }

        // ── the prompts along the foot
        Item {
            x: root.x0
            y: root.host.insetT + root.host.fieldH - root.host.footH
            width: root.span
            height: root.host.footH

            Row {
                anchors.centerIn: parent
                spacing: 20

                Repeater {
                    model: root.host.hintList

                    Row {
                        required property var modelData

                        spacing: 6

                        P5Text {
                            text: modelData.k
                            color: root.gold
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
        }
    }
}
