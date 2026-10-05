//  VELVET  ·  components/StyleCard.qml
//  The ground of a card in the way a look builds its parts (Appearance.uiStyle
//  or a part's own override): the OSD, the notification centre, the power
//  menu's buttons. Velvet keeps its slanted Slash; the looks get
//    prompt     a terminal box with a coloured gutter
//    arcade     a hard-edged box with a hard drop shadow
//    hud        a thin panel with corner brackets
//    index      a paper page with a rule on top
//    spotlight  frosted glass over smoke
//    grimoire   a dark page in a gold frame
//    poster     a black block with an accent bar
//    raycast    the quiet card of the flavour (clean · minimal · flat · neu · clay)
//    start      the flyout of the Windows edition
//  `hot` is the chosen / hovered state; `danger` tints it red. The content
//  goes on top; `ink`, `dim` and `face` tell it how to write.
import qs.config
import qs.services
import QtQuick

Item {
    id: root

    property string style: Appearance.uiStyle
    property bool hot: false
    property bool danger: false
    property real radiusScale: 1

    readonly property string fl: Appearance.flavour
    readonly property string wv: Appearance.winVer
    readonly property color tone: root.danger ? Colours.danger : Colours.accent
    readonly property color clayTint: Config.appearance.clayTint === "accent" ? Colours.accent : Colours.clay

    // how to write on it
    readonly property color ink: {
        if (root.hot && ["velvet", "prompt", "poster", "arcade"].indexOf(root.style) >= 0)
            return root.style === "arcade" ? Colours.paper : Colours.on(root.tone);
        if (root.hot && root.style === "raycast" && root.fl === "flat")
            return Colours.on(root.tone);
        if (root.style === "poster")
            return Colours.paper;
        if (root.style === "start")
            return root.wv === "10" || root.wv === "7" ? "#ffffff" : "#111111";
        return Colours.ink;
    }
    readonly property color dim: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.68)
    readonly property string face: ({
            prompt: Appearance.fontFamily.mono,
            arcade: Appearance.fontFamily.pixel,
            hud: Appearance.fontFamily.tech,
            index: Appearance.fontFamily.serif,
            grimoire: Appearance.fontFamily.serif,
            poster: Appearance.fontFamily.block,
            start: Appearance.fontFamily.win
        })[root.style] ?? Appearance.fontFamily.display
    readonly property real radius: (({
                velvet: 0,
                prompt: 0,
                arcade: 0,
                hud: 0,
                index: 0,
                spotlight: 22,
                grimoire: 4,
                poster: 0,
                raycast: ({ clean: 14, minimal: 0, flat: 4, neu: 22, clay: 26 })[root.fl] ?? 14,
                start: root.wv === "11" ? 10 : (root.wv === "10" ? 0 : 6)
            })[root.style] ?? 12) * root.radiusScale

    // ── velvet: the house slash
    Slash {
        anchors.fill: parent
        visible: root.style === "velvet"
        shear: Appearance.skew
        color: root.hot ? root.tone : Colours.alpha(Colours.surface, 0.9)
        borderColor: root.tone
        borderWidth: root.hot ? 0 : 2
    }

    Item {
        anchors.fill: parent
        visible: root.style !== "velvet"

        // shadows
        Rectangle {
            visible: ["arcade", "poster", "spotlight", "raycast", "start"].indexOf(root.style) >= 0 && !(root.style === "raycast" && root.fl === "minimal")
            x: root.style === "arcade" || root.style === "poster" ? 6 : 0
            y: root.style === "arcade" || root.style === "poster" ? 6 : 8
            width: parent.width
            height: parent.height
            radius: root.radius
            color: root.style === "poster" ? root.tone : (root.style === "raycast" && root.fl === "clay" ? Colours.alpha(root.clayTint, 0.45) : Qt.rgba(0, 0, 0, root.style === "arcade" ? 0.55 : 0.2))
        }
        Rectangle {
            visible: root.style === "raycast" && root.fl === "neu"
            x: root.hot ? -3 : -7
            y: root.hot ? -3 : -7
            width: parent.width
            height: parent.height
            radius: root.radius
            color: Colours.light ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.06)
        }
        Rectangle {
            visible: root.style === "spotlight"
            anchors.fill: parent
            radius: root.radius
            color: Qt.rgba(0.07, 0.08, 0.13, Math.min(0.9, 0.45 + Config.appearance.glassSmoke))
        }

        Rectangle {
            id: body

            anchors.fill: parent
            radius: root.radius
            color: {
                switch (root.style) {
                case "prompt":
                    return root.hot ? root.tone : Colours.alpha(Colours.paper, 0.95);
                case "arcade":
                    return root.hot ? root.tone : Colours.paper;
                case "hud":
                    return root.hot ? Colours.alpha(root.tone, 0.22) : Colours.alpha(Colours.paper, 0.88);
                case "index":
                    return root.hot ? Colours.mix(Colours.surface, root.tone, 0.12) : Colours.surface;
                case "spotlight":
                    return root.hot ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.08 + 0.06 * Config.appearance.glassFrost);
                case "grimoire":
                    return root.hot ? Colours.mix(Colours.surface, root.tone, 0.18) : Colours.surface;
                case "poster":
                    return root.hot ? root.tone : Colours.ink;
                case "start":
                    if (root.hot)
                        return root.wv === "95" ? "#000080" : (root.wv === "10" ? "#3a3a3a" : Colours.alpha(root.tone, 0.3));
                    return root.wv === "95" ? "#c0c0c0" : (root.wv === "xp" ? "#ffffff" : (root.wv === "7" ? Qt.rgba(0.12, 0.2, 0.32, 0.9) : (root.wv === "10" ? "#1f1f1f" : Qt.rgba(0.97, 0.97, 0.98, 0.97))));
                default:
                    if (root.fl === "flat")
                        return root.hot ? root.tone : Colours.surface;
                    if (root.fl === "minimal")
                        return root.hot ? Colours.alpha(Colours.ink, 0.06) : "transparent";
                    if (root.fl === "neu")
                        return Colours.paper;
                    if (root.fl === "clay")
                        return Colours.mix(Colours.surface, root.clayTint, root.hot ? 0.3 : 0.14);
                    return root.hot ? Colours.mix(Colours.surface, root.tone, 0.12) : Colours.surface;
                }
            }
            border.width: ({
                    arcade: 3,
                    hud: 1,
                    index: 1,
                    spotlight: 1,
                    grimoire: 2,
                    start: 1,
                    raycast: root.fl === "clean" ? 1 : (root.fl === "minimal" ? 0 : 0)
                })[root.style] ?? 0
            border.color: ({
                    arcade: root.tone,
                    hud: Colours.alpha(root.tone, root.hot ? 1 : 0.6),
                    index: Colours.ink,
                    spotlight: Qt.rgba(1, 1, 1, Math.min(1, Config.appearance.glassRim)),
                    grimoire: root.tone,
                    start: root.wv === "95" || root.wv === "xp" ? "#000000" : Qt.rgba(1, 1, 1, 0.2),
                    raycast: root.hot ? root.tone : Colours.alpha(Colours.ink, 0.12)
                })[root.style] ?? "transparent"

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        // the style's marks
        Rectangle {
            visible: root.style === "prompt" || (root.style === "raycast" && root.fl === "minimal")
            width: root.style === "prompt" ? 4 : 2
            height: parent.height
            color: root.style === "prompt" ? root.tone : (root.hot ? root.tone : Colours.alpha(Colours.ink, 0.3))
        }
        Repeater {
            model: root.style === "hud" ? 4 : 0

            Item {
                required property int index

                x: index % 2 === 0 ? -4 : root.width - 16
                y: index < 2 ? -4 : root.height - 16
                width: 20
                height: 20

                Rectangle { x: parent.index % 2 === 0 ? 0 : 18; width: 2; height: 20; color: root.tone }
                Rectangle { y: parent.index < 2 ? 0 : 18; width: 20; height: 2; color: root.tone }
            }
        }
        Rectangle {
            visible: root.style === "raycast" && root.fl === "flat"
            width: parent.width
            height: 5
            radius: root.radius
            color: root.tone
        }
        Rectangle {
            visible: root.style === "grimoire"
            anchors.fill: parent
            anchors.margins: 5
            color: "transparent"
            border.width: 1
            border.color: Colours.alpha(root.tone, 0.5)
        }
        Rectangle {
            visible: root.style === "index"
            x: 12
            y: 7
            width: parent.width - 24
            height: 2
            color: Colours.ink
        }
        Rectangle {
            visible: root.style === "poster"
            width: 9
            height: parent.height
            color: root.hot ? Colours.ink : root.tone
        }
    }
}
