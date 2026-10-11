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

    // A bar on an edge (pinned, or hiding until you reach for it) owns that
    // edge's band: BarWindow draws it, as wide as the bar is out, and the
    // frame's inner edge moves with it — a hover bar comes out OF the frame
    // instead of sliding over it. A floating pill leaves the edge to the frame.
    readonly property bool barOnEdge: Config.bar.enabled && Config.bar.style !== "floating"
    readonly property bool barHolds: root.barOnEdge && (Config.bar.persistent || !Config.bar.showOnHover) && !Focus.hidesBar
    property real reveal: root.barHolds || Panels.barOut[root.modelData?.name ?? ""] === true ? 1 : 0

    Behavior on reveal {
        NumberAnimation {
            duration: Appearance.anim.normal
            easing.type: Easing.OutExpo
        }
    }

    // The island's home on the frame (PART OF THE FRAME): where the docked
    // island rests — the middle of the top edge (plus the nudge), or ISLAND
    // HEIGHT on a side edge.
    readonly property bool islandHome: Config.map.enabled && Config.map.island && Config.map.islandFrame
    readonly property real islandAt: Appearance.islandEdge === "top" ? root.width / 2 + Config.map.islandShift : root.height * Math.max(0.05, Math.min(0.95, Config.map.islandEdgeY)) + Config.map.islandShift

    FrameShape {
        anchors.fill: parent
        edge: Config.bar.position
        strip: root.barOnEdge ? Config.bar.thickness + Config.bar.margin : 0
        reveal: root.reveal
        bumpEdge: root.islandHome ? Appearance.islandEdge : ""
        bumpAt: root.islandAt
    }
}
