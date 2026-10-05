//  VELVET  ·  modules/bar/entries/Workspaces.qml
//  Fixed set of slots with a single indicator that slides between them.
//  Occupied workspaces fill in; the active one gets the accent slash.
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick

Item {
    id: root

    property bool vertical: true
    property int span: 30
    property var win: null
    required property ShellScreen screen

    readonly property int shown: Math.max(1, Config.bar.workspaces.shown)
    readonly property int cell: Math.round(root.span * 0.86)
    readonly property int gap: Math.round(Config.bar.spacing * 0.5)

    // Which block of workspaces we're looking at — pages of `shown`.
    readonly property int groupStart: Math.floor((Hypr.activeWsId - 1) / shown) * shown + 1

    // TASKBAR → WORKSPACE STYLE. SLASH is the house wedge; the others are
    // the round inspo looks: PILLS (the active one stretches into a pill
    // with its number), DOTS, NUMBERS.
    // The terminal, the newspaper and the book write them out instead: [1] 2 3,
    // I II III — text, not shapes.
    readonly property bool textLook: ["console", "ledger", "tome"].indexOf(Appearance.skin) >= 0
    readonly property string look: root.textLook ? "text" : (["slash", "pills", "dots", "numbers"].indexOf(Config.bar.workspaces.style) >= 0 ? Config.bar.workspaces.style : "slash")
    readonly property bool slashLook: root.look === "slash"
    readonly property real textW: Math.round(root.cell * (Appearance.skin === "console" ? 1.15 : 1.5))
    readonly property real textLen: root.shown * root.textW + (root.shown - 1) * Math.max(2, root.gap * 0.4)
    readonly property var roman: ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
    readonly property int activeIndex: Hypr.activeWsId - root.groupStart
    // The round looks: a small slot per workspace, the active one longer.
    readonly property real small: root.look === "numbers" ? root.cell * 0.9 : Math.round(root.cell * 0.46)
    readonly property real big: root.look === "pills" ? Math.round(root.cell * 1.7) : root.small
    readonly property real roundGap: root.look === "numbers" ? Math.max(2, root.gap * 0.6) : Math.max(4, root.gap)
    readonly property real roundLength: root.shown * root.small + (root.shown - 1) * root.roundGap + (root.big - root.small)

    implicitWidth: vertical ? span : (root.textLook ? root.textLen : (root.slashLook ? shown * cell + (shown - 1) * gap : root.roundLength))
    implicitHeight: vertical ? (root.textLook ? root.textLen : (root.slashLook ? shown * cell + (shown - 1) * gap : root.roundLength)) : span

    // -------------------------------------------------------------- indicator
    Slash {
        id: indicator

        readonly property int activeIndex: Hypr.activeWsId - root.groupStart
        readonly property real pos: activeIndex * (root.cell + root.gap)

        visible: root.slashLook && Config.bar.workspaces.activeIndicator && activeIndex >= 0 && activeIndex < root.shown
        shear: Appearance.skew
        color: Colours.accent

        width: root.vertical ? root.cell : root.cell
        height: root.vertical ? root.cell : root.cell
        x: root.vertical ? (root.span - root.cell) / 2 : pos
        y: root.vertical ? pos : (root.span - root.cell) / 2

        Behavior on x {
            enabled: !root.vertical
            SpringAnimation {
                spring: 4.2
                damping: 0.42
                epsilon: 0.4
            }
        }
        Behavior on y {
            enabled: root.vertical
            SpringAnimation {
                spring: 4.2
                damping: 0.42
                epsilon: 0.4
            }
        }

        // (No idle pulse: an infinite animation here redrew — and re-blurred —
        // the whole bar every frame, forever. The spring move is the motion.)
    }

    // ------------------------------------------------------------------ slots
    Repeater {
        model: root.slashLook ? root.shown : 0

        Item {
            id: slot

            required property int index

            readonly property int wsId: root.groupStart + index
            readonly property bool isActive: wsId === Hypr.activeWsId
            readonly property int windows: Hypr.windowsOn(wsId)
            readonly property bool occupied: windows > 0

            width: root.cell
            height: root.cell
            x: root.vertical ? (root.span - root.cell) / 2 : index * (root.cell + root.gap)
            y: root.vertical ? index * (root.cell + root.gap) : (root.span - root.cell) / 2

            // Resting dot for an empty slot.
            Rectangle {
                anchors.centerIn: parent
                width: slot.occupied ? root.cell * 0.42 : root.cell * 0.2
                height: width
                radius: width / 2
                visible: !Config.bar.workspaces.labelOccupied && !slot.isActive
                color: slot.occupied ? Colours.inkDim : Colours.alpha(Colours.inkDim, 0.35)
                antialiasing: true

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                    }
                }
            }

            // Number label — used when the slot is active, or always if the
            // user turned labels on.
            P5Text {
                anchors.centerIn: parent
                display: true
                visible: slot.isActive || Config.bar.workspaces.labelOccupied
                text: `${slot.wsId}`
                font.pixelSize: root.cell * 0.52
                color: slot.isActive ? Colours.on(Colours.accent) : (slot.occupied ? Colours.ink : Colours.alpha(Colours.inkDim, 0.5))
            }

            // Window-count pips, hugging the far edge of the slot.
            Row {
                visible: Config.bar.workspaces.showWindows && slot.occupied && !slot.isActive
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1

                Repeater {
                    model: Math.min(3, slot.windows)

                    Rectangle {
                        width: 3
                        height: 2
                        radius: 1
                        color: Colours.alpha(Colours.accent, 0.8)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: peek.restart()
                onExited: {
                    peek.stop();
                    Popout.release("ws");
                }

                onClicked: {
                    Sfx.cursor();
                    Hypr.focusWorkspace(slot.wsId);
                }

                // Long enough that sweeping across the strip does not flicker.
                Timer {
                    id: peek
                    interval: 420
                    onTriggered: Popout.workspace(slot.wsId, slot, root.win)
                }
            }
        }
    }

    // ------------------------------------------------------ the round looks
    // ------------------------------------------------------ the written looks
    Repeater {
        model: root.textLook ? root.shown : 0

        Item {
            id: word

            required property int index

            readonly property int wsId: root.groupStart + index
            readonly property bool isActive: wsId === Hypr.activeWsId
            readonly property bool occupied: Hypr.windowsOn(wsId) > 0
            readonly property real along: index * (root.textW + Math.max(2, root.gap * 0.4))

            width: root.vertical ? root.span : root.textW
            height: root.vertical ? root.textW : root.span
            x: root.vertical ? 0 : word.along
            y: root.vertical ? word.along : 0

            Rectangle {
                anchors.fill: parent
                anchors.margins: root.vertical ? 2 : 3
                visible: Appearance.skin === "console" && (word.isActive || wordArea.containsMouse)
                color: word.isActive ? Colours.accent : Colours.alpha(Colours.accent, 0.2)
            }
            P5Text {
                anchors.centerIn: parent
                text: Appearance.skin === "console" ? `${word.wsId}` : (root.roman[word.wsId - 1] ?? `${word.wsId}`)
                color: word.isActive ? (Appearance.skin === "console" ? Colours.on(Colours.accent) : Colours.accent) : (word.occupied ? Colours.ink : Colours.alpha(Colours.inkDim, 0.7))
                font.pixelSize: Math.round(root.span * 0.46)
                font.weight: word.isActive ? Font.Black : Font.Medium
                font.italic: Appearance.skin !== "console"
            }
            // newspaper: an ink bar under the one you are on; book: a jewel
            Rectangle {
                visible: Appearance.skin === "ledger" && word.isActive
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.6
                height: 2
                color: Colours.accent
            }
            Rectangle {
                visible: Appearance.skin === "tome" && word.isActive
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: 6
                height: 6
                rotation: 45
                color: Colours.accent
            }

            MouseArea {
                id: wordArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: wordPeek.restart()
                onExited: {
                    wordPeek.stop();
                    Popout.release("ws");
                }
                onClicked: {
                    Sfx.cursor();
                    Hypr.focusWorkspace(word.wsId);
                }

                Timer {
                    id: wordPeek
                    interval: 420
                    onTriggered: Popout.workspace(word.wsId, word, root.win)
                }
            }
        }
    }

    Repeater {
        model: root.slashLook || root.textLook ? 0 : root.shown

        Item {
            id: dot

            required property int index

            readonly property int wsId: root.groupStart + index
            readonly property bool isActive: wsId === Hypr.activeWsId
            readonly property int windows: Hypr.windowsOn(wsId)
            readonly property bool occupied: windows > 0
            // Where this slot starts along the bar: every slot before it is
            // small, and the active one (if it is before) adds its stretch.
            readonly property real along: index * (root.small + root.roundGap) + (root.activeIndex >= 0 && root.activeIndex < index ? root.big - root.small : 0)
            readonly property real len: dot.isActive ? root.big : root.small
            readonly property real thick: root.look === "numbers" ? root.small : root.small

            x: root.vertical ? (root.span - dot.thick) / 2 : dot.along
            y: root.vertical ? dot.along : (root.span - dot.thick) / 2
            width: root.vertical ? dot.thick : dot.len
            height: root.vertical ? dot.len : dot.thick

            Behavior on x {
                enabled: !root.vertical
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on y {
                enabled: root.vertical
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
            Behavior on height {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: blob

                anchors.centerIn: parent
                // DOTS: the active one is a fuller accent dot; the others
                // shrink when empty.
                readonly property real d: root.look === "dots" ? (dot.isActive ? dot.thick : (dot.occupied ? dot.thick * 0.72 : dot.thick * 0.5)) : 0
                width: root.look === "dots" ? blob.d : parent.width
                height: root.look === "dots" ? blob.d : parent.height
                radius: Appearance.pill(Math.min(width, height))
                color: dot.isActive ? Colours.accent : (root.look === "numbers" ? (dotHover.containsMouse ? Colours.alpha(Colours.ink, 0.1) : "transparent") : (dot.occupied ? Colours.alpha(Colours.ink, dotHover.containsMouse ? 0.9 : 0.62) : Colours.alpha(Colours.ink, dotHover.containsMouse ? 0.5 : 0.24)))
                antialiasing: true

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                    }
                }
            }

            // The number: always for NUMBERS, only in the active pill for PILLS.
            P5Text {
                anchors.centerIn: parent
                visible: root.look === "numbers" || (root.look === "pills" && dot.isActive)
                text: `${dot.wsId}`
                font.pixelSize: Math.round(dot.thick * (root.look === "numbers" ? 0.56 : 0.72))
                font.weight: Font.Bold
                font.italic: false
                color: dot.isActive ? Colours.on(Colours.accent) : (dot.occupied ? Colours.ink : Colours.alpha(Colours.inkDim, 0.6))
            }

            MouseArea {
                id: dotHover

                anchors.fill: parent
                anchors.margins: -Math.round(root.roundGap / 2)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onEntered: dotPeek.restart()
                onExited: {
                    dotPeek.stop();
                    Popout.release("ws");
                }
                onClicked: {
                    Sfx.cursor();
                    Hypr.focusWorkspace(dot.wsId);
                }

                Timer {
                    id: dotPeek
                    interval: 420
                    onTriggered: Popout.workspace(dot.wsId, dot, root.win)
                }
            }
        }
    }
}
