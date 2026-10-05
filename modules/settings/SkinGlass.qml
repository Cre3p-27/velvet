//  VELVET  ·  modules/settings/SkinGlass.qml
//  The settings as frosted panes: a floating sidebar, a floating content
//  pane, the rooms as a segmented control, a launchpad of tiles on the front
//  page. Everything round, soft and see-through.
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
    readonly property int zoneSel: root.host.flipTarget >= 0 ? root.host.flipTarget : root.host.zone

    Item {
        anchors.fill: parent
        visible: root.back

        // ── the content pane behind the list
        GlassPane {
            visible: root.host.zone === 1
            opacity: root.host.flipping ? 0 : 1
            x: root.host.listX - 14
            y: root.host.bodyY
            width: root.host.listW + 28
            height: root.host.bodyH
            radius: 30
            tintA: 0.12
        }

    }

    Item {
        anchors.fill: parent
        visible: !root.back

        // ── the brand and the way you came
        Item {
            x: root.x0
            y: root.host.insetT + 20
            width: 360
            height: 48

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Slash {
                    width: 38
                    height: 38
                    shape: "round"
                    cornerRadius: 12
                    shear: 0
                    color: Colours.accent
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Panels.closeSettings()
                    }
                    P5Text {
                        anchors.centerIn: parent
                        display: true
                        text: "V"
                        color: Colours.on(Colours.accent)
                        font.pixelSize: 20
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    P5Text {
                        display: true
                        text: root.host.zone === 1 ? "Settings" : root.host.zones[root.host.zone].name
                        color: Colours.ink
                        font.pixelSize: 19
                    }
                    P5Text {
                        text: String(root.host.breadcrumb ?? "").replace(/ › /g, "  ›  ")
                        color: Colours.inkDim
                        font.pixelSize: 11
                        tracking: 1
                        elide: Text.ElideRight
                        width: 290
                    }
                }
            }
        }

        // ── the rooms, as a segmented control
        Item {
            id: seg

                x: root.host.insetL + (root.host.fieldW - width) / 2
            y: root.host.insetT + 22
            width: row.implicitWidth + 12
            height: 44

            Slash {
                anchors.fill: parent
                shape: "pill"
                shear: 0
                color: Colours.alpha(Colours.ink, 0.1)
                borderColor: Colours.alpha(Colours.ink, 0.14)
                borderWidth: 1
            }

            // the sliding thumb
            Slash {
                id: thumb

                readonly property var cell: row.children[root.zoneSel] ?? null

                y: 5
                height: parent.height - 10
                x: 6 + (cell ? cell.x : 0)
                width: cell ? cell.width : 80
                shape: "pill"
                shear: 0
                color: Colours.alpha(Colours.ink, 0.22)
                borderColor: Colours.alpha(Colours.accent, 0.6)
                borderWidth: 1

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.3
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Row {
                id: row

                x: 6
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: root.host.zones

                    Item {
                        id: ztab

                        required property var modelData
                        required property int index

                        width: zt.implicitWidth + 40
                        height: 34

                        P5Text {
                            id: zt

                            anchors.centerIn: parent
                            text: ztab.modelData.name
                            color: ztab.index === root.zoneSel ? Colours.ink : Colours.alpha(Colours.ink, 0.7)
                            font.pixelSize: 13
                            font.weight: ztab.index === root.zoneSel ? Font.Bold : Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.host.setZone(ztab.index)
                        }
                    }
                }
            }
        }

        // ── the sidebar pane
        Item {
            id: side

            visible: root.host.zone === 1
            x: root.host.railX
            y: root.host.bodyY
            width: root.host.railW
            height: root.host.bodyH
            opacity: root.host.flipping ? 0 : 1

            GlassPane {
                anchors.fill: parent
                radius: 30
                tintA: 0.15
            }

            Column {
                x: 12
                y: 14
                width: parent.width - 24
                spacing: 3

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: item

                        required property var modelData
                        required property int index

                        readonly property bool sel: item.index === root.host.tabIndex
                        readonly property int count: root.host.countOf(item.modelData.items ?? [])

                        width: parent.width
                        height: Math.min(52, (side.height - 28) / Schema.tabs.length - 3)

                        Slash {
                            anchors.fill: parent
                            shape: "round"
                            cornerRadius: 16
                            shear: 0
                            color: item.sel ? Colours.alpha(Colours.accent, root.host.column === 0 ? 0.34 : 0.22) : (ima.containsMouse ? Colours.alpha(Colours.ink, 0.1) : "transparent")
                            borderColor: item.sel ? Colours.alpha(Colours.accent, 0.7) : "transparent"
                            borderWidth: 1
                        }
                        Row {
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            Slash {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 30
                                shape: "round"
                                cornerRadius: 9
                                shear: 0
                                color: item.sel ? Colours.accent : Colours.alpha(Colours.ink, 0.12)
                                Icon {
                                    anchors.centerIn: parent
                                    name: item.modelData.icon
                                    color: item.sel ? Colours.on(Colours.accent) : Colours.ink
                                    font.pixelSize: 17
                                }
                            }
                            P5Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: item.modelData.name
                                color: Colours.ink
                                font.pixelSize: 15
                                font.weight: item.sel ? Font.Bold : Font.Medium
                                elide: Text.ElideRight
                                width: side.width - 24 - 14 - 44 - 40
                            }
                        }
                        P5Text {
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            visible: item.count > 0
                            text: `${item.count}`
                            color: Colours.alpha(Colours.ink, 0.5)
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: ima

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.host.enterTab(item.index)
                        }
                    }
                }
            }
        }

        // ── the front page: a launchpad of the categories
        Item {
            visible: root.host.zone === 1 && root.host.home
            x: root.host.listX
            y: root.host.bodyY
            width: root.host.listW
            height: root.host.bodyH
            opacity: root.host.entered && !root.host.flipping ? 1 : 0

            Column {
                x: 26
                y: 26
                spacing: 4

                P5Text {
                    display: true
                    text: "Settings"
                    color: Colours.ink
                    font.pixelSize: 44
                    font.weight: Font.Light
                }
                P5Text {
                    text: "Pick a category, or just start typing to search."
                    color: Colours.inkDim
                    font.pixelSize: 14
                }
            }

            Grid {
                x: 26
                y: 124
                width: parent.width - 52
                columns: 4
                spacing: 14

                Repeater {
                    model: Schema.tabs

                    Item {
                        id: tile

                        required property var modelData
                        required property int index

                        readonly property bool sel: tile.index === root.host.tabIndex

                        width: (parent.width - 14 * 3) / 4
                        height: 112
                        scale: tma.pressed ? 0.96 : (tma.containsMouse ? 1.03 : 1)

                        Behavior on scale {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                                easing.type: Easing.OutBack
                            }
                        }

                        GlassPane {
                            anchors.fill: parent
                            radius: 26
                            tintA: tile.sel ? 0.2 : (tma.containsMouse ? 0.14 : 0.08)
                            lit: tile.sel
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            Slash {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 44
                                height: 44
                                shape: "round"
                                cornerRadius: 14
                                shear: 0
                                color: tile.sel ? Colours.accent : Colours.alpha(Colours.ink, 0.14)
                                Icon {
                                    anchors.centerIn: parent
                                    name: tile.modelData.icon
                                    color: tile.sel ? Colours.on(Colours.accent) : Colours.ink
                                    font.pixelSize: 24
                                }
                            }
                            P5Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.name
                                color: Colours.ink
                                font.pixelSize: 14
                                font.weight: Font.Medium
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

        // ── the hints, in a pill
        Item {
            x: root.host.insetL + (root.host.fieldW - width) / 2
            y: root.host.insetT + root.host.fieldH - root.host.footH + 2
            width: hr.implicitWidth + 36
            height: 32

            Slash {
                anchors.fill: parent
                shape: "pill"
                shear: 0
                color: Colours.alpha(Colours.ink, 0.1)
                borderColor: Colours.alpha(Colours.ink, 0.12)
                borderWidth: 1
            }
            Row {
                id: hr

                anchors.centerIn: parent
                spacing: 18

                Repeater {
                    model: root.host.hintList

                    Row {
                        required property var modelData

                        spacing: 6

                        P5Text {
                            text: modelData.k
                            color: Colours.ink
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                        P5Text {
                            text: modelData.v
                            color: Colours.inkDim
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }

    // A pane of frosted glass: a bright edge, a sheen from the top-left, a line
    // of light along the top and a deep shadow underneath. The wallpaper (or
    // the aurora) shows through the fill.
    component GlassPane: Item {
        id: gp

        property real radius: 28
        property real tintA: 0.15
        property bool lit: false

        Repeater {
            model: 6

            Rectangle {
                required property int index

                x: -index * 2.5 * Appearance.depth
                y: (10 - index) * Appearance.depth
                width: gp.width + index * 5 * Appearance.depth
                height: gp.height + index * 5 * Appearance.depth
                radius: gp.radius + index * 2.5 * Appearance.depth
                color: Qt.rgba(0.03, 0.0, 0.16, Math.max(0, 0.1 - index * 0.015) * Math.min(1.6, Appearance.depth))
            }
        }
        // smoked glass underneath: keeps light type readable on a bright aurora
        Rectangle {
            anchors.fill: parent
            radius: gp.radius
            color: Qt.rgba(0.06, 0.03, 0.22, Config.appearance.glassSmoke)
        }
        Rectangle {
            anchors.fill: parent
            radius: gp.radius
            color: Qt.rgba(1, 1, 1, Math.min(0.6, gp.tintA * Config.appearance.glassFrost))
            border.width: 1
            border.color: gp.lit ? Qt.rgba(Colours.accent.r, Colours.accent.g, Colours.accent.b, 0.9) : Qt.rgba(1, 1, 1, Config.appearance.glassRim)

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: gp.radius - 1

            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, Math.min(0.8, 0.3 * Appearance.gloss)) }
                GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, Math.min(0.4, 0.06 * Appearance.gloss)) }
                GradientStop { position: 0.8; color: Qt.rgba(1, 1, 1, 0.0) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, Math.min(0.4, 0.1 * Appearance.gloss)) }
            }
        }
        Rectangle {
            x: gp.radius * 0.7
            y: 1
            width: Math.max(0, parent.width - gp.radius * 1.4)
            height: 1
            color: Qt.rgba(1, 1, 1, Math.min(1, 0.6 * Appearance.gloss))
        }
    }
}
