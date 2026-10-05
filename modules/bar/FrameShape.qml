//  VELVET  ·  modules/bar/FrameShape.qml
//  What the SCREEN FRAME draws, as a plain item (ScreenFrame.qml puts it
//  on its layer; a test can render it on its own).
//
//  The frame is the space between the screen's edge and a rounded window
//  onto the desktop. On the bar's edge that window starts where the bar
//  ends. CONNECTED, bar and frame are one surface: the frame's shape
//  takes in the bar's strip (its corners round off right where the bar
//  stops, its shadow falls along the bar too) and the bar paints the strip
//  itself in the frame's colour — the frame, on the layer above the
//  windows, leaves the strip out so it can never cover the bar.
import qs.config
import qs.services
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Item {
    id: root

    // Which edge the bar holds (""/none), how deep its strip is, and
    // whether the frame paints that strip too.
    property string edge: Config.bar.position
    property int strip: 0
    property bool joined: false
    readonly property int fw: Math.max(0, Config.bar.frameWidth)
    readonly property int rr: Math.max(0, Config.bar.frameRounding)
    readonly property color colour: Colours.alpha(Colours.frameBase, Math.max(0.2, Math.min(1, Config.bar.frameOpacity)))

    function inset(side: string): int {
        return side === root.edge && root.strip > 0 ? root.strip : root.fw;
    }

    // Without CONNECTED the bar's strip stays the bar's to draw.
    readonly property int cut: root.joined ? 0 : root.strip
    readonly property int ox: root.edge === "left" ? root.cut : 0
    readonly property int oy: root.edge === "top" ? root.cut : 0
    readonly property int ow: root.width - (root.edge === "left" || root.edge === "right" ? root.cut : 0)
    readonly property int oh: root.height - (root.edge === "top" || root.edge === "bottom" ? root.cut : 0)

    readonly property real ix: root.inset("left")
    readonly property real iy: root.inset("top")
    readonly property real iw: root.width - root.inset("left") - root.inset("right")
    readonly property real ih: root.height - root.inset("top") - root.inset("bottom")

    // The frame sits ABOVE the windows now (ScreenFrame is on the top
    // layer), so it must never paint over the bar: it keeps its whole shape
    // — and the shadow it casts along the bar's inner edge — but the bar's
    // own strip is left out. CONNECTED, the bar paints that strip itself in
    // the frame's colour, so the two still meet without a seam.
    readonly property bool leaveStrip: root.joined && root.strip > 0
    readonly property int keepX: root.leaveStrip && root.edge === "left" ? root.strip : 0
    readonly property int keepY: root.leaveStrip && root.edge === "top" ? root.strip : 0
    readonly property int keepW: root.width - (root.leaveStrip && (root.edge === "left" || root.edge === "right") ? root.strip : 0)
    readonly property int keepH: root.height - (root.leaveStrip && (root.edge === "top" || root.edge === "bottom") ? root.strip : 0)

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
