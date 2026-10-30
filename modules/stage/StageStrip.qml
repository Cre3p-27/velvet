//  VELVET  ·  modules/stage/StageStrip.qml
//  The cards of a STAGE desktop (services/Stage.qml): every window waiting in
//  the wings, as a picture of itself on a card that leans back into the
//  screen, in a strip at the edge (MODULES → STAGE → SIDE). Point at one: it
//  straightens up, comes forward and goes live. Click: that window steps on
//  stage and the one there takes its place among the cards. While there are
//  cards the strip keeps its edge clear of windows, so the stage is the
//  middle of what is left.
pragma ComponentBehavior: Bound

import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen modelData

    readonly property int ws: Hypr.monitorFor(root.modelData)?.activeWorkspace?.id ?? 0
    readonly property bool staged: WorkspaceModes.modes[String(root.ws)] === "stage"
    readonly property var cards: Stage.wings[String(root.ws)] ?? []
    readonly property var shown: root.cards.slice(0, Math.max(1, Config.stage.cards))
    readonly property bool onLeft: Config.stage.side !== "right"
    readonly property int cardW: Math.max(110, Math.min(260, Config.stage.card))
    readonly property int pad: 18

    function info(addr: string): var {
        const tops = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < tops.length; i++) {
            const raw = tops[i].lastIpcObject;
            if (raw && raw.address === addr)
                return raw;
        }
        return null;
    }

    screen: modelData
    color: "transparent"
    visible: root.staged && root.cards.length > 0 && !Focus.hidesBar
    WlrLayershell.namespace: "velvet-stage"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: root.cardW + root.pad * 2 - 10

    anchors {
        top: true
        bottom: true
        left: root.onLeft
        right: !root.onLeft
    }

    margins {
        left: root.onLeft ? Appearance.frameRoom("left") : 0
        right: root.onLeft ? 0 : Appearance.frameRoom("right")
    }

    // room beside the cards for the title of the one you point at (the mask
    // keeps that room from catching clicks)
    implicitWidth: root.cardW + root.pad * 2 + 30 + 340

    mask: Region {
        item: column
    }

    Column {
        id: column

        x: root.onLeft ? root.pad : root.width - width - root.pad
        anchors.verticalCenter: parent.verticalCenter
        width: root.cardW
        spacing: 16

        Repeater {
            model: root.shown

            Item {
                id: card

                required property string modelData
                required property int index

                readonly property var raw: root.info(card.modelData)
                readonly property real aspect: {
                    const s = card.raw?.size ?? [16, 10];
                    return Math.max(0.5, Math.min(0.95, (s[1] || 10) / Math.max(1, s[0] || 16)));
                }
                // the lean: 1 tilted back into the screen, 0 upright (pointed at)
                property real lean: Config.stage.tilt && !pointer.hovered ? 1 : 0
                // entering: the cards fan in one after another
                property real born: 0

                width: root.cardW
                height: Math.round(root.cardW * card.aspect)
                opacity: card.born
                scale: (pointer.hovered ? 1.07 : 1) * (0.9 + 0.1 * card.born) * (press.pressed ? 0.95 : 1)
                transformOrigin: root.onLeft ? Item.Left : Item.Right

                Behavior on lean {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.8
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutBack
                    }
                }

                NumberAnimation on born {
                    from: 0
                    to: 1
                    duration: 380
                    easing.type: Easing.OutCubic
                }

                // leaning back: a projection hinged on the strip's edge, the
                // far side smaller — like the cards stand in the room
                transform: Matrix4x4 {
                    readonly property real k: (root.onLeft ? 0.0024 : -0.0024) * card.lean
                    readonly property real ox: root.onLeft ? 0 : card.width
                    readonly property real oy: card.height / 2
                    matrix: Qt.matrix4x4(1 + k * ox, 0, 0, -k * ox * ox, k * oy, 1, 0, -k * ox * oy, 0, 0, 1, 0, k, 0, 0, 1 - k * ox)
                }

                // the shadow it casts on the desktop
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    anchors.topMargin: 6
                    radius: 16
                    color: Qt.rgba(0, 0, 0, 0.35)
                    z: -1
                }

                Rectangle {
                    id: frame

                    anchors.fill: parent
                    radius: 14
                    color: Colours.alpha(Colours.surface, 0.92)
                    border.width: pointer.hovered ? 2 : 1
                    border.color: pointer.hovered ? Colours.accent : Colours.alpha(Colours.ink, 0.18)
                    clip: true

                    // the window's own picture (live while pointed at); the
                    // icon on a tint when there is none
                    AppIcon {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) * 0.42
                        height: width
                        cls: `${card.raw?.class ?? ""}`
                        opacity: 0.85
                    }

                    Loader {
                        id: shot

                        anchors.fill: parent
                        anchors.margins: 3
                        asynchronous: true
                        source: Qt.resolvedUrl("../map/Preview.qml")
                        onLoaded: {
                            shot.item.source = Qt.binding(() => Hypr.toplevelFor(card.modelData));
                            shot.item.live = Qt.binding(() => pointer.hovered);
                        }
                    }
                }

                // the app's badge, over the card's corner
                Rectangle {
                    x: root.onLeft ? -6 : parent.width - width + 6
                    y: parent.height - height + 6
                    width: 30
                    height: 30
                    radius: 15
                    color: Colours.surface
                    border.width: 1
                    border.color: Colours.alpha(Colours.ink, 0.15)

                    AppIcon {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        cls: `${card.raw?.class ?? ""}`
                    }
                }

                // its title, while you point at it
                Rectangle {
                    visible: pointer.hovered
                    x: root.onLeft ? parent.width + 12 : -width - 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(320, title.implicitWidth + 20)
                    height: 26
                    radius: 13
                    color: Colours.alpha(Colours.ink0, 0.88)

                    P5Text {
                        id: title

                        anchors.centerIn: parent
                        width: parent.width - 20
                        text: `${card.raw?.title ?? card.raw?.class ?? ""}`
                        color: "#ffffff"
                        font.pixelSize: Appearance.font.size.tiny
                        elide: Text.ElideRight
                    }
                }

                HoverHandler {
                    id: pointer

                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (pointer.hovered)
                            Sfx.hover();
                    }
                }

                TapHandler {
                    id: press

                    onTapped: {
                        Sfx.select();
                        Stage.pick(card.modelData, root.ws);
                    }
                }
            }
        }

        // more waiting than there are cards
        Rectangle {
            visible: root.cards.length > root.shown.length
            width: 56
            height: 28
            radius: 14
            anchors.horizontalCenter: parent.horizontalCenter
            color: Colours.alpha(Colours.surface, 0.9)

            P5Text {
                anchors.centerIn: parent
                text: `+${root.cards.length - root.shown.length}`
                color: Colours.ink
                font.pixelSize: Appearance.font.size.small
            }
        }
    }
}
