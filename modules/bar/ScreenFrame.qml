//  VELVET  ·  modules/bar/ScreenFrame.qml
//  TASKBAR → SCREEN FRAME: a thin frame round the whole screen in the
//  bar's own colour, with the desktop's corners rounded inside it — the
//  inspo shells' "the wallpaper sits in a rounded window" look. On the
//  bar's edge the frame simply becomes the bar.
//
//  It lives on the TOP layer, like the bar: above every window and the
//  desktop's own cava, below a fullscreen app (Hyprland draws fullscreen
//  windows over the top layer). It takes no input at all (an empty mask),
//  so what is under it stays clickable, and the window gaps keep tiled
//  windows inside it.
import qs.config
import qs.services
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    color: "transparent"
    WlrLayershell.namespace: "velvet-frame"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Span the whole screen, under the bar's reserved strip too — the
    // frame measures the strip itself below.
    exclusionMode: ExclusionMode.Ignore

    anchors {
        left: true
        right: true
        top: true
        bottom: true
    }

    mask: Region {}

    // The bar holds its edge only while it is pinned; a floating pill or a
    // hidden bar leave that edge to the frame.
    readonly property bool barHolds: Config.bar.enabled && Config.bar.style !== "floating" && (Config.bar.persistent || !Config.bar.showOnHover) && !Focus.hidesBar

    FrameShape {
        anchors.fill: parent
        edge: Config.bar.position
        strip: root.barHolds ? Config.bar.thickness + Config.bar.margin : 0
        joined: root.barHolds && Config.bar.frameConnect
    }
}
