//  VELVET  ·  components/Slash.qml
//  The one card primitive — every card, chip, tab and button in the overlay is
//  one of these. In the house look it is a sheared rectangle (the single most
//  Persona-shaped thing there is); VISUALS → CARD SHAPE turns it into a
//  rounded plate, a notched HUD panel, a pixel sprite, a bracket frame …
//  and adds an outline, a hard offset shadow, a soft shadow or a glow, so one
//  change re-dresses the whole shell.
import qs.config
import qs.services
import QtQuick
import QtQuick.Shapes
import "shapes.js" as Shapes

Item {
    id: root

    // Degrees of horizontal shear. Positive leans the top edge right.
    property real shear: Appearance.skew
    property color color: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0
    // Clips the leaning corners back inside the item's own box, so a row of
    // slashes still aligns to a normal grid.
    property bool contain: true

    // The vibe. A caller may override any of these (the LOOKS page draws one
    // card per vibe); by default they follow the settings.
    property string shape: Appearance.shape
    // Thin things (a slider's track, a gauge) get a thinner outline and no
    // cast shadow: the same weight on a 6 px track is a black smear.
    property real outlineWidth: Math.min(Config.appearance.outline, Math.max(1, root.height / 5))
    property color outlineColour: Colours.edge
    property string shadowKind: root.height < 14 ? "none" : Config.appearance.shadow
    property real shadowSize: Math.min(Config.appearance.shadowSize * Appearance.depth, root.height / 3.2)
    property bool flat: false
    // Round corners: -1 sizes them to the box, otherwise exactly this many px.
    property real cornerRadius: -1

    // Corner marks need room: on a small chip or a toggle they are noise.
    readonly property string _shape: root.shape === "bracket" && root.height < 28 ? "square" : root.shape

    readonly property real _off: Math.tan(shear * Math.PI / 180) * height
    readonly property real _unit: Math.max(2, Math.min(height / 7, 4))
    readonly property bool _bare: root.flat || root.width < 2 || root.height < 2
    // A card that is see-through at rest (a tab nobody points at) casts and
    // outlines nothing until it is filled or edged.
    readonly property real _vis: Math.min(1, Math.max(root.color.a, root.borderWidth > 0 ? root.borderColor.a : 0) * 3)
    // …and a shadow needs a card that hides it: a half-filled card would
    // show the block right through itself.
    readonly property real _cast: Math.max(0, Math.min(1, (root.color.a - 0.5) * 2.5))

    // Corner marks on a card of their own colour would vanish: use the ink.
    readonly property color _markColour: Colours.contrast(root.outlineColour, root.color.a > 0.5 ? root.color : Colours.surface) < 1.6 ? Colours.on(root.color) : root.outlineColour

    // neumorphism's two shadows: dark on a light ground, black-and-white on a dark one
    readonly property color _neuDark: Colours.light ? Qt.rgba(0.36, 0.42, 0.58, 0.3) : Qt.rgba(0, 0, 0, 0.5)
    readonly property color _neuLight: Colours.light ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(1, 1, 1, 0.07)

    function pts(list: var): var {
        return list.map(p => Qt.point(p.x, p.y));
    }

    readonly property var _detail: ({
            off: root._off,
            contain: root.contain,
            radius: root.cornerRadius >= 0 ? root.cornerRadius : Math.min(root.height * 0.28, 14),
            cut: Math.min(root.height * 0.32, 12),
            step: root._unit
        })

    readonly property var outline: root.pts(Shapes.outline(root._shape, root.width, root.height, root._detail))

    // ── what the card casts, under it
    Loader {
        anchors.fill: parent
        opacity: root._cast
        active: !root._bare && root._cast > 0.02 && root.shadowKind !== "none" && root.shadowSize > 0 && root.width > 2

        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer
            asynchronous: false

            // an offset block, the colour of the shadow
            ShapePath {
                fillColor: root.shadowKind === "hard" ? Colours.shadowHard : "transparent"
                strokeColor: root.shadowKind === "hard" ? Colours.shadowHard : "transparent"
                strokeWidth: root.shadowKind === "hard" ? 1 : 0
                joinStyle: ShapePath.MiterJoin

                PathPolyline {
                    path: root.pts(Shapes.shifted(Shapes.outline(root._shape, root.width, root.height, root._detail), root.shadowSize, root.shadowSize))
                }
            }

            // soft: three wide strokes fading outwards
            ShapePath {
                fillColor: root.shadowKind === "soft" ? Qt.rgba(0, 0, 0, 0.1) : "transparent"
                strokeColor: root.shadowKind === "soft" ? Qt.rgba(0, 0, 0, 0.06) : "transparent"
                strokeWidth: root.shadowSize * 1.6
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.pts(Shapes.shifted(Shapes.outline(root._shape, root.width, root.height, root._detail), 0, root.shadowSize * 0.35))
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.shadowKind === "soft" ? Qt.rgba(0, 0, 0, 0.09) : "transparent"
                strokeWidth: root.shadowSize * 0.8
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.pts(Shapes.shifted(Shapes.outline(root._shape, root.width, root.height, root._detail), 0, root.shadowSize * 0.2))
                }
            }

            // neumorphism: a dark soft shadow down-right and a light one up-left,
            // so the card looks pushed out of (or, as a pit, into) its own ground
            ShapePath {
                fillColor: root.shadowKind === "neu" ? root._neuDark : "transparent"
                strokeColor: root.shadowKind === "neu" ? Qt.rgba(root._neuDark.r, root._neuDark.g, root._neuDark.b, root._neuDark.a * 0.55) : "transparent"
                strokeWidth: root.shadowSize * 1.5
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.pts(Shapes.shifted(Shapes.outline(root._shape, root.width, root.height, root._detail), root.shadowSize * 0.75 * Appearance.lightSign.x, root.shadowSize * 0.75 * Appearance.lightSign.y))
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.shadowKind === "neu" ? Qt.rgba(root._neuDark.r, root._neuDark.g, root._neuDark.b, root._neuDark.a * 0.5) : "transparent"
                strokeWidth: root.shadowSize * 0.7
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.pts(Shapes.shifted(Shapes.outline(root._shape, root.width, root.height, root._detail), root.shadowSize * 0.5 * Appearance.lightSign.x, root.shadowSize * 0.5 * Appearance.lightSign.y))
                }
            }
            ShapePath {
                fillColor: root.shadowKind === "neu" ? root._neuLight : "transparent"
                strokeColor: root.shadowKind === "neu" ? Qt.rgba(root._neuLight.r, root._neuLight.g, root._neuLight.b, root._neuLight.a * 0.6) : "transparent"
                strokeWidth: root.shadowSize * 1.5
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.pts(Shapes.shifted(Shapes.outline(root._shape, root.width, root.height, root._detail), -root.shadowSize * 0.75 * Appearance.lightSign.x, -root.shadowSize * 0.75 * Appearance.lightSign.y))
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.shadowKind === "neu" ? Qt.rgba(root._neuLight.r, root._neuLight.g, root._neuLight.b, root._neuLight.a * 0.5) : "transparent"
                strokeWidth: root.shadowSize * 0.7
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.pts(Shapes.shifted(Shapes.outline(root._shape, root.width, root.height, root._detail), -root.shadowSize * 0.5 * Appearance.lightSign.x, -root.shadowSize * 0.5 * Appearance.lightSign.y))
                }
            }

            // claymorphism: a fat, tinted shadow straight below, like a lump on a table
            ShapePath {
                fillColor: root.shadowKind === "clay" ? Colours.alpha(Colours.clay, 0.2) : "transparent"
                strokeColor: root.shadowKind === "clay" ? Colours.alpha(Colours.clay, 0.1) : "transparent"
                strokeWidth: root.shadowSize * 1.7
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.pts(Shapes.shifted(Shapes.outline(root._shape, root.width, root.height, root._detail), 0, root.shadowSize * 0.9))
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.shadowKind === "clay" ? Colours.alpha(Colours.clay, 0.12) : "transparent"
                strokeWidth: root.shadowSize * 0.8
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.pts(Shapes.shifted(Shapes.outline(root._shape, root.width, root.height, root._detail), 0, root.shadowSize * 0.5))
                }
            }

            // glow: the same wide strokes, in the accent
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.shadowKind === "glow" ? Colours.alpha(Colours.glow, 0.1) : "transparent"
                strokeWidth: root.shadowSize * 1.8
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.outline
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.shadowKind === "glow" ? Colours.alpha(Colours.glow, 0.16) : "transparent"
                strokeWidth: root.shadowSize * 1.0
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.outline
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.shadowKind === "glow" ? Colours.alpha(Colours.glow, 0.3) : "transparent"
                strokeWidth: root.shadowSize * 0.4
                joinStyle: ShapePath.RoundJoin

                PathPolyline {
                    path: root.outline
                }
            }
        }
    }

    // ── the card itself
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {
            fillColor: root.color
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap

            PathPolyline {
                path: root.outline
            }
        }
    }

    // ── clay: the lit top and the shaded belly of a lump of modelling clay
    Loader {
        anchors.fill: parent
        active: !root._bare && root.shadowKind === "clay" && root.color.a > 0.5 && root.height >= 20

        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer
            asynchronous: false

            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: 0
                    y2: root.height

                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.5) }
                    GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0.0) }
                    GradientStop { position: 0.75; color: Qt.rgba(0, 0, 0, 0.0) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.14) }
                }

                PathPolyline {
                    path: root.outline
                }
            }
        }
    }

    // ── a bevel (the old window system): light on the top-left, dark on the
    // bottom-right, twice — the card stands up off the page.
    Loader {
        anchors.fill: parent
        opacity: root._vis
        active: !root._bare && root._shape === "bevel" && root._vis > 0.3 && root.width > 5 && root.height > 5

        sourceComponent: Item {
            readonly property color hi: Qt.rgba(1, 1, 1, 0.95)
            readonly property color hi2: Qt.rgba(1, 1, 1, 0.45)
            readonly property color lo: Colours.alpha(Colours.ink0, 0.92)
            readonly property color lo2: Colours.alpha(Colours.ink, 0.38)

            Rectangle { width: parent.width - 1; height: 1; color: parent.hi }
            Rectangle { width: 1; height: parent.height - 1; color: parent.hi }
            Rectangle { x: 1; y: 1; width: parent.width - 3; height: 1; color: parent.hi2 }
            Rectangle { x: 1; y: 1; width: 1; height: parent.height - 3; color: parent.hi2 }
            Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: parent.lo }
            Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: parent.lo }
            Rectangle { x: 1; y: parent.height - 2; width: parent.width - 2; height: 1; color: parent.lo2 }
            Rectangle { x: parent.width - 2; y: 1; width: 1; height: parent.height - 2; color: parent.lo2 }
        }
    }

    // ── the outline a vibe draws over every card, and the corner marks of a bracket frame
    Loader {
        anchors.fill: parent
        opacity: root._vis
        active: !root._bare && root._vis > 0.02 && (root.outlineWidth > 0 || root._shape === "bracket") && root.width > 2

        sourceComponent: Shape {
            preferredRendererType: Shape.CurveRenderer
            asynchronous: false

            ShapePath {
                fillColor: "transparent"
                strokeColor: root._shape === "bracket" ? Colours.alpha(root.outlineColour, 0.35) : root.outlineColour
                strokeWidth: root._shape === "bracket" ? Math.max(1, root.outlineWidth * 0.5) : root.outlineWidth
                joinStyle: ShapePath.MiterJoin

                PathPolyline {
                    path: root.outline
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root._shape === "bracket" ? root._markColour : "transparent"
                strokeWidth: Math.max(1.5, root.outlineWidth)
                joinStyle: ShapePath.MiterJoin
                capStyle: ShapePath.FlatCap

                PathMultiline {
                    paths: Shapes.brackets(root.width, root.height, Math.min(root.height * 0.38, 14), Math.max(1.5, root.outlineWidth) / 2).map(l => root.pts(l))
                }
            }
        }
    }
}
