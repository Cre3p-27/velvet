//  VELVET  ·  components/WinBox.qml
//  The surfaces of the WINDOWS look: a push button, an input field, a panel,
//  a recessed area — drawn the way the chosen edition drew them. Bevelled
//  grey in 95, Luna in XP, Aero glass in 7, flat in 10, rounded in 11.
//  Children go inside it like in a Rectangle.
import qs.config
import qs.services
import QtQuick

Item {
    id: root

    // button | field | panel | sunken | flat
    property string kind: "button"
    property bool hot: false
    property bool pressed: false
    // keyboard focus / the selected one
    property bool focused: false
    // the default button: accent-filled where the edition does that
    property bool primary: false
    // paints this colour instead of the edition's own fill
    property color fill: "transparent"

    readonly property string v: Appearance.winVer
    readonly property bool fillSet: root.fill.a > 0

    implicitWidth: 80
    implicitHeight: 28

    Loader {
        anchors.fill: parent
        sourceComponent: ({
                "95": c95,
                "xp": cXp,
                "7": c7,
                "10": c10,
                "11": c11
            })[root.v] ?? c11
    }

    // ═════════════════════════════════════════════════════════════ 95
    Component {
        id: c95

        Item {
            readonly property bool sunk: root.kind === "field" || root.kind === "sunken" || root.pressed

            Rectangle {
                anchors.fill: parent
                color: root.fillSet ? root.fill : (root.kind === "field" || root.kind === "sunken" ? WinTheme.field : WinTheme.face)
            }
            // the double bevel
            Rectangle { width: parent.width - 1; height: 1; color: parent.sunk ? "#808080" : "#ffffff"; visible: root.kind !== "flat" }
            Rectangle { width: 1; height: parent.height - 1; color: parent.sunk ? "#808080" : "#ffffff"; visible: root.kind !== "flat" }
            Rectangle { x: 1; y: 1; width: parent.width - 3; height: 1; color: parent.sunk ? "#000000" : "#dfdfdf"; visible: root.kind !== "flat" }
            Rectangle { x: 1; y: 1; width: 1; height: parent.height - 3; color: parent.sunk ? "#000000" : "#dfdfdf"; visible: root.kind !== "flat" }
            Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: parent.sunk ? "#ffffff" : "#000000"; visible: root.kind !== "flat" }
            Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: parent.sunk ? "#ffffff" : "#000000"; visible: root.kind !== "flat" }
            Rectangle { x: 1; y: parent.height - 2; width: parent.width - 2; height: 1; color: parent.sunk ? "#dfdfdf" : "#808080"; visible: root.kind !== "flat" }
            Rectangle { x: parent.width - 2; y: 1; width: 1; height: parent.height - 2; color: parent.sunk ? "#dfdfdf" : "#808080"; visible: root.kind !== "flat" }
            // the default / focused button gets a black frame
            Rectangle {
                anchors.fill: parent
                visible: (root.primary || root.focused) && root.kind === "button"
                color: "transparent"
                border.width: 1
                border.color: "#000000"
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ XP
    Component {
        id: cXp

        Item {
            readonly property bool isButton: root.kind === "button"

            Rectangle {
                anchors.fill: parent
                radius: parent.isButton ? 3 : (root.kind === "panel" ? 4 : 0)
                color: root.fillSet ? root.fill : (root.kind === "field" || root.kind === "sunken" ? "#ffffff" : (root.kind === "panel" ? "#f6f4ea" : "transparent"))
                border.width: root.kind === "flat" ? 0 : 1
                border.color: parent.isButton ? "#003c74" : (root.kind === "panel" ? "#d0d0bf" : "#7f9db9")

                gradient: parent.isButton && !root.fillSet ? btnGrad : null
            }
            Gradient {
                id: btnGrad

                GradientStop {
                    position: 0
                    color: root.pressed ? "#cecbbb" : (root.primary ? "#e4edfd" : "#ffffff")
                }
                GradientStop {
                    position: 0.85
                    color: root.pressed ? "#e3e0d2" : (root.primary ? "#c9dafa" : "#ece9d8")
                }
                GradientStop {
                    position: 1
                    color: root.pressed ? "#f1efe2" : (root.primary ? "#b4cbf4" : "#d6d0c5")
                }
            }
            // the orange glow of a hovered button, the blue of the default one
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 2
                visible: parent.isButton && !root.pressed && (root.hot || root.primary || root.focused)
                color: "transparent"
                border.width: 2
                border.color: root.hot ? "#f9c23c" : "#7ea3ee"
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ 7
    Component {
        id: c7

        Item {
            readonly property bool isButton: root.kind === "button"

            Rectangle {
                anchors.fill: parent
                radius: parent.isButton ? 3 : (root.kind === "panel" ? 3 : 1)
                color: root.fillSet ? root.fill : (root.kind === "field" || root.kind === "sunken" ? "#ffffff" : (root.kind === "panel" ? "#fbfcfe" : "transparent"))
                border.width: root.kind === "flat" ? 0 : 1
                border.color: parent.isButton ? (root.pressed ? "#2c628b" : (root.hot || root.focused ? "#3c7fb1" : "#707070")) : (root.kind === "panel" ? "#d5dfe5" : (root.hot ? "#5794bf" : "#abadb3"))

                gradient: parent.isButton && !root.fillSet ? btnGrad7 : null
            }
            Gradient {
                id: btnGrad7

                GradientStop {
                    position: 0
                    color: root.pressed ? "#c4e5f6" : (root.hot ? "#eaf6fd" : (root.primary ? "#f0f8fe" : "#f2f2f2"))
                }
                GradientStop {
                    position: 0.49
                    color: root.pressed ? "#98d1ef" : (root.hot ? "#d9f0fc" : (root.primary ? "#d6ecfb" : "#ebebeb"))
                }
                GradientStop {
                    position: 0.5
                    color: root.pressed ? "#68b3db" : (root.hot ? "#bee6fd" : (root.primary ? "#bcdff6" : "#dddddd"))
                }
                GradientStop {
                    position: 1
                    color: root.pressed ? "#bee6fd" : (root.hot ? "#a7d9f5" : (root.primary ? "#a3d0ee" : "#cfcfcf"))
                }
            }
            // the inner white line that makes the glass
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: 2
                visible: parent.isButton
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.7)
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ 10
    Component {
        id: c10

        Item {
            readonly property bool isButton: root.kind === "button"

            Rectangle {
                anchors.fill: parent
                color: root.fillSet ? root.fill : (root.kind === "field" || root.kind === "sunken" ? WinTheme.field : (root.kind === "panel" ? WinTheme.card : (root.kind === "button" ? (root.primary ? WinTheme.accent : (root.pressed ? (WinTheme.dark ? "#555555" : "#999999") : (WinTheme.dark ? "#333333" : "#cccccc"))) : "transparent")))
                border.width: root.kind === "flat" || root.kind === "panel" ? 0 : 2
                border.color: root.focused ? WinTheme.accent : (root.hot ? (WinTheme.dark ? "#7a7a7a" : "#7a7a7a") : (root.kind === "button" ? "transparent" : (WinTheme.dark ? "#8a8a8a" : "#7a7a7a")))

                Behavior on color {
                    ColorAnimation {
                        duration: 90
                    }
                }
            }
        }
    }

    // ═════════════════════════════════════════════════════════════ 11
    Component {
        id: c11

        Item {
            readonly property bool isButton: root.kind === "button"

            Rectangle {
                anchors.fill: parent
                radius: root.kind === "panel" ? 8 : 4
                color: root.fillSet ? root.fill : (root.kind === "field" || root.kind === "sunken" ? WinTheme.field : (root.kind === "panel" ? WinTheme.card : (root.kind === "button" ? (root.primary ? (root.pressed ? Qt.darker(WinTheme.accent, 1.15) : (root.hot ? Qt.lighter(WinTheme.accent, 1.1) : WinTheme.accent)) : (WinTheme.dark ? (root.pressed ? "#272727" : (root.hot ? "#363636" : "#2d2d2d")) : (root.pressed ? "#f5f5f5" : (root.hot ? "#f6f6f6" : "#fdfdfd")))) : "transparent")))
                border.width: root.kind === "flat" ? 0 : 1
                border.color: root.focused ? WinTheme.accent : (root.primary ? "transparent" : (WinTheme.dark ? "#3a3a3a" : "#e0e0e0"))

                Behavior on color {
                    ColorAnimation {
                        duration: 110
                    }
                }
            }
            // the darker lower edge of a button / the accent line of a field
            Rectangle {
                x: 4
                y: parent.height - 1
                width: parent.width - 8
                height: root.focused && !parent.isButton ? 2 : 1
                visible: !root.primary && (parent.isButton || root.focused) && root.kind !== "panel"
                color: root.focused ? WinTheme.accent : (WinTheme.dark ? "#1d1d1d" : "#c8c8c8")
            }
        }
    }
}
