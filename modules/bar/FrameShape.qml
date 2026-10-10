//  VELVET  ·  modules/bar/FrameShape.qml
//  What the SCREEN FRAME draws, as a plain item (ScreenFrame.qml puts it
//  on its layer; a test can render it on its own).
//
//  The frame is the space between the screen's edge and a rounded window
//  onto the desktop. On the bar's edge that window starts where the bar
//  ends — and with a bar that hides until you reach for it, the band there
//  grows with the bar as it slides out (`reveal`), so the bar comes out of
//  the frame instead of sliding over it. That band is BarWindow's to draw
//  (in the frame's colour, under the bar); the frame, on the layer above,
//  leaves it out so it can never cover the bar.
import qs.config
import qs.services
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: root

    // Which edge a bar lives on, how deep its strip is (thickness + margin;
    // 0 = no bar on an edge) and how far it is out right now: a pinned bar
    // always (1), a hover bar only while you reach for it — the band on its
    // edge grows from the frame's width to the strip as it comes out, and
    // the desktop's rounded corners move with it.
    property string edge: Config.bar.position
    property int strip: 0
    property real reveal: 1
    // (kept for old callers: the band is BarWindow's now, connected or not)
    property bool joined: false
    readonly property int fw: Math.max(0, Config.bar.frameWidth)
    readonly property int rr: Math.max(0, Config.bar.frameRounding)
    readonly property color colour: Colours.alpha(Colours.frameBase, Math.max(0.2, Math.min(1, Config.bar.frameOpacity)))

    readonly property real band: root.strip > 0 ? Math.max(0, root.fw + (root.strip - root.fw) * root.reveal) : 0

    function inset(side: string): real {
        return side === root.edge && root.strip > 0 ? root.band : root.fw;
    }

    readonly property int ox: 0
    readonly property int oy: 0
    readonly property int ow: root.width
    readonly property int oh: root.height

    readonly property real ix: root.inset("left")
    readonly property real iy: root.inset("top")
    readonly property real iw: root.width - root.inset("left") - root.inset("right")
    readonly property real ih: root.height - root.inset("top") - root.inset("bottom")

    // The frame sits ABOVE the windows and above the bar (both on the top
    // layer, the frame mapped later), so it never paints the bar's band:
    // BarWindow draws that band itself, under its modules, in the frame's
    // colour. Two pixels of overlap keep the frame's own outline along the
    // desktop's edge whole.
    readonly property bool leaveStrip: root.strip > 0
    readonly property real lip: Math.max(0, root.band - 2)
    readonly property real keepX: root.leaveStrip && root.edge === "left" ? root.lip : 0
    readonly property real keepY: root.leaveStrip && root.edge === "top" ? root.lip : 0
    readonly property real keepW: root.width - (root.leaveStrip && (root.edge === "left" || root.edge === "right") ? root.lip : 0)
    readonly property real keepH: root.height - (root.leaveStrip && (root.edge === "top" || root.edge === "bottom") ? root.lip : 0)

    Item {
        id: keep

        x: root.keepX
        y: root.keepY
        width: root.keepW
        height: root.keepH
        clip: root.leaveStrip

        Item {
            x: -keep.x
            y: -keep.y
            width: root.width
            height: root.height

            // FRAME SHADOW: the frame casts a soft shadow inwards, onto the desktop.
            Item {
                anchors.fill: parent
                layer.enabled: Config.bar.frameShadow
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.55)
                    shadowBlur: 0.7
                    blurMax: 32
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.colour
                        strokeColor: "transparent"
                        strokeWidth: 0
                        fillRule: ShapePath.OddEvenFill

                        PathRectangle {
                            x: root.ox
                            y: root.oy
                            width: root.ow
                            height: root.oh
                        }
                        PathRectangle {
                            x: root.ix
                            y: root.iy
                            width: root.iw
                            height: root.ih
                            radius: root.rr
                        }
                    }
                }
            }

            // FRAME OUTLINE: a hairline of accent round the desktop.
            Shape {
                anchors.fill: parent
                visible: Config.bar.frameOutline
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colours.alpha(Colours.accent, 0.5)
                    strokeWidth: 1.5

                    PathRectangle {
                        x: root.ix
                        y: root.iy
                        width: root.iw
                        height: root.ih
                        radius: root.rr
                    }
                }
            }
        }
    }
}
