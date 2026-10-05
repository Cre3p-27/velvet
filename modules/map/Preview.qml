//  VELVET  ·  modules/map/Preview.qml
//  One window's own pixels.
//
//  Loaded by PATH, never as a type, for the same reason the MPRIS and PAM
//  bridges are: ScreencopyView belongs to a Quickshell build option, and a
//  file that names a type the build does not have fails to compile — which
//  would take the window map down with it, and shell.qml down with that. Here,
//  a missing type costs previews and nothing else.
import Quickshell.Wayland
import QtQuick

Item {
    id: root

    property var source: null
    property bool live: false

    readonly property bool hasContent: view.hasContent

    ScreencopyView {
        id: view

        anchors.fill: parent
        captureSource: root.source
        live: root.live
        paintCursor: false
    }
}
