//  VELVET  ·  components/Backdrop.qml
//  The pattern a vibe lays under its surfaces — VISUALS → BACKDROP. It
//  replaces the Persona speed lines and print dots in the settings, the
//  launcher and the home screen. "persona" draws nothing here: the house
//  look keeps its own rays.
import qs.config
import qs.services
import QtQuick
import QtQuick.Shapes

Item {
    id: root

    property string kind: Config.appearance.backdrop
    property color colour: Colours.ink
    // How loud the pattern is, 0..1 (a few percent is plenty).
    property real strength: 1.0
    property real step: 48

    enabled: false
    clip: true

    function hex(c: color): string {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return `#${h(c.r)}${h(c.g)}${h(c.b)}`;
    }

    readonly property string ink: root.hex(root.colour)
    readonly property real s: root.step

    readonly property string tile: {
        const st = root.s;
        switch (root.kind) {
        case "grid":
            return `<svg xmlns="http://www.w3.org/2000/svg" width="${st * 4}" height="${st * 4}"><path d="M0 0H${st * 4}M0 ${st}H${st * 4}M0 ${st * 2}H${st * 4}M0 ${st * 3}H${st * 4}M0 0V${st * 4}M${st} 0V${st * 4}M${st * 2} 0V${st * 4}M${st * 3} 0V${st * 4}" stroke="${root.ink}" stroke-opacity="0.07" stroke-width="1" fill="none"/><path d="M0.5 0.5H${st * 4}M0.5 0.5V${st * 4}" stroke="${root.ink}" stroke-opacity="0.16" stroke-width="1" fill="none"/></svg>`;
        case "dots":
            return `<svg xmlns="http://www.w3.org/2000/svg" width="${st / 2}" height="${st / 2}"><circle cx="${st / 4}" cy="${st / 4}" r="1.6" fill="${root.ink}" fill-opacity="0.16"/></svg>`;
        case "checker":
            return `<svg xmlns="http://www.w3.org/2000/svg" width="${st}" height="${st}"><rect width="${st / 2}" height="${st / 2}" fill="${root.ink}" fill-opacity="0.045"/><rect x="${st / 2}" y="${st / 2}" width="${st / 2}" height="${st / 2}" fill="${root.ink}" fill-opacity="0.045"/></svg>`;
        case "ruled":
            return `<svg xmlns="http://www.w3.org/2000/svg" width="${st}" height="${st * 0.6}"><path d="M0 ${st * 0.6 - 0.5}H${st}" stroke="${root.ink}" stroke-opacity="0.12" stroke-width="1" fill="none"/></svg>`;
        case "aurora":
            return "";
        default:
            return "";
        }
    }

    // The aurora's five clouds, in the palette chosen under THIS LOOK → GLASS.
    readonly property var auroraBlobs: {
        const pal = ({
                violet: ["#8b6cff", "#3ee0ff", "#ff6fb5", "#4a90ff", "#c4a7ff"],
                ocean: ["#2f7bff", "#19d3c5", "#7ad7ff", "#1b4fd8", "#9fe9ff"],
                sunset: ["#ff7a59", "#ffb347", "#ff4f8b", "#8a4fff", "#ffd6a5"],
                forest: ["#2bd48a", "#8be04a", "#1aa6a0", "#3a8f5a", "#c6f5a6"],
                mono: ["#ffffff", "#cfd8ff", "#9aa3c7", "#ffffff", "#d7dcf0"]
            })[Config.appearance.auroraPalette] ?? ["#8b6cff", "#3ee0ff", "#ff6fb5", "#4a90ff", "#c4a7ff"];
        return [
            { x: 0.14, y: 0.18, r: 0.6, c: pal[0], a: 0.8 },
            { x: 0.88, y: 0.14, r: 0.5, c: pal[1], a: 0.62 },
            { x: 0.8, y: 0.9, r: 0.6, c: pal[2], a: 0.64 },
            { x: 0.08, y: 0.92, r: 0.5, c: pal[3], a: 0.64 },
            { x: 0.5, y: 0.5, r: 0.38, c: pal[4], a: 0.42 }
        ];
    }

    Image {
        anchors.fill: parent
        visible: root.tile !== ""
        opacity: root.strength * Appearance.pattern
        fillMode: Image.Tile
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
        source: root.tile !== "" ? "data:image/svg+xml;utf8," + encodeURIComponent(root.tile) : ""
        smooth: false
        cache: false
    }

    // The aurora of the glass look: big soft colour clouds for the panes to float over.
    Item {
        anchors.fill: parent
        visible: root.kind === "aurora"
        opacity: Math.min(1, root.strength * Config.appearance.auroraStrength * Math.max(0.35, Appearance.pattern))

        Repeater {
            model: root.auroraBlobs

            Shape {
                id: blob

                required property var modelData

                x: blob.modelData.x * root.width
                y: blob.modelData.y * root.height
                width: 1
                height: 1
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    id: glow

                    readonly property real rr: blob.modelData.r * Math.max(root.width, root.height)
                    readonly property color cc: Qt.color(blob.modelData.c)

                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: 0
                        centerY: 0
                        centerRadius: Math.max(1, glow.rr)
                        focalX: 0
                        focalY: 0
                        GradientStop { position: 0.0; color: Qt.rgba(glow.cc.r, glow.cc.g, glow.cc.b, blob.modelData.a) }
                        GradientStop { position: 0.5; color: Qt.rgba(glow.cc.r, glow.cc.g, glow.cc.b, blob.modelData.a * 0.45) }
                        GradientStop { position: 1.0; color: Qt.rgba(glow.cc.r, glow.cc.g, glow.cc.b, 0) }
                    }
                    PathRectangle {
                        x: -glow.rr
                        y: -glow.rr
                        width: glow.rr * 2
                        height: glow.rr * 2
                    }
                }
            }
        }
    }

    // the notebook's margin rule
    Rectangle {
        visible: root.kind === "ruled"
        x: Math.round(root.width * 0.085)
        width: 2
        height: parent.height
        color: Colours.alpha(Colours.accent, Math.min(1, 0.35 * root.strength * Appearance.pattern))
    }

    // darkened edges
    Rectangle {
        anchors.fill: parent
        visible: root.kind === "vignette"
        opacity: Math.min(1, root.strength * Appearance.pattern)

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: Colours.alpha(Colours.ink0, 0.45)
            }
            GradientStop {
                position: 0.3
                color: "transparent"
            }
            GradientStop {
                position: 0.7
                color: "transparent"
            }
            GradientStop {
                position: 1.0
                color: Colours.alpha(Colours.ink0, 0.55)
            }
        }
    }
}
