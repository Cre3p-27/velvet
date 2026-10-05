//  VELVET  ·  modules/settings/SkinArcade.qml
//  The settings as a game's menu, kept tidy: a title bar with the rooms, a row
//  of level-select tiles for the categories, the key hints under everything.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var host: null

    readonly property real x0: root.host.insetL + root.host.pad
    readonly property real span: root.host.fieldW - root.host.pad * 2
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ── the title bar
    Item {
        x: root.x0
        y: root.host.insetT + 10
        width: root.span
        height: root.host.headH - 16

        Slash {
            anchors.fill: parent
            shear: 0
            color: Colours.alpha(Colours.surface, 0.96)
            outlineWidth: 0
            shadowKind: "none"
        }

        Row {
            x: 22
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: "SETTINGS"
                color: Colours.accent
                font.pixelSize: 30
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.closeSettings()
                }
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 3
                text: `${root.total} OPTIONS`
                color: Colours.inkDim
                font.pixelSize: 12
            }
        }

        // the rooms
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Repeater {
                model: root.host.zones

                Item {
                    id: ztab

                    required property var modelData
                    required property int index

                    readonly property bool sel: ztab.index === (root.host.flipTarget >= 0 ? root.host.flipTarget : root.host.zone)

                    width: zt.implicitWidth + 30
                    height: 34

                    Slash {
                        anchors.fill: parent
                        shear: 0
                        color: ztab.sel ? Colours.accent : (zma.containsMouse ? Colours.alpha(Colours.ink, 0.12) : Colours.alpha(Colours.ink, 0.05))
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
                        color: ztab.sel ? Colours.on(Colours.accent) : Colours.ink
                        font.pixelSize: 12
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

    // ── the level select
    Item {
        id: strip

        visible: root.host.zone === 1
        x: root.x0
        y: root.host.roomY
        width: root.span
        height: root.host.railStripH
        opacity: root.host.flipping ? 0 : 1

        Row {
            id: tiles

            spacing: 6
            y: 6

            Repeater {
                model: Schema.tabs

                Item {
                    id: tile

                    required property var modelData
                    required property int index

                    readonly property bool sel: tile.index === root.host.tabIndex
                    readonly property bool hot: tma.containsMouse

                    width: Math.floor((strip.width - 6 * (Schema.tabs.length - 1)) / Schema.tabs.length)
                    height: strip.height - 14
                    y: tile.sel ? -2 : (tile.hot ? -1 : 0)

                    Behavior on y {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Slash {
                        anchors.fill: parent
                        shear: 0
                        color: tile.sel ? Colours.alpha(Colours.accent, root.host.column === 0 ? 1 : 0.9) : (tile.hot ? Colours.surfaceHigh : Colours.alpha(Colours.surface, 0.9))
                        outlineWidth: tile.sel ? 2 : 1
                        shadowKind: tile.sel ? Config.appearance.shadow : "none"

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: tile.modelData.icon
                            color: tile.sel ? Colours.on(Colours.accent) : Colours.accent
                            font.pixelSize: 24
                        }
                        P5Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tile.width - 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: tile.modelData.name
                            color: tile.sel ? Colours.on(Colours.accent) : Colours.alpha(Colours.ink, 0.85)
                            font.pixelSize: 10
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

    // ── the title screen
    Column {
        visible: root.host.zone === 1 && root.host.home
        x: root.host.listX
        y: root.host.bodyY + root.host.bodyH * 0.24
        width: root.host.listW
        spacing: 14
        opacity: root.host.entered && !root.host.flipping ? 1 : 0

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            display: true
            text: "SELECT A CATEGORY"
            color: Colours.accent
            font.pixelSize: 26
        }
        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "◀  ▶   CHOOSE        ENTER   START        /   SEARCH"
            color: Colours.ink
            font.pixelSize: 13
        }
        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: `${root.total} OPTIONS TO TUNE`
            color: Colours.inkDim
            font.pixelSize: 12
        }
    }

    // ── the bottom line
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

                    spacing: 7

                    Slash {
                        anchors.verticalCenter: parent.verticalCenter
                        width: kc.implicitWidth + 14
                        height: 22
                        shear: 0
                        color: Colours.alpha(Colours.ink, 0.08)
                        outlineWidth: 0
                        shadowKind: "none"

                        P5Text {
                            id: kc

                            anchors.centerIn: parent
                            text: modelData.k
                            color: Colours.accent
                            font.pixelSize: 11
                        }
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.v
                        color: Colours.inkDim
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
