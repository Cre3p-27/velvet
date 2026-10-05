//  VELVET  ·  modules/osd/Toasts.qml
//  Where Toast.show() lands. Stacks from the bottom, each one timing itself
//  out, hovering pauses the clock so you can actually finish reading.
import qs.config
import qs.services
import qs.components
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    screen: Hypr.focusedScreen
    visible: Toast.items.length > 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "velvet-toast"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: Math.max(1, stack.implicitHeight + 40)

    mask: Region {
        item: stack
    }

    Column {
        id: stack

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26
        spacing: Appearance.spacing.small

        Repeater {
            // ScriptModel keeps each card alive across list changes: a plain
            // array rebuilt every card (and restarted its timer) on each new one.
            model: ScriptModel {
                values: Toast.items
                objectProp: "id"
            }

            Item {
                id: toast

                required property var modelData

                readonly property color tint: {
                    switch (toast.modelData.kind) {
                    case "ok":
                        return Colours.success;
                    case "warn":
                        return Colours.warning;
                    case "error":
                        return Colours.danger;
                    default:
                        return Colours.accent;
                    }
                }

                implicitWidth: Math.min(root.width * 0.6, label.implicitWidth + 108)
                implicitHeight: Math.max(56, label.implicitHeight + 30)

                // Arrives from below with a little overshoot, leaves quietly.
                property bool shown: false
                Component.onCompleted: shown = true

                opacity: shown ? 1 : 0
                scale: shown ? 1 : 0.9

                transform: Translate {
                    y: toast.shown ? 0 : 26

                    Behavior on y {
                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.6
                        }
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutBack
                    }
                }

                Slash {
                    anchors.fill: parent
                    shear: Appearance.skew
                    color: Colours.alpha(Colours.surfaceHigh, 0.97)
                    borderColor: toast.tint
                    borderWidth: 3
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: 5
                    height: parent.height * 0.5
                    radius: 2.5
                    color: toast.tint
                }

                P5Text {
                    id: label

                    anchors.left: parent.left
                    anchors.leftMargin: 38
                    anchors.right: parent.right
                    anchors.rightMargin: 44
                    anchors.verticalCenter: parent.verticalCenter
                    text: toast.modelData.text
                    color: Colours.ink
                    font.pixelSize: Appearance.font.size.normal
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    name: "close"
                    color: area.containsMouse ? Colours.danger : Colours.alpha(Colours.inkDim, 0.7)
                    font.pixelSize: Appearance.font.size.normal
                }

                // Hovering holds it open — a message you are still reading
                // should not vanish mid-sentence.
                Timer {
                    running: !area.containsMouse
                    interval: toast.modelData.ms
                    onTriggered: Toast.dismiss(toast.modelData.id)
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sfx.close();
                        Toast.dismiss(toast.modelData.id);
                    }
                }
            }
        }
    }
}
