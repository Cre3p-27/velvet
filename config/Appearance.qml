//  VELVET  ·  config/Appearance.qml
//  Derived design tokens. Nothing in the UI hardcodes a number or a font —
//  everything scales from the four multipliers the user can drag in Settings.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // ------------------------------------------------------------------ fonts
    // Pick the first family actually installed. The display face carries the
    // whole Persona look, so the list is ordered by how heavy/condensed it is.
    function firstAvailable(candidates: var, fallback: string): string {
        const families = Qt.fontFamilies();
        for (let i = 0; i < candidates.length; i++)
            if (families.indexOf(candidates[i]) !== -1)
                return candidates[i];
        return fallback;
    }

    // VISUALS → TYPE STYLE. "persona" is the house type — heavy, italic,
    // tracked out; "soft" is the round Material look — the same words,
    // upright, in a friendly geometric sans. The others belong to the vibes:
    // "mono" a terminal, "serif" a printed page, "block" a poster, "arcade"
    // a pixel game, "tech" a sci-fi HUD, "clean" a calm neutral sans, "win" the
    // face of the Windows edition chosen (appearance.winVersion).
    readonly property string mood: Config.appearance.typeStyle
    readonly property bool softType: root.mood !== "persona"

    // The pixel face is drawn by assets/make-font.py and loaded here; without
    // it the arcade type falls back to a bold monospace.
    FontLoader {
        id: pixelFace

        source: Qt.resolvedUrl("../assets/fonts/VelvetPixel.ttf")
    }

    // The face of a type mood — the LOOKS page draws every vibe in its own.
    function familyOf(mood: string, display: bool): string {
        switch (mood) {
        case "soft":
            return fontFamily.soft;
        case "mono":
            return fontFamily.mono;
        case "serif":
            return fontFamily.serif;
        case "block":
            return fontFamily.block;
        case "arcade":
            return display ? fontFamily.pixel : fontFamily.mono;
        case "tech":
            return fontFamily.tech;
        case "clean":
            return fontFamily.clean;
        case "win":
            return fontFamily.win;
        default:
            return display ? root.firstAvailable(["Archivo Black", "Anton", "Bebas Neue", "Oswald", "Archivo Expanded", "Inter Display", "Inter", "Roboto Condensed", "DejaVu Sans"], "sans-serif") : root.firstAvailable(["Inter", "IBM Plex Sans", "Roboto", "Noto Sans", "Cantarell", "DejaVu Sans"], "sans-serif");
        }
    }

    readonly property var fontFamily: QtObject {
        readonly property string mono: Config.appearance.fontMono !== "auto" ? Config.appearance.fontMono : root.firstAvailable(["JetBrains Mono", "JetBrainsMono Nerd Font", "Iosevka", "Fira Code", "IBM Plex Mono", "Hack", "CaskaydiaCove Nerd Font Mono", "DejaVu Sans Mono"], "monospace")
        // The round, friendly geometric sans the soft looks are made of
        // (the SOFT lock, the inspo looks) — whichever of them is installed.
        readonly property string soft: root.firstAvailable(["Google Sans Flex", "Google Sans", "Product Sans", "DM Sans", "Plus Jakarta Sans", "Outfit", "Poppins", "Manrope", "Figtree", "Inter", "Adwaita Sans", "Cantarell", "Noto Sans"], "sans-serif")
        readonly property string serif: root.firstAvailable(["Playfair Display", "Cormorant Garamond", "EB Garamond", "Libre Baskerville", "Source Serif 4", "Source Serif Pro", "Noto Serif", "Liberation Serif", "DejaVu Serif"], "serif")
        readonly property string block: root.firstAvailable(["Archivo Black", "Anton", "Montserrat", "Inter Display", "Open Sans", "Noto Sans", "DejaVu Sans"], "sans-serif")
        readonly property string tech: root.firstAvailable(["Rajdhani", "Orbitron", "Exo 2", "Oxanium", "Saira", "Adwaita Sans", "Open Sans", "Noto Sans"], "sans-serif")
        readonly property string pixel: pixelFace.status === FontLoader.Ready ? pixelFace.name : mono
        // The calm neutral sans of the CLEAN look (Adwaita Sans is Inter's cousin).
        readonly property string clean: root.firstAvailable(["Inter", "Inter Display", "Adwaita Sans", "IBM Plex Sans", "Cantarell", "Noto Sans", "Open Sans"], "sans-serif")
        // The window system's own faces, one per era: the old bitmap-ish
        // sans of 95/98, Tahoma for XP, Segoe for the rest.
        readonly property string win: {
            const v = Config.appearance.winVersion;
            if (v === "95")
                return root.firstAvailable(["MS Sans Serif", "Liberation Sans", "Arimo", "Arial", "DejaVu Sans"], "sans-serif");
            if (v === "xp")
                return root.firstAvailable(["Tahoma", "Verdana", "DejaVu Sans", "Bitstream Vera Sans"], "sans-serif");
            return root.firstAvailable(["Selawik", "Segoe UI", "Open Sans", "Noto Sans", "Adwaita Sans"], "sans-serif");
        }
        // Big, heavy, italic-able — the "SYSTEM OVERRIDE" type.
        readonly property string display: Config.appearance.fontDisplay !== "auto" ? Config.appearance.fontDisplay : root.familyOf(root.mood, true)
        // Everything else.
        readonly property string body: Config.appearance.fontBody !== "auto" ? Config.appearance.fontBody : root.familyOf(root.mood, false)
        // Icon font — Material Symbols; without it we degrade to text.
        readonly property string icon: root.firstAvailable(["Material Symbols Rounded", "Material Symbols Outlined", "Material Icons Round", "Symbols Nerd Font", "Symbols Nerd Font Mono"], "sans-serif")
    }

    // How the type of the current mood is set: weight, slant, tracking.
    readonly property var type: QtObject {
        readonly property int displayWeight: ({
                persona: Font.Black,
                soft: Font.Bold,
                mono: Font.Bold,
                serif: Font.Bold,
                block: Font.Black,
                arcade: Font.Normal,
                tech: Font.DemiBold,
                clean: Font.DemiBold,
                win: Config.appearance.winVersion === "95" || Config.appearance.winVersion === "xp" ? Font.Bold : Font.DemiBold
            })[root.mood] ?? Font.Bold
        readonly property int bodyWeight: ({
                persona: Font.DemiBold,
                soft: Font.Medium,
                mono: Font.Normal,
                serif: Font.Medium,
                block: Font.Bold,
                arcade: Font.Normal,
                tech: Font.Medium,
                clean: Font.Normal,
                win: Font.Normal
            })[root.mood] ?? Font.Medium
        readonly property bool italic: root.mood === "persona"
        readonly property real displayTracking: ({
                persona: 1.4,
                soft: 0.3,
                mono: 0.2,
                serif: 0.8,
                block: 1.0,
                arcade: 1.0,
                tech: 1.8,
                clean: 0,
                win: 0
            })[root.mood] ?? 0.3
        readonly property real bodyTracking: ({
                persona: 0.2,
                soft: 0.2,
                mono: 0,
                serif: 0.2,
                block: 0.3,
                arcade: 0.4,
                tech: 0.8,
                clean: 0,
                win: 0
            })[root.mood] ?? 0.2
        // lowercase for the terminal's voice; everything else is as written
        readonly property int capitalization: Config.appearance.caps === "lower" ? Font.AllLowercase : Font.MixedCase
    }

    readonly property bool hasIconFont: fontFamily.icon !== "sans-serif"

    readonly property var font: QtObject {
        readonly property var size: QtObject {
            readonly property int tiny: Math.round(10 * Config.appearance.fontScale)
            readonly property int small: Math.round(12 * Config.appearance.fontScale)
            readonly property int normal: Math.round(14 * Config.appearance.fontScale)
            readonly property int large: Math.round(17 * Config.appearance.fontScale)
            readonly property int huge: Math.round(22 * Config.appearance.fontScale)
            readonly property int title: Math.round(34 * Config.appearance.fontScale)
            readonly property int hero: Math.round(76 * Config.appearance.fontScale)
        }
    }

    // ------------------------------------------------------------------ density
    // One dial for how much room a settings row gets. Bigger rows mean fewer
    // on screen at once, which is the point: a wall of thirty settings is
    // harder to read than eight you can actually see.
    readonly property real densityScale: {
        switch (Config.appearance.density) {
        case "compact":
            return 0.84;
        case "spacious":
            return 1.3;
        default:
            return 1.0;
        }
    }

    // ── the settings skin (VISUALS → VIBE → SETTINGS LAYOUT)
    readonly property string skin: Config.appearance.skin
    readonly property bool skinned: root.skin !== "persona"
    // The kind of launcher, notifications … a look builds (Velvet: "velvet").
    readonly property string uiStyle: !root.skinned ? "velvet" : (({
                console: "prompt",
                arcade: "arcade",
                hud: "hud",
                ledger: "index",
                glass: "spotlight",
                tome: "grimoire",
                poster: "poster",
                clean: "raycast",
                win: "start"
            })[root.skin] ?? "spotlight")
    // Each part may wear another look's way (VISUALS → THIS LOOK → SHELL
    // PARTS): "auto" follows the look.
    function partStyle(v: string): string {
        return !v || v === "auto" ? root.uiStyle : v;
    }
    readonly property string launcherStyle: root.partStyle(Config.appearance.launcherStyle)
    readonly property string notifStyle: root.partStyle(Config.appearance.notifStyle)
    readonly property string osdStyle: root.partStyle(Config.appearance.osdStyle)
    readonly property string sessionStyle: root.partStyle(Config.appearance.sessionStyle)
    // The quiet sheet (skin "clean") comes in five moods, told apart by the vibe
    // wearing it: clean, minimal, flat, neu (neumorphism) and clay.
    readonly property string flavour: ["minimal", "flat", "neu", "clay"].indexOf(Config.appearance.vibe) >= 0 ? Config.appearance.vibe : "clean"
    // Which windows the WINDOWS look is wearing: 95 | xp | 7 | 10 | 11.
    readonly property string winVer: Config.appearance.winVersion

    // ── THIS LOOK: the tuning every look shares (VISUALS → THIS LOOK)
    readonly property real depth: Math.max(0, Config.appearance.depth)
    readonly property real gloss: Math.max(0, Config.appearance.gloss)
    readonly property real pattern: Math.max(0, Config.appearance.patternStrength)
    // Where the light comes from (neumorphism): the signs of the dark side's
    // offset — (1, 1) is the light at the top left, the shadow below right.
    readonly property point lightSign: ({
            "top-left": Qt.point(1, 1),
            "top-right": Qt.point(-1, 1),
            "bottom-left": Qt.point(1, -1),
            "bottom-right": Qt.point(-1, -1)
        })[Config.appearance.neuLight] ?? Qt.point(1, 1)

    // Words that stay capitals in a sentence ("CPU", not "Cpu").
    readonly property var keepCaps: ["CPU", "RAM", "GPU", "FPS", "OSD", "UI", "HDR", "DPI", "ID", "USB", "DND", "PAM", "SSH", "URL", "IPC", "GTK", "QT", "VRR", "HDMI", "LED", "MPRIS", "PIN", "WCAG", "AA", "P1", "P2", "TTS", "AI", "SFX", "BPM", "LRC", "OK", "TV", "DE", "EN", "PC", "AM", "PM"]

    function _word(w: string, cap: bool): string {
        const bare = w.replace(/[^a-zA-Z0-9]/g, "").toUpperCase();
        if (root.keepCaps.indexOf(bare) >= 0)
            return w.toUpperCase();
        if (cap && w.indexOf("-") > 0)
            return w.split("-").map(p => p.charAt(0).toUpperCase() + p.slice(1)).join("-");
        return cap ? w.charAt(0).toUpperCase() + w.slice(1) : w;
    }

    // "ACCENT SOURCE · WHERE IT COMES FROM" → "Accent source · Where it comes from".
    // The settings are written in capitals; the calm looks read them as
    // sentences.
    function sentence(s: string): string {
        if (!s)
            return "";
        return String(s).split(" · ").map(part => part.toLowerCase().split(" ").map((w, i) => root._word(w, i === 0)).join(" ")).join(" · ");
    }

    // Text as the current settings skin writes it: sentences for CLEAN and the
    // newer Windows editions, Title Case for 95 and XP, as written elsewhere.
    function tcase(s: string): string {
        if (root.skin === "clean")
            return root.sentence(s);
        if (root.skin === "win")
            return root.winVer === "95" || root.winVer === "xp" ? root.titled(s) : root.sentence(s);
        return s;
    }

    // "ACCENT SOURCE" → "Accent Source" (the old window system's titles).
    function titled(s: string): string {
        if (!s)
            return "";
        return String(s).toLowerCase().split(" ").map(w => root._word(w, true)).join(" ");
    }

    // Row metrics of every skin: head height, gap between rows, name / sub /
    // value type sizes and the inset of the first column.
    readonly property var skinRows: ({
            console: { h: 30, gap: 0, name: 14, sub: 12, val: 14, inset: 16 },
            arcade: { h: 54, gap: 6, name: 17, sub: 11, val: 17, inset: 44 },
            hud: { h: 54, gap: 5, name: 15, sub: 11, val: 15, inset: 56 },
            ledger: { h: 58, gap: 0, name: 18, sub: 12, val: 16, inset: 34 },
            glass: { h: 62, gap: 3, name: 17, sub: 12, val: 16, inset: 24 },
            tome: { h: 58, gap: 0, name: 18, sub: 12, val: 16, inset: 40 },
            poster: { h: 62, gap: 0, name: 20, sub: 12, val: 18, inset: 26 },
            clean: { h: 60, gap: 0, name: 15, sub: 12, val: 14, inset: 20 },
            win: ({
                "95": { h: 34, gap: 0, name: 12, sub: 11, val: 12, inset: 8 },
                "xp": { h: 38, gap: 0, name: 12, sub: 11, val: 12, inset: 10 },
                "7": { h: 52, gap: 0, name: 14, sub: 12, val: 13, inset: 14 },
                "10": { h: 60, gap: 0, name: 15, sub: 12, val: 14, inset: 20 },
                "11": { h: 64, gap: 3, name: 14, sub: 12, val: 14, inset: 18 }
            })[root.winVer] ?? { h: 60, gap: 0, name: 14, sub: 12, val: 13, inset: 18 }
        })
    readonly property var sk: root.skinRows[root.skin] ?? null

    // One dial for how much room a settings row gets. Bigger rows mean fewer
    // on screen at once, which is the point: a wall of thirty settings is
    // harder to read than eight you can actually see.
    readonly property var row: QtObject {
        readonly property int height: Math.round((root.sk ? root.sk.h : 112) * root.densityScale * Config.appearance.spacingScale)
        readonly property int wide: Math.round(164 * root.densityScale * Config.appearance.spacingScale)
        readonly property int gap: Math.round((root.sk ? root.sk.gap : 16) * root.densityScale * Config.appearance.spacingScale)
        readonly property int title: Math.round((root.sk ? root.sk.name : 34) * root.densityScale * Config.appearance.fontScale)
        readonly property int sub: Math.round((root.sk ? root.sk.sub : 15) * root.densityScale * Config.appearance.fontScale)
        readonly property int value: Math.round((root.sk ? root.sk.val : 40) * root.densityScale * Config.appearance.fontScale)
        readonly property int inset: Math.round((root.sk ? root.sk.inset : 52) * root.densityScale)
        // How far each level of an opened sub-page steps in.
        readonly property int indent: Math.round(34 * root.densityScale)
    }

    // ------------------------------------------------------------------ metrics
    readonly property var spacing: QtObject {
        readonly property int tiny: Math.round(4 * Config.appearance.spacingScale)
        readonly property int small: Math.round(8 * Config.appearance.spacingScale)
        readonly property int normal: Math.round(12 * Config.appearance.spacingScale)
        readonly property int large: Math.round(20 * Config.appearance.spacingScale)
        readonly property int huge: Math.round(32 * Config.appearance.spacingScale)
    }

    readonly property var padding: QtObject {
        readonly property int tiny: Math.round(4 * Config.appearance.spacingScale)
        readonly property int small: Math.round(8 * Config.appearance.spacingScale)
        readonly property int normal: Math.round(14 * Config.appearance.spacingScale)
        readonly property int large: Math.round(22 * Config.appearance.spacingScale)
        readonly property int huge: Math.round(36 * Config.appearance.spacingScale)
    }

    // ── the card shape (VISUALS → CARD SHAPE). square, notch, bracket and pixel
    // have no rounded corners at all; round and pill have more than the house.
    readonly property string shape: Config.appearance.shape
    readonly property bool angular: Config.appearance.sharpCorners || ["square", "notch", "bracket", "pixel", "bevel"].indexOf(root.shape) >= 0
    readonly property real shapeK: root.shape === "round" ? 1.35 : (root.shape === "pill" ? 1.8 : 1)

    // A corner radius from a pixel size written into a module: 0 where the
    // vibe has no round corners, wider where it has more. Radii under 6 px
    // are details (a dot, a tick), not corners, and stay as they are.
    // ── where a part stands along an edge (the …side settings: left | centre |
    // right). The x of an item `w` wide in an area `areaW` wide, `margin` in
    // from the edge it keeps to; a taskbar standing on that side is cleared.
    function sideX(side: string, areaW: real, w: real, margin: real): real {
        if (side === "left")
            return margin + root.barRoom("left");
        if (side === "right")
            return areaW - w - margin - root.barRoom("right");
        return (areaW - w) / 2;
    }
    // The island's edge (MODULES → DYNAMIC ISLAND → POSITION): "top", or the
    // "left" / "right" edge it slides out of. The map and the hot zone follow.
    readonly property string islandEdge: Config.map.islandSide === "left" ? "left" : (Config.map.islandSide === "right" ? "right" : "top")
    // On a side edge: the y of an item `h` tall whose first `anchorH` pixels
    // are centred on the chosen height (ISLAND HEIGHT, plus the nudge), kept
    // on screen — an island that opens downwards stays where the pill was
    // until the bottom of the screen pushes it up.
    function edgeY(areaH: real, h: real, anchorH: real): real {
        const centre = areaH * Math.max(0.05, Math.min(0.95, Config.map.islandEdgeY)) + Config.map.islandShift;
        return Math.round(Math.max(8, Math.min(areaH - h - 8, centre - anchorH / 2)));
    }
    // the room a vertical taskbar takes on the left or right edge
    function barRoom(side: string): real {
        if (!Config.bar.enabled || Config.bar.position !== side)
            return 0;
        return Config.bar.thickness + Config.bar.margin * 2;
    }
    // Where the desktop starts on a screen edge: inside the SCREEN FRAME and
    // inside a pinned taskbar on that edge. A docked island grows out of
    // exactly this line, so it reads as part of the frame (or the bar).
    function edgeInset(side: string): real {
        const bar = Config.bar.enabled && Config.bar.position === side && Config.bar.style !== "floating" && (Config.bar.persistent || !Config.bar.showOnHover);
        if (bar)
            return Config.bar.thickness + Config.bar.margin;
        return Config.bar.frame ? Math.max(0, Config.bar.frameWidth) : 0;
    }

    function r(px: real): real {
        if (px < 6)
            return px;
        return root.angular ? 0 : Math.round(px * root.shapeK);
    }

    // The radius of a pill, a chip, a toggle: half its height — unless the
    // vibe has no round corners, then a rectangle.
    function pill(h: real): real {
        return root.angular ? Math.min(2, h / 8) : h / 2;
    }

    readonly property var rounding: QtObject {
        readonly property int small: root.angular ? 0 : Math.round(6 * Config.appearance.roundingScale * root.shapeK)
        readonly property int normal: root.angular ? 0 : Math.round(12 * Config.appearance.roundingScale * root.shapeK)
        readonly property int large: root.angular ? 0 : Math.round(20 * Config.appearance.roundingScale * root.shapeK)
        readonly property int full: root.angular ? 0 : 999
    }

    // Where a shape's middle LOOKS to be, as a share of its height below
    // the box's middle — a triangle's weight sits low, so what it holds
    // sits low too.
    function shapeCentre(kind: string): real {
        return ({
                triangle: 0.1,
                penta: 0.04,
                pentagon: 0.02,
                star: 0.03
            })[kind] ?? 0;
    }

    // The shape a shape turns into under the pointer when nobody picked one:
    // a partner that reads as the same family, never itself.
    function hoverPartner(kind: string): string {
        return ({
                circle: "cookie",
                square: "diamond",
                cookie: "flower",
                sun: "cookie",
                scallop: "flower",
                flower: "clover",
                clover: "flower",
                wavy: "sun",
                blob: "circle",
                penta: "star",
                pentagon: "penta",
                hexagon: "cookie",
                diamond: "square",
                triangle: "penta",
                star: "burst",
                burst: "star"
            })[kind] ?? "cookie";
    }

    // Every shape an element can wear (M3Shape kinds), in picker order —
    // the soft lock, the widgets and the editors all offer this one list.
    readonly property var shapeKinds: [
        {
            v: "circle",
            t: "Circle"
        },
        {
            v: "square",
            t: "Square"
        },
        {
            v: "cookie",
            t: "Cookie"
        },
        {
            v: "sun",
            t: "Gear"
        },
        {
            v: "scallop",
            t: "Scallop"
        },
        {
            v: "flower",
            t: "Flower"
        },
        {
            v: "clover",
            t: "Clover"
        },
        {
            v: "wavy",
            t: "Wavy"
        },
        {
            v: "blob",
            t: "Pebble"
        },
        {
            v: "penta",
            t: "Pentagon"
        },
        {
            v: "pentagon",
            t: "Soft pentagon"
        },
        {
            v: "hexagon",
            t: "Hexagon"
        },
        {
            v: "diamond",
            t: "Diamond"
        },
        {
            v: "triangle",
            t: "Triangle"
        },
        {
            v: "star",
            t: "Star"
        },
        {
            v: "burst",
            t: "Burst"
        }
    ]

    // The signature tilt. Everything in the Settings overlay rides on this.
    readonly property real skew: Config.appearance.skew

    // ------------------------------------------------------------------ motion
    // Punchy means: fast in, hard stop, slight overshoot. Never linear. The
    // vibes bend it: smooth glides, bouncy overshoots, crisp snaps.
    readonly property real motionK: ({
            punchy: 1,
            smooth: 1.35,
            bouncy: 1,
            crisp: 0.55
        })[Config.appearance.motion] ?? 1

    readonly property var anim: QtObject {
        readonly property int instant: Math.round(90 * Config.appearance.animationScale * root.motionK)
        readonly property int fast: Math.round(160 * Config.appearance.animationScale * root.motionK)
        readonly property int normal: Math.round(260 * Config.appearance.animationScale * root.motionK)
        readonly property int slow: Math.round(420 * Config.appearance.animationScale * root.motionK)
        readonly property int entrance: Math.round(560 * Config.appearance.animationScale * root.motionK)

        readonly property int emphasized: Config.appearance.motion === "smooth" ? Easing.InOutCubic : (Config.appearance.motion === "crisp" ? Easing.OutQuad : Easing.OutExpo)
        readonly property int standard: Config.appearance.motion === "smooth" ? Easing.InOutSine : Easing.OutCubic
        readonly property int snap: Config.appearance.motion === "bouncy" ? Easing.OutElastic : (Config.appearance.motion === "crisp" ? Easing.OutQuad : Easing.OutBack)
        // how far a pop overshoots
        readonly property real overshoot: Config.appearance.motion === "bouncy" ? 3.2 : 1.7
    }
}
