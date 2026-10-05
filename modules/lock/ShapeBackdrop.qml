//  VELVET  ·  modules/lock/ShapeBackdrop.qml
//  The lock's background, the punchy Material way: a flat field, and the whole
//  wallpaper shown through one giant centred shape glyph. Click any neutral
//  spot and it thumps; scroll and it changes shape (SETTINGS → LOCK SCREEN
//  → SHAPES CYCLE ON SCROLL turns the cycling off). With BACKGROUND SHAPE →
//  OFF this is the old plain blurred wallpaper.
//
//  The unlock choreography is a HANDOVER, not a fade to grey: as the lock
//  opens (progress 1 → 0), the blur sharpens away, the dim lifts, the glyph
//  lets go — and the bare wallpaper rises to fill the whole screen, drawn
//  exactly the way the desktop draws it (same file, same crop, no dim, no
//  blur). The lock's last painted frame IS the desktop's first one.
//
//  The shape vocabulary is LockGlyph's: circle, arrow, pill, burst,
//  diamond, clam, pentagon — the same glyphs the password field plants
//  as you type, so the whole lock speaks one shape language.
import qs.config
import qs.services
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

Item {
    id: root

    // 0 = handing over to the desktop (glyph gone, blur gone, dim gone, the
    // bare wallpaper fills the screen exactly as the desktop renders it) ·
    // 1 = settled on the lock.
    property real progress: 1

    // The crop the desktop's wallpaper layer uses — the reveal must match
    // it pixel for pixel, whatever WALLPAPER → FILL MODE says.
    readonly property int fill: {
        switch (Config.wallpaper.fillMode) {
        case "fit":
            return Image.PreserveAspectFit;
        case "stretch":
            return Image.Stretch;
        default:
            return Image.PreserveAspectCrop;
        }
    }

    readonly property var shapeNames: ["off", "circle", "arrow", "pill", "burst", "diamond", "clam", "pentagon"]

    function kindOf(name: string): int {
        const i = root.shapeNames.indexOf(name);
        // "off" and anything unrecognised both land on burst — the shape
        // window is only visible when it is enabled anyway.
        return i <= 0 ? 3 : i - 1;
    }

    readonly property int kind: root.kindOf(Config.lock.backgroundShape)
    // The SOFT lock always wants the plain blurred picture, whatever
    // BACKGROUND SHAPE says for the fluid one.
    property bool plain: false
    readonly property bool useShape: !root.plain && Config.lock.backgroundShape !== "off"

    function thump(): void {
        if (thumpAnim.running)
            return;
        thumpAnim.restart();
    }

    // Wheel over the lock swaps the shape, Material-style, with a cooldown so
    // fast scrolling cannot skip through the whole alphabet.
    function cycle(dir: int): void {
        if (!Config.lock.shapeCycle || cool.running)
            return;
        const i = root.shapeNames.indexOf(Config.lock.backgroundShape);
        const next = (i < 0 ? 4 : i) + (dir > 0 ? 1 : -1);
        Config.set("lock.backgroundShape", root.shapeNames[(next + root.shapeNames.length) % root.shapeNames.length]);
        Config.save();
        cool.restart();
    }

    Timer {
        id: cool
        interval: 400
    }

    // ── the flat field everything sits on
    Rectangle {
        anchors.fill: parent
        color: Colours.paper
    }

    // ── OFF: the old look — the whole wallpaper, blurred and dimmed
    Loader {
        anchors.fill: parent
        // With a shape, LOCK SCREEN → AROUND THE SHAPE → WALLPAPER puts the
        // blurred picture around it instead of the plain paper.
        active: !root.useShape || Config.lock.shapeSurround === "blur"

        sourceComponent: Item {
            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: true
                // The blur follows the unlock: as the lock opens, the
                // picture sharpens into the real desktop wallpaper.
                // LOCK SCREEN → BLUR LEVEL scales it; 0 is the sharp picture.
                blur: root.progress * Math.max(0, Math.min(1, Config.lock.blur))
                blurMax: 64
                blurMultiplier: 1
            }

            Image {
                anchors.fill: parent
                source: Config.wallpaper.current !== "" ? "file://" + Config.wallpaper.current : ""
                fillMode: root.fill
                asynchronous: true
                cache: true
                // 1.06 while blurred (keeps the blur from eating the edge
                // pixels), settling to exactly 1.0 as the lock opens — the
                // desktop's own crop.
                scale: 1.0 + 0.06 * root.progress
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: !root.useShape || Config.lock.shapeSurround === "blur"
        color: Colours.alpha(Colours.paper, Config.lock.backgroundDim * 0.92)
        // The dim lifts as the lock opens, so the last painted frame is the
        // wallpaper itself — undimmed and sharp.
        opacity: root.progress
    }

    // ── the handover image — the desktop's own wallpaper layer, recreated
    // exactly: same file, same crop, no blur, no dim. It fades in as the
    // lock opens, so by the last frame the screen shows precisely what the
    // desktop will show — the glyph only ever dissolves INTO the real thing.
    Image {
        id: reveal

        anchors.fill: parent
        source: Config.wallpaper.current !== "" ? "file://" + Config.wallpaper.current : ""
        fillMode: root.fill
        asynchronous: true
        cache: true
        opacity: 1 - root.progress
        visible: root.progress < 0.999 && source !== ""
    }

    // ── the shape window into the wallpaper
    Item {
        id: window

        readonly property real side: Math.min(root.width, root.height) * Math.max(0.2, Config.lock.shapeSize)

        anchors.centerIn: parent
        width: window.side
        height: window.side
        // On unlock the glyph lets go cleanly: it fades while drifting a
        // touch larger, and the reveal image has already taken its place —
        // the handover is a crossfade into the bare desktop wallpaper.
        opacity: root.progress
        visible: root.useShape && root.opacity > 0.01
        scale: window.zoom * (1 + 0.10 * (1 - root.progress))

        property real zoom: 1

        SequentialAnimation {
            id: thumpAnim

            NumberAnimation {
                target: window
                property: "zoom"
                to: 1.06
                duration: 300
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: window
                property: "zoom"
                to: 1.0
                duration: 500
                easing.type: Easing.InOutQuad
            }
        }

        Image {
            id: shot

            anchors.fill: parent
            source: Config.wallpaper.current !== "" ? "file://" + Config.wallpaper.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            layer.enabled: true
            layer.effect: GE.OpacityMask {
                maskSource: LockGlyph {
                    width: shot.width
                    height: shot.height
                    kind: root.kind
                    col: "#ffffff"
                }
            }
        }
    }
}
