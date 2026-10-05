//  VELVET  ·  modules/island/IslandTasks.qml
//  The TASKS body of the Dynamic Island — the workflow list, checkable
//  without ever leaving the pill. Tap a task to check it off, type a new
//  one at the bottom, and the ring keeps the score. Done tasks drop to the
//  bottom, dimmed, so the list itself becomes the reward.
//
//  Like every island module, this rides on black: all text is ink (the
//  palette's light text), never paper.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    anchors.fill: parent

    readonly property int pad: 24

    // ---------------------------------------------------------------- header
    P5Text {
        x: root.pad
        y: 20
        display: true
        text: "TASKS"
        color: Colours.ink
        font.pixelSize: Appearance.font.size.title
        tracking: 1
    }

    P5Text {
        x: root.pad
        y: 62
        text: `${Tasks.openCount} OPEN  ·  ${Tasks.doneCount} DONE`
        color: Colours.inkDim
        font.pixelSize: Appearance.font.size.tiny
        tracking: 1.4
    }

    // The score ring — the whole day at a glance.
    CircularProgress {
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        y: 18
        width: 46
        height: 46
        thickness: 3
        value: Tasks.progress
        color: Tasks.openCount === 0 ? Colours.accentAlt : Colours.accent
        text: `${Tasks.doneCount}/${Tasks.openCount + Tasks.doneCount}`
        textSize: Appearance.font.size.tiny - 1
    }

    // ------------------------------------------------------------- the list
    Flickable {
        id: list

        x: root.pad
        y: 96
        width: root.width - root.pad * 2
        height: root.height - 96 - 58
        clip: true
        contentHeight: listColumn.height
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 2600

        Column {
            id: listColumn

            width: parent.width
            spacing: 4

            // The empty state: nothing to do, and that is worth saying.
            Item {
                width: parent.width
                height: 130
                visible: Tasks.openCount + Tasks.doneCount === 0

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    width: 30
                    name: "task_alt"
                    color: Colours.alpha(Colours.ink, 0.35)
                    font.pixelSize: 28
                }

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 48
                    display: true
                    text: "ALL CLEAR"
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.large
                    tracking: 1.6
                }

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 82
                    text: "TYPE BELOW  ·  OR SUPER+TAB → WORKFLOW"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.2
                }
            }

            // Open tasks — the rows you actually work with.
            Repeater {
                model: Tasks.open.length

                TaskRow {
                    id: openRow

                    required property int index

                    width: parent.width
                    height: 44
                    item: Tasks.open[index]
                }
            }

            // Done tasks, dimmed and struck through, pinned under a quiet
            // divider. Checking them back on sends them straight up.
            Item {
                width: parent.width
                height: 20
                visible: Tasks.doneCount > 0

                Rectangle {
                    y: 10
                    width: parent.width
                    height: 1
                    color: Colours.alpha(Colours.ink, 0.14)
                }

                P5Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1
                    width: 90
                    horizontalAlignment: Text.AlignHCenter
                    text: "DONE"
                    color: Colours.inkDim
                    font.pixelSize: Appearance.font.size.tiny
                    tracking: 1.6
                    // cover the divider
                    Rectangle {
                        anchors.fill: parent
                        z: -1
                        color: "#050505"
                    }
                }
            }

            Repeater {
                model: Tasks.finished.length

                TaskRow {
                    required property int index

                    width: parent.width
                    height: 40
                    item: Tasks.finished[index]
                }
            }
        }

        SmoothScroll {
            view: list
        }
    }

    // -------------------------------------------------------------- add row
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        height: 40
        radius: Math.min(12, height / 2)
        color: Colours.alpha(Colours.ink, 0.07)
        border.width: 1
        border.color: addInput.activeFocus ? Colours.accent : Colours.alpha(Colours.ink, 0.16)
        clip: true

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            x: 14
            width: 16
            name: "add"
            color: addInput.activeFocus ? Colours.accent : Colours.inkDim
            font.pixelSize: 16
        }

        TextInput {
            id: addInput

            anchors.left: parent.left
            anchors.leftMargin: 38
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            color: Colours.ink
            font.family: Appearance.fontFamily.body
            font.pixelSize: Appearance.font.size.small
            selectByMouse: true
            // The caret follows the accent.
            cursorDelegate: Rectangle {
                width: 2
                color: Colours.accent
            }

            onAccepted: {
                const id = Tasks.add(text);
                if (id >= 0) {
                    Sfx.select();
                    text = "";
                    list.returnToBounds();
                }
            }

            // Escape leaves the input without closing the island; typing is
            // not the island's business.
            Keys.onEscapePressed: event => {
                focus = false;
                event.accepted = true;
            }
        }
    }

    // ------------------------------------------------------------- task row
    component TaskRow: Item {
        id: row

        required property var item
        readonly property bool done: row.item?.done ?? false
        readonly property bool pinned: row.item?.pinned ?? false
        property bool hovered: false

        // The check circle — accent ring that fills when the task is done.
        Plate {
            anchors.verticalCenter: parent.verticalCenter
            x: 2
            width: 20
            height: 20
            radius: Appearance.r(10)
            color: row.done ? Colours.accent : "transparent"
            border.width: 1.5
            border.color: row.done ? Colours.accent : Colours.alpha(Colours.ink, 0.35)
            scale: hoverArea.pressed ? 0.86 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }

            Icon {
                anchors.centerIn: parent
                width: 12
                visible: row.done
                name: "check"
                color: "#050505"
                font.pixelSize: 12
            }
        }

        P5Text {
            anchors.left: parent.left
            anchors.leftMargin: 32
            anchors.right: parent.right
            anchors.rightMargin: row.hovered && !row.done ? 34 : 8
            anchors.verticalCenter: parent.verticalCenter
            text: row.item?.text ?? ""
            color: row.done ? Colours.alpha(Colours.inkDim, 0.7) : Colours.ink
            font.pixelSize: row.done ? Appearance.font.size.small : Appearance.font.size.normal
            elide: Text.ElideRight
            lineHeight: 1.05
            // Strikethrough on done — drawn, not a style, so it stays crisp.
            font.strikeout: row.done
            opacity: row.done ? 0.75 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        // Pin — taps only on the tiny mark itself, so a stray click cannot
        // pin things by accident.
        Icon {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            visible: row.pinned && !row.done
            name: "push_pin"
            color: Colours.accent
            font.pixelSize: 13

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!row.item)
                        return;
                    Sfx.toggle();
                    Tasks.togglePin(row.item.id);
                }
            }
        }

        // Remove — appears on hover so the list stays quiet otherwise.
        Icon {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            visible: row.hovered
            name: "close"
            color: Colours.alpha(Colours.ink, 0.5)
            font.pixelSize: 14

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!row.item)
                        return;
                    Sfx.back();
                    Tasks.remove(row.item.id);
                }
            }
        }

        MouseArea {
            id: hoverArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: row.hovered = true
            onExited: row.hovered = false
            onClicked: {
                if (!row.item)
                    return;
                Sfx.select();
                Tasks.toggle(row.item.id);
            }
        }
    }
}
