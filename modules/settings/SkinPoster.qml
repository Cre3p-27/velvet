//  VELVET  ·  modules/settings/SkinPoster.qml
//  The settings as a plain poster: one big headline, the rooms as flat blocks,
//  the categories as a stack of outlined labels, key hints along the foot.
//  Black outlines, a small hard shadow, one colour.
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
    readonly property string headline: root.host.zone !== 1 ? root.host.zones[root.host.zone].name : (root.host.home ? "SETTINGS" : (root.host.tab?.name ?? ""))
    readonly property int total: {
        let n = 0;
        for (let i = 0; i < Schema.tabs.length; i++)
            n += root.host.countOf(Schema.tabs[i].items ?? []);
        return n;
    }

    // ── the headline
    Item {
        x: root.x0
        y: root.host.insetT + 8
        width: root.span
        height: root.host.headH - 14

        Item {
            id: hl

            width: hlText.implicitWidth
            height: hlText.implicitHeight
            anchors.verticalCenter: parent.verticalCenter

            P5Text {
                id: hlText

                display: true
                text: root.headline
                color: Colours.edge
                font.pixelSize: 54
                tracking: -1
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.closeSettings()
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                height: 5
                color: Colours.accent
                z: -1
            }
        }

        P5Text {
            x: hl.width + 18
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: 8
            text: `${root.total} settings`
            color: Colours.inkDim
            font.pixelSize: 13
            tracking: 1
        }

        // the rooms, flat blocks
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

                    readonly property bool sel: ztab.index === root.zoneSel

                    width: zt.implicitWidth + 32
                    height: 38

                    Slash {
                        anchors.fill: parent
                        shear: 0
                        color: ztab.sel ? Colours.edge : (zma.containsMouse ? Colours.surfaceHigh : Colours.alpha(Colours.surface, 0.9))
                        shadowKind: ztab.sel ? "none" : Config.appearance.shadow

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                    P5Text {
                        id: zt

                        anchors.centerIn: parent
                        display: true
                        text: ztab.modelData.name
                        color: ztab.sel ? Colours.paper : Colours.edge
                        font.pixelSize: 13
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

    // a plain rule under the headline
    Rectangle {
        x: root.host.insetL
        y: root.host.insetT + root.host.headH - 4
        width: root.host.fieldW
        height: 2
        color: Colours.edge
    }

    // ── the stack of labels
    Item {
        id: stack

        visible: root.host.zone === 1
        x: root.host.railX
        y: root.host.bodyY
        width: root.host.railW
        height: root.host.bodyH
        opacity: root.host.flipping ? 0 : 1

        Column {
            width: parent.width
            spacing: 6

            Repeater {
                model: Schema.tabs

                Item {
                    id: st

                    required property var modelData
                    required property int index

                    readonly property bool sel: st.index === root.host.tabIndex
                    readonly property int count: root.host.countOf(st.modelData.items ?? [])

                    width: stack.width - 8
                    height: Math.min(44, (stack.height - 8) / Schema.tabs.length - 6)
                    x: st.sel ? 8 : (sma.containsMouse ? 3 : 0)

                    Behavior on x {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Slash {
                        anchors.fill: parent
                        shear: 0
                        color: st.sel ? Colours.accent : Colours.alpha(Colours.surface, 0.95)
                        shadowKind: st.sel ? Config.appearance.shadow : "none"

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }
                    P5Text {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(st.index + 1).padStart(2, "0")
                        color: st.sel ? Colours.alpha(Colours.edge, 0.7) : Colours.inkDim
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                    P5Text {
                        x: 46
                        anchors.verticalCenter: parent.verticalCenter
                        display: true
                        text: st.modelData.name
                        color: Colours.edge
                        font.pixelSize: 17
                        tracking: 0.4
                        elide: Text.ElideRight
                        width: stack.width - 46 - 60
                    }
                    P5Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: st.count > 0
                        text: `${st.count}`
                        color: st.sel ? Colours.alpha(Colours.edge, 0.7) : Colours.inkDim
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        id: sma

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.host.enterTab(st.index)
                    }
                }
            }
        }
    }

    // ── the front page
    Item {
        visible: root.host.zone === 1 && root.host.home
        x: root.host.listX
        y: root.host.bodyY
        width: root.host.listW
        height: root.host.bodyH
        opacity: root.host.entered && !root.host.flipping ? 1 : 0

        Column {
            anchors.centerIn: parent
            spacing: 10

            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                display: true
                text: "PICK ONE."
                color: Colours.edge
                font.pixelSize: 64
                tracking: -1
            }
            P5Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `or start typing to search all ${root.total} settings`
                color: Colours.inkDim
                font.pixelSize: 14
                tracking: 0.6
            }
        }
    }

    // ── the foot
    Item {
        x: root.host.insetL
        y: root.host.insetT + root.host.fieldH - root.host.footH
        width: root.host.fieldW
        height: root.host.footH

        Rectangle {
            width: parent.width
            height: 2
            color: Colours.edge
        }
        Row {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1
            spacing: 22

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
                        color: Colours.alpha(Colours.surface, 0.95)
                        shadowKind: "none"

                        P5Text {
                            id: kc

                            anchors.centerIn: parent
                            display: true
                            text: modelData.k
                            color: Colours.edge
                            font.pixelSize: 10
                        }
                    }
                    P5Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.v
                        color: Colours.inkDim
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        tracking: 0.8
                    }
                }
            }
        }
    }
}
