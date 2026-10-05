//  VELVET  ·  components/Plate.qml
//  A drop-in Rectangle for the surfaces of the shell that are not Slash
//  cards (the bar, the island, the launcher, the settings' cards). In the
//  house look it IS a Rectangle; as soon as a vibe asks for a notched, pixel
//  or bracketed plate, an outline or a shadow, it draws itself with the same
//  machinery as Slash, so one dial re-dresses both kinds of surface.
//  Children go inside it like in a Rectangle.
import qs.config
import qs.services
import QtQuick

Item {
    id: root

    property color color: "transparent"
    property real radius: 0
    property alias border: plain.border
    // A caller may switch the vibe off for one plate (a thumbnail frame).
    property bool vibe: true
    // The Rectangle has no tilt: in the house look a plate stays rounded.
    property string shape: Appearance.shape === "slash" ? "round" : Appearance.shape

    readonly property bool decorated: root.vibe && root.height >= 10 && root.width >= 10 && (["notch", "bracket", "pixel", "bevel"].indexOf(root.shape) >= 0 || Config.appearance.outline > 0 || Config.appearance.shadow !== "none")

    Rectangle {
        id: plain

        anchors.fill: parent
        visible: !root.decorated
        color: root.color
        radius: root.radius
        antialiasing: root.antialiasing
    }

    Loader {
        anchors.fill: parent
        active: root.decorated

        sourceComponent: Slash {
            shape: root.shape
            cornerRadius: root.radius
            color: root.color
            // A Rectangle that was never given a border still reports one
            // (1 px, black): that is "no border", not a black line.
            borderColor: plain.border.color
            borderWidth: String(plain.border.color) === "#000000" ? 0 : plain.border.width
        }
    }
}
