//  VELVET  ·  modules/settings/SkinClean.qml
//  The settings as one quiet sheet in the middle of the screen: a slim top
//  line with the rooms, a sidebar of categories with a search pill, a single
//  column of rows between hairlines, the key hints along the foot.
//  Everything is sentence case, everything eases, nothing shouts.
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
    readonly property string fl: Appearance.flavour
    readonly property bool soft: root.fl === "neu" || root.fl === "clay"
    readonly property real rad: ({ minimal: 0, flat: 4, neu: 30, clay: 38 })[root.fl] ?? Appearance.r(14)
    // ink on the sidebar: white on the flat look's navy column
    readonly property color sideInk: root.fl === "flat" ? "#ffffff" : Colours.ink
    readonly property color sideDim: root.fl === "flat" ? Qt.rgba(1, 1, 1, 0.62) : Colours.inkDim
    readonly property color sideSelInk: root.fl === "flat" ? Colours.on(Colours.accent) : Colours.ink
    readonly property int zoneSel: root.host.flipTarget >= 0 ? root.host.flipTarget : root.host.zone
    readonly property color hair: Colours.alpha(Colours.ink, 0.09)
    readonly property real sideW: root.host.pad + root.host.railW + root.host.sg.gap / 2
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ═══ the layer behind the lists: the sheet, what it casts, the sidebar's ground
    Item {
        anchors.fill: parent
        visible: root.back

        // ── the sheet and what it casts
        Repeater {
            model: root.fl === "clean" ? 5 : 0

            Rectangle {
                required property int index

                x: root.fx - index * 3
                y: root.fy + 10 + index * 2
                width: root.fw + index * 6
                height: root.fh + index * 6 - 4
                radius: root.rad + index * 3
                color: Qt.rgba(0.05, 0.07, 0.12, 0.07 - index * 0.012)
            }
        }
        Rectangle {
            visible: !root.soft
            x: root.fx
            y: root.fy
            width: root.fw
            height: root.fh
            radius: root.rad
            color: Colours.surfaceHigh
            border.width: root.fl === "clean" ? 1 : 0
            border.color: root.hair
        }
        Puff {
            visible: root.soft
            x: root.fx
            y: root.fy
            width: root.fw
            height: root.fh
            kind: root.fl === "neu" ? "raised" : "clay"
            radius: root.rad
            depth: root.fl === "neu" ? 16 : 26
            color: root.fl === "neu" ? Colours.surface : Colours.surfaceHigh
        }

        // ── the sidebar's ground (clipped to the sheet's square part) — only
        // the SETTINGS room has a sidebar; HOME and the others use the whole sheet
        Rectangle {
            visible: root.host.zone === 1
            x: root.fx + 1
            y: root.host.roomY
            width: root.sideW
            height: root.fh - root.host.headH - root.host.footH
            color: root.fl === "flat" ? Colours.mix(Colours.ink, Colours.accent, 0.1) : ((root.fl === "minimal" || Config.appearance.cleanSide === "plain") ? "transparent" : (root.fl === "clay" ? Colours.alpha(Config.appearance.clayTint === "accent" ? Colours.accent : Colours.clay, 0.07) : Colours.alpha(Colours.ink, root.fl === "neu" ? 0.02 : 0.03)))
        }
        Rectangle {
            visible: root.host.zone === 1
            x: root.fx + root.sideW
            y: root.host.roomY
            width: 1
            height: root.fh - root.host.headH - root.host.footH
            color: root.soft ? "transparent" : root.hair
        }


        Rectangle {
            x: root.fx
            y: root.host.roomY - 1
            width: root.fw
            height: 1
            color: root.soft ? "transparent" : root.hair
        }
        Rectangle {
            x: root.fx
            y: root.fy + root.fh - root.host.footH
            width: root.fw
            height: 1
            color: root.soft ? "transparent" : root.hair
        }
    }

    // ═══ the layer above them
    Item {
        anchors.fill: parent
        visible: !root.back

    // ── the top line: the name, the rooms, the way out
    Item {
        x: root.fx
        y: root.fy
        width: root.fw
        height: root.host.headH

        Row {
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: 12
                color: Colours.accent

                P5Text {
                    anchors.centerIn: parent
                    display: true
                    text: "V"
                    color: Colours.on(Colours.accent)
                    font.pixelSize: 13
                }
            }
            P5Text {
                anchors.verticalCenter: parent.verticalCenter
                display: true
                text: "Settings"
                color: Colours.ink
                font.pixelSize: 15
            }
        }

        // the rooms: text tabs with one underline that glides
        Item {
            id: tabs

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: tabRow.implicitWidth
            height: 36

            Row {
                id: tabRow

                spacing: 2

                Repeater {
                    model: root.host.zones

                    Item {
                        id: ztab

                        required property var modelData
                        required property int index

                        readonly property bool sel: ztab.index === root.zoneSel

                        width: zt.implicitWidth + 28
                        height: 36

                        Puff {
                            anchors.fill: parent
                            anchors.topMargin: 2
                            anchors.bottomMargin: 2
                            visible: root.soft && ztab.sel
                            kind: root.fl === "neu" ? "inset" : "clay"
                            radius: height / 2
                            depth: 4
                            color: root.fl === "neu" ? Colours.surface : Colours.mix(Colours.surfaceHigh, Colours.accent, 0.16)
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 3
                            anchors.bottomMargin: 3
                            radius: Appearance.r(9)
                            color: zma.containsMouse && !ztab.sel ? Colours.alpha(Colours.ink, 0.05) : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }
                        P5Text {
                            id: zt

                            anchors.centerIn: parent
                            text: Appearance.sentence(ztab.modelData.name)
                            color: ztab.sel ? Colours.ink : Colours.inkDim
                            font.pixelSize: 13
                            font.weight: ztab.sel ? Font.DemiBold : Font.Normal

                            Behavior on color {
                                ColorAnimation {
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

            Rectangle {
                readonly property var cell: tabRow.children[root.zoneSel] ?? null

                visible: !root.soft
                y: parent.height - (root.fl === "flat" ? 3 : 2)
                height: root.fl === "flat" ? 3 : (root.fl === "minimal" ? 1 : 2)
                radius: root.fl === "clean" ? 1 : 0
                x: cell ? cell.x + 14 : 0
                width: cell ? cell.width - 28 : 0
                color: Colours.accent

                Behavior on x {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        // close
        Item {
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: 30
            height: 30

            Rectangle {
                anchors.fill: parent
                radius: 15
                color: closeArea.containsMouse ? Colours.alpha(Colours.ink, 0.08) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
            Icon {
                anchors.centerIn: parent
                name: "close"
                color: closeArea.containsMouse ? Colours.ink : Colours.inkDim
                font.pixelSize: 16
            }
            MouseArea {
                id: closeArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.closeSettings()
            }
        }
    }
    // ── the sidebar
    Item {
        id: side

        visible: root.host.zone === 1
        x: root.host.railX
        y: root.host.bodyY + 14
        width: root.host.railW
        height: root.host.bodyH - 28
        opacity: root.host.flipping ? 0 : 1

        // search
        Item {
            id: search

            width: parent.width
            height: 34

            Puff {
                anchors.fill: parent
                visible: root.soft
                kind: root.fl === "neu" ? "inset" : "clay"
                radius: height / 2
                depth: 5
                color: root.fl === "neu" ? Colours.surface : Colours.surfaceHigh
            }
            Rectangle {
                anchors.fill: parent
                visible: !root.soft
                radius: root.fl === "clean" ? Appearance.pill(height) : (root.fl === "flat" ? 3 : 0)
                color: root.fl === "minimal" ? "transparent" : (root.fl === "flat" ? Qt.rgba(1, 1, 1, searchArea.containsMouse ? 0.16 : 0.1) : (searchArea.containsMouse ? Colours.alpha(Colours.ink, 0.08) : Colours.alpha(Colours.ink, 0.05)))
                border.width: root.fl === "clean" ? 1 : 0
                border.color: root.hair

                Rectangle {
                    visible: root.fl === "minimal"
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Colours.ink
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
            Icon {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                color: root.sideDim
                font.pixelSize: 16
            }
            P5Text {
                x: 36
                anchors.verticalCenter: parent.verticalCenter
                text: "Search settings"
                color: root.sideDim
                font.pixelSize: 13
            }
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20
                radius: 6
                color: Colours.alpha(Colours.ink, 0.07)

                P5Text {
                    anchors.centerIn: parent
                    text: "/"
                    color: root.sideDim
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: searchArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.host.searching = true
            }
        }

        // the categories, with one highlight that glides between them
        Item {
            id: cats

            y: 48
            width: parent.width
            height: parent.height - 48

            readonly property real step: Math.min(38, (height - 4) / Schema.tabs.length)

            Puff {
                visible: root.soft
                y: root.host.tabIndex * cats.step
                width: cats.width
                height: cats.step - 2
                kind: root.fl === "neu" ? "inset" : "clay"
                radius: height / 2.4
                depth: 5
                color: root.fl === "neu" ? Colours.surface : Colours.mix(Colours.surfaceHigh, Colours.accent, 0.16)

                Behavior on y {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }
            }
            Rectangle {
                visible: !root.soft
                y: root.host.tabIndex * cats.step
                width: root.fl === "minimal" ? 2 : cats.width
                height: cats.step - 2
                radius: root.fl === "clean" ? Appearance.r(10) : (root.fl === "flat" ? 3 : 0)
                color: root.fl === "flat" ? Colours.accent : (root.fl === "minimal" ? Colours.ink : Colours.alpha(Colours.accent, root.host.column === 0 ? 0.16 : 0.1))

                Behavior on y {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Repeater {
                model: Schema.tabs

                Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool sel: row.index === root.host.tabIndex
                    readonly property int count: root.host.countOf(row.modelData.items ?? [])

                    y: row.index * cats.step
                    width: cats.width
                    height: cats.step - 2

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.r(10)
                        color: rma.containsMouse && !row.sel ? Colours.alpha(Colours.ink, 0.05) : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                    Icon {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        name: row.modelData.icon
                        color: row.sel ? (root.fl === "flat" ? root.sideSelInk : Colours.accent) : root.sideDim
                        font.pixelSize: 18

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                    P5Text {
                        x: 40
                        anchors.verticalCenter: parent.verticalCenter
                        width: cats.width - 40 - 40
                        elide: Text.ElideRight
                        text: Appearance.sentence(row.modelData.name)
                        color: row.sel ? root.sideSelInk : Qt.rgba(root.sideInk.r, root.sideInk.g, root.sideInk.b, 0.82)
                        font.pixelSize: 14
                        font.weight: row.sel ? Font.DemiBold : Font.Normal
                    }
                    P5Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: row.count > 0
                        text: `${row.count}`
                        color: Qt.rgba(root.sideInk.r, root.sideInk.g, root.sideInk.b, 0.4)
                        font.pixelSize: 11
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

    // ── the front page: every category with a line about it
    Item {
        id: front

        visible: root.host.zone === 1 && root.host.home
        x: root.host.listX
        y: root.host.bodyY
        width: root.host.listW
        height: root.host.bodyH
        opacity: root.host.entered && !root.host.flipping ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }

        Column {
            y: 22
            width: parent.width
            spacing: 4

            P5Text {
                display: true
                text: "Settings"
                color: Colours.ink
                font.pixelSize: 28
            }
            P5Text {
                text: `${root.total} settings in ${Schema.tabs.length} categories. Pick one, or press / to search.`
                color: Colours.inkDim
                font.pixelSize: 14
            }
        }

        Grid {
            y: 104
            width: parent.width
            columns: 2
            columnSpacing: 12
            rowSpacing: 4

            Repeater {
                model: Schema.tabs

                Item {
                    id: tile

                    required property var modelData
                    required property int index

                    width: (front.width - 12) / 2
                    height: 60

                    Rectangle {
                        anchors.fill: parent
                        radius: Appearance.r(12)
                        color: tma.containsMouse ? Colours.alpha(Colours.ink, 0.05) : "transparent"
                        border.width: 1
                        border.color: tma.containsMouse ? root.hair : "transparent"

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                    Puff {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38
                        height: 38
                        visible: root.soft
                        kind: root.fl === "neu" ? "raised" : "clay"
                        radius: 12
                        depth: 5
                        color: root.fl === "neu" ? Colours.surface : Colours.mix(Colours.surfaceHigh, Colours.accent, 0.12)

                        Icon {
                            anchors.centerIn: parent
                            name: tile.modelData.icon
                            color: Colours.accent
                            font.pixelSize: 20
                        }
                    }
                    Rectangle {
                        visible: !root.soft && root.fl !== "minimal"
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: root.fl === "flat" ? 3 : Appearance.r(10)
                        color: root.fl === "flat" ? Colours.accent : Colours.alpha(Colours.accent, tma.containsMouse ? 0.18 : 0.1)

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: tile.modelData.icon
                            color: root.fl === "flat" ? Colours.on(Colours.accent) : Colours.accent
                            font.pixelSize: 20
                        }
                    }
                    Column {
                        x: 60
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 60 - 12
                        spacing: 1

                        P5Text {
                            text: Appearance.sentence(tile.modelData.name)
                            color: Colours.ink
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        P5Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: Appearance.sentence(tile.modelData.sub ?? "")
                            color: Colours.inkDim
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

    // ── the foot: the keys
    Item {
        x: root.fx
        y: root.fy + root.fh - root.host.footH
        width: root.fw
        height: root.host.footH

        Row {
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 1
            spacing: 18

            Repeater {
                model: root.host.hintList

                Row {
                    required property var modelData

                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: kc.implicitWidth + 12
                        height: 20
                        radius: 6
                        color: Colours.alpha(Colours.ink, 0.06)
                        border.width: 1
                        border.color: root.hair

                        P5Text {
                            id: kc

                            anchors.centerIn: parent
                            text: modelData.k
                            color: Colours.alpha(Colours.ink, 0.8)
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Appearance.sentence(modelData.v)
                        color: Colours.inkDim
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
    }
}
