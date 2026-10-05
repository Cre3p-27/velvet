//  VELVET  ·  modules/settings/TabRail.qml
//  The category column. Always on screen now — it is how you know where you
//  are, so it cannot be something you navigate away from.
//
//  The pointer only lights a category up; a click opens it. (Opening on
//  hover swapped the whole list whenever the pointer crossed the rail on
//  its way somewhere else.)
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    required property int currentIndex
    required property bool focused
    // The front page: bigger rows, centred in the column, right-aligned on
    // the screen. Inside a category the rail shrinks back to its quiet self.
    required property bool hero

    signal picked(int index)
    signal entered(int index)

    // How many settings live under a category, counted through its sub-pages.
    function countOf(items: var): int {
        let n = 0;
        for (let i = 0; i < (items?.length ?? 0); i++) {
            if (items[i].kind === "page")
                n += root.countOf(items[i].items ?? []);
            else if (items[i].kind !== "info")
                n++;
        }
        return n;
    }

    // The sub-tab open inside the selected category ("TASKBAR › CLOCK").
    property string trailText: ""

    implicitWidth: 320
    implicitHeight: column.implicitHeight

    Column {
        id: column

        width: parent.width
        spacing: Appearance.spacing.small

        // The rows' own total height, computed rather than asked for —
        // `implicitHeight` lies here: the row Items set `height` directly,
        // which leaves their implicitHeight at zero, and centring against
        // nothing left the categories pinned to the top of their column.
        readonly property real rowsH: Schema.tabs.length * (root.hero ? 76 : 62) * Appearance.densityScale * Config.appearance.spacingScale
            + (Schema.tabs.length - 1) * Appearance.spacing.small

        // On the front page the categories float in the middle of their
        // column; inside a category they pin to the top like always.
        y: root.hero ? Math.max(0, (parent.height - column.rowsH) / 2) : 0

        Behavior on y {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutExpo
            }
        }

        Repeater {
            model: Schema.tabs

            Item {
                id: tab

                required property var modelData
                required property int index

                readonly property bool selected: index === root.currentIndex
                readonly property bool hot: tabArea.containsMouse
                readonly property int count: root.countOf(tab.modelData.items)

                width: column.width
                height: Math.round((root.hero ? 76 : 62) * Appearance.densityScale * Config.appearance.spacingScale)

                // The rows breathe with the rest of the reveal.
                Behavior on height {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                // Was 42px and a fade to 35%, which turned seven of the eight
                // categories into grey noise. The selected one still moves and
                // fills; the others stay legible, because you choose between
                // them by reading them.
                x: selected ? 16 : (hot ? 6 : 0)
                scale: selected ? 1.02 : 1.0
                opacity: selected || hot ? 1.0 : (root.focused ? 0.9 : 0.78)

                Behavior on x {
                    SpringAnimation {
                        spring: 4.0
                        damping: 0.32
                        epsilon: 0.5
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                // The fill reaches past the name however long it is — "LOCK
                // SCREEN" used to run off the accent into dark-on-dark.
                Slash {
                    anchors.fill: parent
                    shear: Appearance.skew
                    color: tab.selected ? Colours.accent : (tab.hot ? Colours.alpha(Colours.ink, 0.08) : "transparent")
                    borderColor: !tab.selected && tab.hot ? Colours.alpha(Colours.ink, 0.22) : "transparent"
                    borderWidth: 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                Row {

                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: tab.modelData.icon
                        color: tab.selected ? Colours.on(Colours.accent) : Colours.accent
                        font.pixelSize: root.hero ? Math.round(Appearance.font.size.huge * 1.3) : Appearance.font.size.huge
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -2

                        P5Text {
                            id: tabName

                            display: true
                            text: tab.modelData.name
                            color: tab.selected ? Colours.on(Colours.accent) : Colours.ink
                            font.pixelSize: root.hero ? Math.round(Appearance.row.title * 1.24) : Appearance.row.title
                        }

                        P5Text {
                            // The subtitle used to appear only on the selected
                            // row, so the list changed height as you moved and
                            // told you nothing about where you were going.
                            text: tab.selected && root.trailText !== "" ? `›  ${root.trailText}` : tab.modelData.sub
                            color: tab.selected ? Colours.alpha(Colours.on(Colours.accent), root.trailText !== "" ? 0.95 : 0.78) : Colours.inkDim
                            font.pixelSize: Appearance.font.size.tiny
                            tracking: 1.2
                            width: root.width - 120
                            elide: Text.ElideRight
                        }
                    }
                }

                // How many settings live in it; editors (LOOKS, DESKTOP) have
                // none to count and say nothing.
                P5Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    // Only where the name leaves room for it.
                    visible: tab.count > 0 && !tab.selected && tabName.implicitWidth + 30 + Appearance.font.size.huge + 16 + 28 < tab.width - 22 - implicitWidth
                    text: `${tab.count}`
                    color: tab.selected ? Colours.alpha(Colours.on(Colours.accent), 0.7) : Colours.alpha(Colours.inkDim, 0.7)
                    font.pixelSize: Appearance.font.size.small
                    tracking: 1
                }

                MouseArea {
                    id: tabArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.entered(tab.index)
                    onClicked: root.picked(tab.index)
                }
            }
        }
    }
}
