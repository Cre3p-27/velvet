//  VELVET  ·  modules/settings/SoftLockTab.qml
//  LOCK SCREEN → SOFT LOCK → ARRANGE BY HAND: the SOFT lock as big as the
//  pane allows, with everything on it movable.
//
//    drag an element     put it anywhere — it snaps to the middle of the
//                        screen, hold Alt to place it freely
//    click an element    pick it: the column shows its shape, size,
//                        corners, form and switch
//    ← → ↑ ↓             nudge the picked one (Shift: a bigger step)
//
//  Under the picked element the column holds everything else: layout,
//  entrance, speed, one-after-another, gliding, turning shapes, the
//  digits, blur and the visualizer.
//
//  It is the lock's own face — the same code draws both — so what you
//  arrange here is exactly what the lock shows, on this screen's size.
//  Every change is a normal setting (lock.softPlace, lock.softStyle and
//  the rows of the SOFT LOCK page).
import qs.config
import qs.services
import qs.components
import qs.modules.lock
import QtQuick
import Qt5Compat.GraphicalEffects as GE

FocusScope {
    id: root

    focus: true

    // The screen the lock will fill; the settings pass their own.
    property real screenW: 1920
    property real screenH: 1080

    // The face itself, for whoever opens this pane with a pick in mind.
    readonly property alias face: face

    readonly property real side: 360
    readonly property real gap: 22
    readonly property real strip: 58
    // The picture: as wide as the room beside the column allows, never
    // taller than the pane minus the strip below it.
    readonly property real picW: Math.max(240, Math.min(root.width - root.side - root.gap, (root.height - root.strip) * root.screenW / Math.max(1, root.screenH)))
    readonly property real picH: Math.round(root.picW * root.screenH / Math.max(1, root.screenW))

    // The arrows nudge the picked element even when the picture has not
    // been clicked yet.
    Keys.onPressed: event => event.accepted = face.keyNudge(event)

    Item {
        id: pic

        width: root.picW
        height: root.picH
        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: pic.width
                height: pic.height
                radius: Appearance.r(20)
            }
        }

        SoftFace {
            id: face

            preview: true
            arranging: true
            focus: true
            width: root.screenW
            height: root.screenH
            scale: pic.width / Math.max(1, root.screenW)
            transformOrigin: Item.TopLeft
        }
    }

    Rectangle {
        width: pic.width
        height: pic.height
        radius: Appearance.r(20)
        color: "transparent"
        border.width: 1
        border.color: Colours.alpha(Colours.ink, 0.14)
        antialiasing: true
    }

    // ── under the picture: how it works, and the two big buttons
    Item {
        y: pic.height + 12
        width: pic.width
        height: root.strip - 12

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            SoftChip {
                icon: "replay"
                text: "Play the entrance"
                onClicked: face.replay()
            }
            SoftChip {
                icon: "restart_alt"
                text: "Reset the arrangement"
                onClicked: {
                    face.resetAll();
                    Toast.show("SOFT LOCK · BACK TO ITS LAYOUT'S OWN ARRANGEMENT", "info", 2400);
                }
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.5)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: "Drag to move  ·  click to pick  ·  ← → ↑ ↓ nudge, Shift more  ·  Alt: no snapping"
            color: Colours.alpha(Colours.ink, 0.55)
            font.family: Appearance.fontFamily.soft
            font.pixelSize: 12
        }
    }

    // ── the column: the picked element, then everything
    Plate {
        x: pic.width + root.gap
        width: Math.max(0, root.width - x)
        height: root.height
        radius: Appearance.r(20)
        color: Colours.alpha(Colours.tone, 0.97)
        antialiasing: true

        Flickable {
            id: flick

            anchors.fill: parent
            anchors.margins: 18
            contentHeight: col.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: col

                width: flick.width
                spacing: 12

                Heading {
                    text: "ELEMENT"
                }
                SoftInspector {
                    width: col.width
                    face: face
                    section: "element"
                }

                Rectangle {
                    width: col.width
                    height: 1
                    color: Colours.alpha(Colours.ink, 0.12)
                }

                Heading {
                    text: "EVERYTHING"
                }
                SoftInspector {
                    width: col.width
                    face: face
                    section: "global"
                }

                Item {
                    width: 1
                    height: 8
                }
            }

            SmoothScroll {
                view: flick
            }
        }
    }

    component Heading: Text {
        color: Colours.alpha(Colours.ink, 0.5)
        font.family: Appearance.fontFamily.soft
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1.4
    }
}
