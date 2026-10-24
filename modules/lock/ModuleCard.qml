//  VELVET  ·  modules/lock/ModuleCard.qml
//  Every tile module's stage — the fluid lock's card: a calm,
//  opaque surface with the title as a small quiet mono line at the top
//  (only the notification dock carries one, exactly like its own) and the
//  module's content front and centre. The background itself wears the
//  module's glyph — a quiet watermark at the right edge, cut by the
//  card's outline — so every module keeps its shape identity even at
//  rest without sitting behind the words. Hovering the card wakes it:
//  the glyph morphs to a fresh random form (never the module's own) and
//  turns a little, then returns when the pointer leaves. Each module
//  picks the fluid lock's own corner radius: weather 48, fetch 12, media 28,
//  resources 28, notifications 12. No border, no chrome — the content
//  IS the card.
//  The media card wears its cover artwork instead, dimmed by a veil so
//  the text still reads. `carded` off = the bare look, content only.
//  LOCK SCREEN → FLUID LOCK → CARDS dresses every card at once: SOLID,
//  GLASS, TINTED or OUTLINE, how much of the fill shows, one corner radius
//  for all (or each module its own), the watermark, and whether the cards
//  answer the pointer.
import qs.config
import qs.services
import qs.components
import Quickshell
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE

Item {
    id: root

    property int glyphKind: 0
    // Hover: the background glyph morphs to a fresh random form on every
    // hover (never the module's own shape) and settles back on exit.
    property bool glyphHover: true
    // Pin the hover pool instead of the whole deck — e.g. only full,
    // face-friendly forms for the avatar card.
    property var glyphHoverSet: []

    // The pointer is over the card (LOCK SCREEN → FLUID LOCK → CARDS →
    // RESPOND TO THE POINTER): the edge lights up and, where the module
    // allows it, the glyph changes.
    readonly property bool hot: root.carded && Config.lock.fluidHover && hoverHandler.hovered
    property int hoverGlyph: -1
    property int _lastHover: -1

    property string title: ""
    property string titleIcon: ""
    property bool carded: true
    // The fluid lock's per-card corner radius — the module decides…
    property int radius: 28
    // …unless CORNERS gives every card the same one.
    readonly property real corner: {
        const v = parseInt(Config.lock.fluidCorners);
        return Math.min(isNaN(v) ? root.radius : Math.max(0, v), root.height / 2);
    }
    readonly property string look: ["solid", "glass", "tinted", "outline"].indexOf(Config.lock.fluidCardStyle) >= 0 ? Config.lock.fluidCardStyle : "solid"
    readonly property real strength: Math.max(0.2, Math.min(1, Config.lock.fluidCardOpacity))
    // The fluid lock's full-bleed artwork: the media card can wear its cover as
    // its background, dimmed by a surface veil so the text still reads.
    property string image: ""
    property real imageDim: 0.7
    // Soften the artwork (0 = sharp): a bright cover then reads as a colour
    // field, and the words over it keep their contrast.
    property real imageBlur: 0

    Rectangle {
        id: cardBg

        anchors.fill: parent
        radius: root.corner
        // SOLID is the fluid lock's own opaque surface container tone:
        // whatever moves behind the card never bleeds through. GLASS lets
        // the lock show through, TINTED leans into the accent, OUTLINE is
        // little more than its line. CARD STRENGTH thins any of them.
        color: {
            const base = root.look === "tinted" ? Colours.mix(Colours.surfaceHigh, Colours.accent, 0.16) : Colours.surfaceHigh;
            const share = root.look === "glass" ? 0.42 : (root.look === "outline" ? 0.18 : 1);
            return Colours.alpha(base, share * root.strength);
        }
        border.width: root.look === "outline" ? 1.5 : 1
        border.color: {
            if (root.hot)
                return Colours.alpha(Colours.accent, 0.6);
            if (root.look === "glass")
                return Colours.alpha(Colours.ink, 0.16);
            if (root.look === "tinted")
                return Colours.alpha(Colours.accent, 0.32);
            if (root.look === "outline")
                return Colours.alpha(Colours.ink, 0.26);
            return Colours.alpha(Colours.outline, 0.6);
        }
        antialiasing: true
        visible: root.carded

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    // GLASS: a soft light falling on the top of the pane.
    Rectangle {
        anchors.fill: parent
        radius: root.corner
        visible: root.carded && root.look === "glass"
        antialiasing: true
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Colours.alpha(Colours.ink, 0.07)
            }
            GradientStop {
                position: 0.45
                color: "transparent"
            }
        }
    }

    // Watching the whole card — a HoverHandler observes without grabbing,
    // so the modules' own buttons and areas keep their clicks.
    HoverHandler {
        id: hoverHandler

        enabled: root.carded && Config.lock.fluidHover

        onHoveredChanged: {
            if (hovered && root.glyphHover) {
                const pool = root.glyphHoverSet.length > 0 ? root.glyphHoverSet : [0, 1, 2, 3, 4, 5, 6, 8];
                const options = pool.filter(k => k !== root.glyphKind && k !== root._lastHover);
                const src = options.length > 0 ? options : pool;
                root.hoverGlyph = src[Math.floor(Math.random() * src.length)];
                root._lastHover = root.hoverGlyph;
            } else {
                root.hoverGlyph = -1;
            }
        }
    }

    // The module's glyph lives IN the background itself — as a watermark
    // at the card's right edge, partly past it and cut by the card's own
    // rounded outline. Centred it sat right behind the words ("Welcome
    // back" read over a triangle, the power buttons over a flower); at the
    // edge it keeps every module's shape identity and leaves the content
    // alone. Cards that wear artwork simply cover it — the cover is the
    // face then.
    Item {
        id: glyphClip

        anchors.fill: parent
        // LOCK SCREEN → FLUID LOCK → CARDS → GLYPH WATERMARK
        visible: root.carded && Config.lock.fluidWatermark
        layer.enabled: glyphClip.visible
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: glyphClip.width
                height: glyphClip.height
                radius: root.corner
            }
        }

        MorphGlyph {
            id: glyph

            readonly property real side: Math.max(48, Math.min(root.height * 1.2, 240))

            width: glyph.side
            height: glyph.side
            x: root.width - glyph.side * 0.62
            y: (root.height - glyph.side) / 2
            rotation: root.hot ? -8 : 0
            kind: root.hot && root.glyphHover && root.hoverGlyph >= 0 ? root.hoverGlyph : root.glyphKind
            // The shell's own accent — the glyphs speak in the accent tone.
            col: Colours.alpha(Colours.accent, root.hot ? 0.2 : 0.11)

            Behavior on col {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }

            Behavior on rotation {
                NumberAnimation {
                    duration: 420
                    easing.type: Easing.OutBack
                }
            }
        }
    }

    // ── the artwork layer: the cover, radius-masked, fading in when it is
    // ready, never popping — and softened when the card asks for it.
    Item {
        id: artClip

        anchors.fill: parent
        visible: root.carded && root.image !== ""
        opacity: cardArt.status === Image.Ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: 400
                easing.type: Easing.OutQuad
            }
        }

        layer.enabled: artClip.visible
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: artClip.width
                height: artClip.height
                radius: root.corner
            }
        }

        Image {
            id: cardArt

            anchors.fill: parent
            // A touch larger while blurred, so the soft edge falls outside.
            scale: root.imageBlur > 0 ? 1.12 : 1
            source: root.image
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true

            layer.enabled: root.imageBlur > 0
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: root.imageBlur
                blurMax: 48
                autoPaddingEnabled: false
            }
        }
    }

    // The veil that keeps the text readable over the artwork — in the
    // paper tone, the one the ink is made to read on.
    Rectangle {
        anchors.fill: parent
        radius: root.corner
        color: Colours.alpha(Colours.paper, root.imageDim)
        visible: root.carded && root.image !== ""
        opacity: artClip.opacity
        antialiasing: true
    }

    // The title line — what this card is, small, quiet and mono, exactly
    // like the fluid lock's dock label.
    P5Text {
        anchors.top: parent.top
        anchors.topMargin: 16
        anchors.left: parent.left
        anchors.leftMargin: 16
        visible: root.carded && root.title !== ""
        text: root.title
        color: Colours.alpha(Colours.inkDim, 0.75)
        font.family: Appearance.fontFamily.mono
        font.pixelSize: Appearance.font.size.small
        font.weight: Font.Medium
    }
}
