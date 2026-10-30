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
    readonly property color colour: Colours.alpha(Colours.frameBase, root.op)
    // Inside its own group the frame is drawn solid and the group as a whole
    // takes FRAME OPACITY: pieces that overlap (the island's home, the
    // notifications' tab) never show a darker seam.
    readonly property real op: Math.max(0.2, Math.min(1, Config.bar.frameOpacity))
    readonly property color solid: Colours.alpha(Colours.frameBase, 1)

    readonly property real band: root.strip > 0 ? Math.max(0, root.fw + (root.strip - root.fw) * root.reveal) : 0

    // ── the island's home (MODULES → DYNAMIC ISLAND → PART OF THE FRAME): a
    //  soft swell of the frame itself where the docked island rests, on the
    //  frame's inner edge, flaring in and out in S-curves. The island grows
    //  out of it. `bumpEdge` "" = none; `bumpAt` = its middle along the edge.
    property string bumpEdge: ""
    property real bumpAt: 0
    readonly property real bumpLen: root.bumpEdge === "top" ? 168 : 124
    readonly property real bumpDepth: Math.max(6, Math.min(12, Math.round(root.fw * 0.75 + 2)))
    readonly property real bumpFlare: 30

    // The swell as an SVG path in screen coordinates, drawn for the top edge
    // in (u along, v into the desktop) and turned onto the side edges. Only
    // cubic curves, so mirroring needs no arc flags. `part`: "fill" (with a
    // lip into the band), "line" (the outline, open), "cover" (a thin strip
    // that hides the frame's straight outline under the swell's foot).
    function bumpPath(part: string): string {
        const e = root.bumpEdge;
        if (e === "" || root.width <= 0)
            return "";
        const H = root.bumpDepth;
        const L = root.bumpLen;
        const k = Math.min(root.bumpFlare, L / 2 - 6);
        const c = root.bumpAt;
        const base = e === "top" ? root.iy : (e === "left" ? root.ix : root.ix + root.iw);
        const P = (u, v) => {
            if (e === "top")
                return `${(c + u).toFixed(2)},${(base + v).toFixed(2)}`;
            if (e === "left")
                return `${(base + v).toFixed(2)},${(c + u).toFixed(2)}`;
            return `${(base - v).toFixed(2)},${(c + u).toFixed(2)}`;
        };
        const a = -L / 2;
        const b = L / 2;
        if (part === "cover")
            return `M ${P(a, -1.6)} L ${P(b, -1.6)} L ${P(b, 2.2)} L ${P(a, 2.2)} Z`;
        const curve = ` C ${P(a + k * 0.55, 0)} ${P(a + k * 0.45, H)} ${P(a + k, H)} L ${P(b - k, H)} C ${P(b - k * 0.45, H)} ${P(b - k * 0.55, 0)} ${P(b, 0)}`;
        if (part === "line")
            return `M ${P(a, 0)}` + curve;
        return `M ${P(a, -1.5)} L ${P(a, 0)}` + curve + ` L ${P(b, -1.5)} Z`;
    }

    // ── NOTIFICATIONS → IN THE FRAME: a tab of the frame itself that the
    //  popups sit in — grown out of a corner of the desktop, or out of the
    //  middle of its top or bottom edge — whose sides flare into the frame in
    //  concave curves. It reaches into the frame's band, so frame and tab
    //  meet without an edge of their own. `tabPos` "" = none; "top-right" …
    //  "bottom-centre" as NOTIFICATIONS → POSITION says.
    property string tabPos: ""
    property real tabW: 0
    property real tabH: 0
    readonly property bool tabOn: root.tabPos !== "" && root.tabH > 0.5 && root.tabW > 1

    // The notification centre's drawer (NOTIFICATIONS → THE CENTRE TOO): the
    // frame's side band grown thick, the whole height of the desktop, its
    // edge flowing into the top and bottom of the frame in quarter curves —
    // "side-right" / "side-left", `drawerW` = how far it is out.
    property string drawerPos: ""
    property real drawerW: 0
    property real drawerH: 0

    // the cubic that draws a quarter circle
    readonly property real kq: 0.5523

    function f2(n: real): string {
        return n.toFixed(2);
    }

    // The desktop's window: what FRAME OUTLINE strokes.
    function holePath(): string {
        const r = Math.max(0, Math.min(root.rr, root.iw / 2, root.ih / 2));
        const k = root.kq;
        const L = root.ix, T = root.iy, R = root.ix + root.iw, B = root.iy + root.ih;
        const P = (x, y) => `${root.f2(x)},${root.f2(y)}`;
        let p = `M ${P(L + r, T)} C ${P(L + r - k * r, T)} ${P(L, T + r - k * r)} ${P(L, T + r)}`;
        p += ` L ${P(L, B - r)} C ${P(L, B - r + k * r)} ${P(L + r - k * r, B)} ${P(L + r, B)}`;
        p += ` L ${P(R - r, B)} C ${P(R - r + k * r, B)} ${P(R, B - r + k * r)} ${P(R, B - r)}`;
        p += ` L ${P(R, T + r)} C ${P(R, T + r - k * r)} ${P(R - r + k * r, T)} ${P(R - r, T)} Z`;
        return p;
    }

    // The tab, built in "tab space" — u along the edge away from the corner,
    // v into the desktop — and written backwards when the mapping mirrors it
    // once, so it always runs clockwise on the screen.
    function tabPath(): string {
        return root.tabShape(root.tabPos, root.tabW, root.tabH);
    }

    function drawerPath(): string {
        return root.tabShape(root.drawerPos, root.drawerW, root.drawerH);
    }

    function tabShape(pos: string, wantW: real, wantH: real): string {
        if (pos === "" || wantH <= 0.5 || wantW <= 1)
            return "";
        if (pos.startsWith("side-"))
            return root.sideShape(pos === "side-right", wantW);
        const top = !pos.startsWith("bottom");
        const centre = pos.endsWith("centre");
        const right = pos.endsWith("right");
        const L = root.ix, T = root.iy, R = root.ix + root.iw, B = root.iy + root.ih;
        const th = Math.min(wantH, root.ih - 2);
        const tw = Math.min(wantW, root.iw - 2);
        const k = root.kq;
        // the convex corners inside, and the concave flares into the frame
        const c = Math.max(0, Math.min(Math.max(8, root.rr), th / 2, tw / 2));
        const f = Math.max(0, Math.min(Math.max(10, root.rr), th / 2, centre ? 40 : th));
        const e = Math.max(root.inset("top"), root.inset("bottom"), root.inset("left"), root.inset("right")) + 2;
        const sy = top ? 1 : -1;
        const Ay = top ? T : B;
        // u, v → the screen
        let X;
        let sx;
        if (centre) {
            const cx = L + root.iw / 2;
            sx = 1;
            X = u => cx + u;
        } else {
            sx = right ? 1 : -1;
            const Ax = right ? R : L;
            X = u => Ax - sx * u;
        }
        const Q = (u, v) => [X(u), Ay + sy * v];
        // the segments: [start, then {c1, c2, p} or {p}]
        let pts;
        if (centre) {
            const a = -tw / 2, b = tw / 2;
            pts = [Q(a - f, -e), {
                    p: Q(b + f, -e)
                }, {
                    p: Q(b + f, 0)
                }, {
                    c1: Q(b + f - k * f, 0),
                    c2: Q(b, f - k * f),
                    p: Q(b, f)
                }, {
                    p: Q(b, th - c)
                }, {
                    c1: Q(b, th - c + k * c),
                    c2: Q(b - c + k * c, th),
                    p: Q(b - c, th)
                }, {
                    p: Q(a + c, th)
                }, {
                    c1: Q(a + c - k * c, th),
                    c2: Q(a, th - c + k * c),
                    p: Q(a, th - c)
                }, {
                    p: Q(a, f)
                }, {
                    c1: Q(a, f - k * f),
                    c2: Q(a - f + k * f, 0),
                    p: Q(a - f, 0)
                }];
        } else {
            pts = [Q(tw + f, -e), {
                    p: Q(-e, -e)
                }, {
                    p: Q(-e, th + f)
                }, {
                    p: Q(0, th + f)
                }, {
                    c1: Q(0, th + f - k * f),
                    c2: Q(f - k * f, th),
                    p: Q(f, th)
                }, {
                    p: Q(tw - c, th)
                }, {
                    c1: Q(tw - c + k * c, th),
                    c2: Q(tw, th - c + k * c),
                    p: Q(tw, th - c)
                }, {
                    p: Q(tw, f)
                }, {
                    c1: Q(tw, f - k * f),
                    c2: Q(tw + f - k * f, 0),
                    p: Q(tw + f, 0)
                }];
        }
        // one mirror turns the path round: write it backwards
        if (sx * sy < 0) {
            const rev = [pts[pts.length - 1].p];
            for (let i = pts.length - 1; i >= 1; i--) {
                const seg = pts[i];
                const to = i - 1 === 0 ? pts[0] : pts[i - 1].p;
                rev.push(seg.c1 ? {
                    c1: seg.c2,
                    c2: seg.c1,
                    p: to
                } : {
                    p: to
                });
            }
            pts = rev;
        }
        const P = q => `${root.f2(q[0])},${root.f2(q[1])}`;
        let out = `M ${P(pts[0])}`;
        for (let i = 1; i < pts.length; i++) {
            const seg = pts[i];
            out += seg.c1 ? ` C ${P(seg.c1)} ${P(seg.c2)} ${P(seg.p)}` : ` L ${P(seg.p)}`;
        }
        return out + " Z";
    }

    // A side drawer, in "side space": u in from the side edge, y down the
    // screen. Its flares give the desktop round corners where they meet it,
    // so they grow with the drawer (a sliver of drawer, a sliver of curve).
    function sideShape(right: bool, wantW: real): string {
        const L = root.ix, T = root.iy, R = root.ix + root.iw, B = root.iy + root.ih;
        const tw = Math.min(wantW, root.iw - 2);
        const k = root.kq;
        const f = Math.max(0, Math.min(Math.max(10, root.rr), tw, root.ih / 4));
        const e = Math.max(root.inset("top"), root.inset("bottom"), root.inset("left"), root.inset("right")) + 2;
        const Q = (u, y) => [right ? R - u : L + u, y];
        let pts = [Q(tw + f, T - e), {
                p: Q(-e, T - e)
            }, {
                p: Q(-e, B + e)
            }, {
                p: Q(tw + f, B + e)
            }, {
                p: Q(tw + f, B)
            }, {
                c1: Q(tw + f - k * f, B),
                c2: Q(tw, B - f + k * f),
                p: Q(tw, B - f)
            }, {
                p: Q(tw, T + f)
            }, {
                c1: Q(tw, T + f - k * f),
                c2: Q(tw + f - k * f, T),
                p: Q(tw + f, T)
            }];
        // the left side mirrors it once: write it backwards (clockwise again)
        if (!right) {
            const rev = [pts[pts.length - 1].p];
            for (let i = pts.length - 1; i >= 1; i--) {
                const seg = pts[i];
                const to = i - 1 === 0 ? pts[0] : pts[i - 1].p;
                rev.push(seg.c1 ? {
                    c1: seg.c2,
                    c2: seg.c1,
                    p: to
                } : {
                    p: to
                });
            }
            pts = rev;
        }
        const P = q => `${root.f2(q[0])},${root.f2(q[1])}`;
        let out = `M ${P(pts[0])}`;
        for (let i = 1; i < pts.length; i++) {
            const seg = pts[i];
            out += seg.c1 ? ` C ${P(seg.c1)} ${P(seg.c2)} ${P(seg.p)}` : ` L ${P(seg.p)}`;
        }
        return out + " Z";
    }

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
                opacity: root.op
                layer.enabled: Config.bar.frameShadow || root.op < 0.999
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.55)
                    shadowBlur: 0.7
                    blurMax: 32
                    shadowHorizontalOffset: 0
                    shadowVerticalOffset: 0
                }

                // the island's home, inside the shadow too
                Shape {
                    anchors.fill: parent
                    visible: root.bumpEdge !== ""
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.solid
                        strokeColor: "transparent"
                        strokeWidth: 0

                        PathSvg {
                            path: root.bumpPath("fill")
                        }
                    }
                }

                // FRAME OUTLINE: a hairline of accent round the desktop —
                // and round the notifications' tab. Drawn twice as wide
                // UNDER the frame, which covers its outer half and every
                // stretch the tab has grown over.
                Shape {
                    anchors.fill: parent
                    visible: Config.bar.frameOutline
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: Colours.alpha(Colours.accent, 0.5)
                        strokeWidth: 3

                        PathSvg {
                            path: root.holePath() + " " + root.tabPath() + " " + root.drawerPath()
                        }
                    }
                }

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer

                    ShapePath {
                        fillColor: root.solid
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

                    // the notifications' tab
                    ShapePath {
                        fillColor: root.solid
                        strokeColor: "transparent"
                        strokeWidth: 0

                        PathSvg {
                            path: root.tabPath()
                        }
                    }

                    // the centre's drawer
                    ShapePath {
                        fillColor: root.solid
                        strokeColor: "transparent"
                        strokeWidth: 0

                        PathSvg {
                            path: root.drawerPath()
                        }
                    }
                }
            }

            // …and round the island's home: the straight line under the
            // swell's foot is covered, the outline bends over the swell.
            Shape {
                anchors.fill: parent
                visible: root.bumpEdge !== "" && Config.bar.frameOutline
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: root.colour
                    strokeColor: "transparent"
                    strokeWidth: 0

                    PathSvg {
                        path: root.bumpPath("cover")
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Colours.alpha(Colours.accent, 0.5)
                    strokeWidth: 1.5

                    PathSvg {
                        path: root.bumpPath("line")
                    }
                }
            }
        }
    }
}
