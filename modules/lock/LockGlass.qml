//  VELVET  ·  modules/lock/LockGlass.qml
//  The lock of the GLASS look: the wallpaper frosted over, a huge light clock,
//  the date above it, and a round picture over a frosted pill with the dots of
//  your password. Everything soft; a wrong password shakes the pill and tints it.
import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Effects

Item {
    id: root

    property var kit: null

    readonly property real u: Math.max(0.5, Math.min(root.width / 1920, root.height / 1080))

    LockWall {
        anchors.fill: parent
        blur: root.kit.blurOr(Math.min(1, 0.55 + 0.3 * Config.appearance.glassFrost))
        dim: root.kit.dimOr(0.1 + Config.appearance.glassSmoke * 1.0)
    }

    // ── the clock
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(root.height * 0.09, 80)
        spacing: 4 * root.u

        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.kit.date(root.kit.stamp("dddd, d MMMM"))
            visible: text !== ""
            color: Qt.rgba(1, 1, 1, 0.82)
            font.pixelSize: 30 * root.u
            font.weight: Font.Medium
            tracking: 1
        }
        FitClock {
            anchors.horizontalCenter: parent.horizontalCenter
            display: true
            text: root.kit.clockText
            font.family: root.kit.typeface(Appearance.fontFamily.display)
            color: root.kit.tint("#ffffff")
            want: Math.min(root.height * 0.3, 330 * root.u) * Math.min(root.kit.clockScale, 1.3)
            maxWidth: root.width * 0.92
            font.weight: Font.Thin
            tracking: -6
        }
    }

    // ── the person and the field
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.64
        spacing: 18 * root.u
        transform: Translate { x: root.kit.shake }

        // the picture
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 112 * root.u
            height: width

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.1 + 0.12 * Config.appearance.glassFrost)
                border.width: 2 * root.u
                border.color: Qt.rgba(1, 1, 1, Math.min(1, Config.appearance.glassRim))
            }
            Image {
                id: pic

                anchors.fill: parent
                anchors.margins: 4 * root.u
                source: root.kit.hasFace ? root.kit.faceUrl : ""
                fillMode: Image.PreserveAspectCrop
                visible: false
                asynchronous: true
            }
            MultiEffect {
                anchors.fill: pic
                source: pic
                visible: root.kit.hasFace && pic.status === Image.Ready
                maskEnabled: true
                maskSource: maskItem
            }
            Item {
                id: maskItem

                anchors.fill: pic
                visible: false
                layer.enabled: true

                Rectangle { anchors.fill: parent; radius: width / 2; color: "#000" }
            }
            P5Text {
                anchors.centerIn: parent
                visible: !(root.kit.hasFace && pic.status === Image.Ready)
                text: (root.kit.user.charAt(0) || "?").toUpperCase()
                color: "#ffffff"
                font.pixelSize: 54 * root.u
                font.weight: Font.Light
            }
        }
        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.kit.name
            visible: root.kit.showUser
            color: "#ffffff"
            font.pixelSize: 28 * root.u
            font.weight: Font.Medium
        }

        // the frosted pill
        Item {
            id: pill

            anchors.horizontalCenter: parent.horizontalCenter
            width: 440 * root.u
            height: 64 * root.u
            scale: root.kit.recoil

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: root.kit.failed ? Qt.rgba(1, 0.3, 0.35, 0.34) : Qt.rgba(1, 1, 1, 0.08 + 0.12 * Config.appearance.glassFrost)
                border.width: 1.5 * root.u
                border.color: root.kit.failed ? Qt.rgba(1, 0.5, 0.55, 0.8) : Qt.rgba(1, 1, 1, Math.min(1, Config.appearance.glassRim * 0.9))

                Behavior on color {
                    ColorAnimation { duration: 160 }
                }
            }
            P5Text {
                anchors.centerIn: parent
                visible: root.kit.length === 0
                text: root.kit.busy ? "Checking…" : (root.kit.failed ? (root.kit.message ? root.kit.message.charAt(0) + root.kit.message.slice(1).toLowerCase() : "Wrong password") : (root.kit.hello !== "" ? root.kit.hello : "Enter password"))
                color: Qt.rgba(1, 1, 1, 0.78)
                font.pixelSize: 20 * root.u
                font.weight: Font.Medium
            }
            PassMask {
                anchors.left: parent.left
                anchors.leftMargin: 28 * root.u
                anchors.verticalCenter: parent.verticalCenter
                centered: false
                kit: root.kit
                colour: "#ffffff"
                track: Qt.rgba(1, 1, 1, 0.28)
                size: 20 * root.u
                family: Appearance.fontFamily.body
            }
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 28 * root.u
                anchors.verticalCenter: parent.verticalCenter
                spacing: 9 * root.u
                visible: root.kit.mask === "dots"

                Repeater {
                    model: 18

                    Rectangle {
                        required property int index

                        readonly property bool lit: index < root.kit.length

                        width: 13 * root.u
                        height: width
                        radius: width / 2
                        color: "#ffffff"
                        scale: lit ? 1 : 0
                        opacity: lit ? 1 : 0

                        Behavior on scale {
                            NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 2.4 }
                        }
                    }
                }
            }
            // the arrow, when there is something to send
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 9 * root.u
                anchors.verticalCenter: parent.verticalCenter
                width: 46 * root.u
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.9)
                opacity: root.kit.length > 0 && !root.kit.busy ? 1 : 0
                scale: opacity > 0.5 ? 1 : 0.6

                Behavior on opacity { NumberAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                Icon {
                    anchors.centerIn: parent
                    name: "arrow_forward"
                    color: "#1b1f2a"
                    font.pixelSize: 24 * root.u
                }
            }
        }
        P5Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.kit.caps ? "Caps Lock is on" : (root.kit.hints && root.kit.length === 0 ? "Press Enter to unlock" : "")
            color: root.kit.caps ? Qt.rgba(1, 0.86, 0.5, 1) : Qt.rgba(1, 1, 1, 0.55)
            font.pixelSize: 15 * root.u
        }
    }

    // ── a frosted chip, bottom right: battery and network
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 48 * root.u
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44 * root.u
        spacing: 12 * root.u

        Repeater {
            model: [
                { show: root.kit.showInfo && Battery.available, t: `${Battery.percent}%${Battery.charging ? " ⚡" : ""}` },
                { show: root.kit.showInfo, t: Net.label || "Offline" }
            ]

            Rectangle {
                required property var modelData

                visible: modelData.show
                width: chipT.implicitWidth + 30 * root.u
                height: 38 * root.u
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.06 + 0.1 * Config.appearance.glassFrost)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, Math.min(1, Config.appearance.glassRim * 0.55))

                P5Text {
                    id: chipT

                    anchors.centerIn: parent
                    text: modelData.t
                    color: "#ffffff"
                    font.pixelSize: 15 * root.u
                    font.weight: Font.Medium
                }
            }
        }
    }

    LockExtras {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 44 * root.u
        width: root.width * 0.4
        kit: root.kit
        colour: Qt.rgba(1, 1, 1, 0.82)
        family: Appearance.fontFamily.body
        size: 16 * root.u
        info: false
        // the battery/network chips already sit bottom right
        visible: root.kit.mediaLine !== "" || root.kit.weatherLine !== ""
    }
}
