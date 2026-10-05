//  VELVET  ·  modules/lock/LockClean.qml
//  The lock of the quiet looks: CLEAN, MINIMAL, FLAT, NEUMORPH and CLAY share
//  this face and each wears it differently. Clean is a pale veil, a calm clock
//  and a white pill with a hairline; minimal drops the pill for one line; flat
//  is a solid bar with square corners; neumorph is a plate pushed out of the
//  paper by a light and a shadow (and pressed in as you type); clay is a fat,
//  soft, tinted lozenge. A wrong password shakes it, once. THIS LOOK (depth,
//  gloss, light, clay colour) and LOCK SCREEN → VIBE FACES tune it.
import qs.config
import qs.services
import qs.components
import QtQuick

Item {
    id: root

    property var kit: null

    readonly property real u: Math.max(0.5, Math.min(root.width / 1920, root.height / 1080))
    readonly property color ink: Colours.ink

    readonly property string fl: Appearance.flavour
    readonly property bool neu: root.fl === "neu"
    readonly property bool clay: root.fl === "clay"
    readonly property bool flat: root.fl === "flat"
    readonly property bool minimal: root.fl === "minimal"

    // the colour clay is made of, and how far a plate is pushed out
    readonly property color tint: Config.appearance.clayTint === "accent" ? Colours.accent : Colours.clay
    readonly property real depth: Appearance.depth
    readonly property point light: Appearance.lightSign

    // the geometry of the field in each mood
    readonly property real fieldW: (root.minimal ? 420 : (root.clay ? 500 : 460)) * root.u
    readonly property real fieldH: (root.clay ? 78 : (root.minimal ? 54 : 62)) * root.u
    readonly property real fieldR: root.minimal ? 0 : (root.flat ? 6 * root.u : root.fieldH / 2)
    readonly property bool pressed: root.kit.length > 0

    LockWall {
        anchors.fill: parent
        ground: Colours.paper
        blur: root.kit.blurOr(root.neu || root.minimal ? 1 : 0.9)
        dim: root.kit.dimOr(root.neu ? 0.97 : (root.minimal ? 0.9 : (root.flat ? 0.88 : (root.clay ? 0.82 : 0.78))))
    }
    // clay and flat tint the veil; neumorph and minimal keep it plain
    Rectangle {
        anchors.fill: parent
        visible: root.clay || root.flat
        color: Colours.alpha(root.clay ? root.tint : Colours.accent, root.flat ? 0.06 : 0.1)
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * (root.minimal ? 0.3 : 0.2)
        spacing: 8 * root.u

        FitClock {
            anchors.horizontalCenter: parent.horizontalCenter
            display: true
            text: root.kit.clockText
            font.family: root.kit.typeface(Appearance.fontFamily.display)
            color: root.kit.tint(root.ink)
            want: Math.min(root.height * (root.minimal ? 0.18 : 0.22), (root.minimal ? 200 : 240) * root.u) * Math.min(root.kit.clockScale, 1.4)
            maxWidth: root.width * 0.9
            font.weight: root.minimal ? Font.Light : (root.flat ? Font.Bold : (root.clay ? Font.ExtraBold : Font.DemiBold))
            tracking: root.minimal ? -2 : -4
        }
        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: root.kit.date(root.kit.stamp("dddd, d MMMM"))
            color: Colours.inkDim
            font.pixelSize: 26 * root.u
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * (root.minimal ? 0.6 : 0.62)
        spacing: 16 * root.u
        transform: Translate { x: root.kit.shake }

        Item {
            id: pill

            anchors.horizontalCenter: parent.horizontalCenter
            width: root.fieldW
            height: root.fieldH
            scale: root.kit.recoil

            // ── what lifts the field off the sheet
            // clean · flat: a soft shadow
            Rectangle {
                visible: root.fl === "clean"
                y: 4 * root.u * root.depth
                width: parent.width
                height: parent.height
                radius: root.fieldR
                color: Qt.rgba(0, 0, 0, 0.07 * Math.min(2, root.depth))
            }
            // neumorph: a dark side and a light side, closer when pressed
            Rectangle {
                visible: root.neu
                x: root.light.x * (root.pressed ? 3 : 9) * root.u * root.depth
                y: root.light.y * (root.pressed ? 3 : 9) * root.u * root.depth
                width: parent.width
                height: parent.height
                radius: root.fieldR
                color: Colours.light ? Qt.rgba(0.45, 0.5, 0.6, 0.34) : Qt.rgba(0, 0, 0, 0.5)

                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
            Rectangle {
                visible: root.neu
                x: -root.light.x * (root.pressed ? 3 : 9) * root.u * root.depth
                y: -root.light.y * (root.pressed ? 3 : 9) * root.u * root.depth
                width: parent.width
                height: parent.height
                radius: root.fieldR
                color: Colours.light ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.07)

                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
            // clay: a fat tinted shadow underneath
            Rectangle {
                visible: root.clay
                y: 9 * root.u * root.depth
                width: parent.width - 8 * root.u
                x: 4 * root.u
                height: parent.height
                radius: root.fieldR
                color: Colours.alpha(root.tint, 0.55)
            }

            // ── the field itself
            Rectangle {
                id: body

                anchors.fill: parent
                radius: root.fieldR
                color: {
                    if (root.kit.failed)
                        return Colours.alpha(Colours.danger, root.minimal ? 0 : 0.12);
                    if (root.minimal)
                        return "transparent";
                    if (root.neu)
                        return Colours.paper;
                    if (root.flat)
                        return Colours.mix(Colours.paper, Colours.accent, 0.12);
                    if (root.clay)
                        return Colours.mix(Colours.surface, root.tint, 0.32);
                    return Colours.alpha(Colours.surface, 0.97);
                }
                border.width: root.neu ? 0 : (root.minimal ? 0 : (root.flat ? 2 * root.u : 1))
                border.color: root.kit.failed ? Colours.alpha(Colours.danger, 0.8) : (root.flat ? Colours.accent : Colours.alpha(root.ink, 0.12))

                Behavior on color { ColorAnimation { duration: 160 } }
                Behavior on border.color { ColorAnimation { duration: 160 } }

                // clay: the sheen on its upper lip
                Rectangle {
                    visible: root.clay && Appearance.gloss > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 5 * root.u
                    width: parent.width - parent.radius * 1.1
                    height: parent.height * 0.3
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, Math.min(0.5, 0.32 * Appearance.gloss))
                }
            }
            // minimal: one line under the dots
            Rectangle {
                visible: root.minimal
                anchors.bottom: parent.bottom
                width: parent.width
                height: 2 * root.u
                color: root.kit.failed ? Colours.danger : Colours.alpha(root.ink, root.pressed ? 0.7 : 0.25)

                Behavior on color { ColorAnimation { duration: 160 } }
            }

            // the user, small, on the left (minimal has none)
            Rectangle {
                visible: !root.minimal && root.kit.showUser
                x: 9 * root.u
                anchors.verticalCenter: parent.verticalCenter
                width: root.fieldH - 18 * root.u
                height: width
                radius: root.flat ? 4 * root.u : width / 2
                color: root.flat ? Colours.accent : Colours.alpha(root.clay ? root.tint : Colours.accent, root.clay ? 0.35 : 0.14)

                P5Text {
                    anchors.centerIn: parent
                    text: (root.kit.user.charAt(0) || "?").toUpperCase()
                    color: root.flat ? Colours.on(Colours.accent) : Colours.accentInk
                    font.pixelSize: 20 * root.u
                    font.weight: Font.DemiBold
                }
            }
            readonly property real textLeft: root.minimal || !root.kit.showUser ? 24 * root.u : root.fieldH + 6 * root.u

            P5Text {
                anchors.centerIn: parent
                visible: root.kit.length === 0
                text: root.kit.busy ? "Checking…" : (root.kit.failed ? (root.kit.message ? root.kit.message.charAt(0) + root.kit.message.slice(1).toLowerCase() : "Wrong password") : (root.kit.hello !== "" ? root.kit.hello : "Password"))
                color: root.kit.failed ? Colours.danger : Colours.alpha(root.ink, 0.45)
                font.pixelSize: 19 * root.u
            }
            PassMask {
                anchors.left: parent.left
                anchors.leftMargin: pill.textLeft
                anchors.verticalCenter: parent.verticalCenter
                centered: false
                kit: root.kit
                colour: root.ink
                track: Colours.alpha(root.ink, 0.15)
                size: 17 * root.u
                family: Appearance.fontFamily.body
            }
            Row {
                anchors.left: parent.left
                anchors.leftMargin: pill.textLeft
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * root.u
                visible: root.kit.mask === "dots"

                Repeater {
                    model: 17

                    Rectangle {
                        required property int index

                        readonly property bool lit: index < root.kit.length

                        width: 11 * root.u
                        height: root.minimal ? 3 * root.u : width
                        radius: root.flat ? 2 * root.u : height / 2
                        color: root.ink
                        scale: lit ? 1 : 0

                        Behavior on scale {
                            NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 2 }
                        }
                    }
                }
            }
            Rectangle {
                visible: !root.minimal
                anchors.right: parent.right
                anchors.rightMargin: 9 * root.u
                anchors.verticalCenter: parent.verticalCenter
                width: root.fieldH - 18 * root.u
                height: width
                radius: root.flat ? 4 * root.u : width / 2
                color: root.clay ? root.tint : Colours.accent
                opacity: root.kit.length > 0 && !root.kit.busy ? 1 : 0

                Behavior on opacity { NumberAnimation { duration: 140 } }

                Icon {
                    anchors.centerIn: parent
                    name: "arrow_forward"
                    color: Colours.on(parent.color)
                    font.pixelSize: 22 * root.u
                }
            }
        }
        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: text !== ""
            text: root.kit.caps ? "Caps lock is on" : (root.kit.showUser ? root.kit.name : "")
            color: root.kit.caps ? Colours.warning : Colours.inkDim
            font.pixelSize: 16 * root.u
        }
        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.kit.hints && root.kit.length === 0 && !root.kit.failed
            text: "Press Enter to unlock"
            color: Colours.alpha(root.ink, 0.4)
            font.pixelSize: 14 * root.u
        }
    }

    LockExtras {
        anchors.left: parent.left
        anchors.leftMargin: 56 * root.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44 * root.u
        width: root.width * 0.45
        kit: root.kit
        colour: Colours.alpha(root.ink, 0.5)
        family: Appearance.fontFamily.body
        size: 15 * root.u
        align: Text.AlignLeft
    }
}
