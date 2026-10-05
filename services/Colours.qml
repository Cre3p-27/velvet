//  VELVET  ·  services/Colours.qml
//  Pulls an accent out of the current wallpaper and derives the whole palette
//  from it.
//
//  The rule that matters here: nothing is allowed to be unreadable. Text
//  colours are not picked by eye or by a lightness threshold — they are
//  measured against their background with the WCAG contrast formula and pushed
//  until they pass. A wallpaper can change the shell's colour; it cannot make
//  the shell illegible.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property color fallback: "#e4002b"

    // ------------------------------------------------------------------ maths
    function alpha(c: color, a: real): color {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    function lighten(c: color, amount: real): color {
        return Qt.hsla(c.hslHue, c.hslSaturation, Math.min(1, c.hslLightness + amount), c.a);
    }

    function darken(c: color, amount: real): color {
        return Qt.hsla(c.hslHue, c.hslSaturation, Math.max(0, c.hslLightness - amount), c.a);
    }

    function saturate(c: color, amount: real): color {
        return Qt.hsla(c.hslHue, Math.min(1, c.hslSaturation + amount), c.hslLightness, c.a);
    }

    // WCAG relative luminance, and the contrast ratio built from it. 4.5 is the
    // AA threshold for body text, 3.0 for large text and UI edges.
    function luminance(c: color): real {
        const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
    }

    function contrast(a: color, b: color): real {
        const la = root.luminance(a);
        const lb = root.luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Ink or paper — whichever actually reads better on this background, rather
    // than whichever side of an arbitrary threshold it falls on.
    function on(c: color): color {
        return root.contrast(root.ink, c) >= root.contrast(root.paper, c) ? root.ink : root.paper;
    }

    // Walks a colour's lightness until it clears `min` against `bg`, keeping its
    // hue. This is what stops a dark-blue wallpaper from giving you dark-blue
    // labels on a dark-blue panel.
    function readable(fg: color, bg: color, min: real): color {
        if (!Config.appearance.contrastGuard || root.contrast(fg, bg) >= min)
            return fg;

        const up = root.luminance(bg) < 0.2;
        let c = fg;
        for (let i = 0; i < 26; i++) {
            const l = Math.max(0, Math.min(1, c.hslLightness + (up ? 0.03 : -0.03)));
            c = Qt.hsla(c.hslHue, c.hslSaturation, l, fg.a);
            if (root.contrast(c, bg) >= min)
                return c;
            if (l <= 0 || l >= 1)
                break;
        }
        return c;
    }

    // ------------------------------------------------------------------ accent
    property color rawAccent: root.fallback

    // The theme switcher's feel. When the wallpaper changes, this one value
    // walks to its new home instead of snapping — and because every other
    // colour in the shell is derived from it, the whole palette follows in
    // one gesture: bar, settings, map and lock retint together, the way the
    // screen does when the picture underneath changes.
    Behavior on rawAccent {
        ColorAnimation { duration: 620; easing.type: Easing.InOutSine }
    }

    readonly property color accentSource: Config.appearance.accentSource === "manual" ? Config.appearance.accentColour : rawAccent

    // The user's own dial on how loud the wallpaper is allowed to be. At 1.0
    // it is what the image gave us; below that it drifts toward neutral.
    readonly property color accent: {
        // A MANUAL accent is used as picked; COLOUR STRENGTH tames only the
        // colour extracted from the wallpaper.
        const s = Config.appearance.accentSource === "manual" ? 1 : Math.max(0, Math.min(1.4, Config.appearance.accentSaturation));
        const tuned = Qt.hsla(accentSource.hslHue, Math.max(0.12, Math.min(1, accentSource.hslSaturation * s)), accentSource.hslLightness, 1);
        // Must stay legible against the panels it sits on.
        return root.readable(tuned, root.surface, 3.4);
    }

    readonly property color accentHot: Qt.hsla(accent.hslHue, Math.min(1, accent.hslSaturation * 1.05), Math.min(0.76, accent.hslLightness + 0.14), 1)
    // The colour of the clay look (VISUALS → THIS LOOK → CLAY): its shadow and
    // the tint of its plates. "accent" is the accent's own deep tone.
    readonly property color clay: ({
            peach: "#ff9a76",
            mint: "#3fc79a",
            sky: "#4f9dff",
            lilac: "#9a7bff"
        })[Config.appearance.clayTint] ?? root.accentDeep
    readonly property color accentDeep: Qt.hsla(accent.hslHue, accent.hslSaturation, Math.max(0.16, accent.hslLightness - 0.24), 1)
    readonly property color accentAlt: Qt.hsla((accent.hslHue + 0.52) % 1.0, Math.min(1, accent.hslSaturation * 0.85), 0.62, 1)

    // Accent used as *text* on a panel — guaranteed to clear body-text contrast,
    // which the accent fill itself does not have to.
    readonly property color accentInk: root.readable(accent, root.surface, 4.5)

    // ── the wallpaper's own ground colours, for surfaces that want to wear
    // the picture itself (the Dynamic Island's WALLPAPER theme). The tint is
    // a prominence-weighted mix of the colours the image is actually made of
    // — its hue and saturation survive, so the island unmistakably belongs
    // to the picture — held just dark enough that ink text clears it. The
    // glow is the picture's loudest mid-tone. Both walk with every wallpaper
    // switch, like the rest of the palette.
    readonly property color wallpaperTint: {
        const list = quantizer.colors;
        if (!list || list.length === 0)
            return root.surface;
        // The quantizer lists the most prominent colours first — the first
        // three carry most of the picture's identity.
        const weights = [0.55, 0.28, 0.17];
        let sx = 0;
        let sy = 0;
        let sSum = 0;
        let lSum = 0;
        let wSum = 0;
        for (let i = 0; i < Math.min(3, list.length); i++) {
            const w = weights[i];
            const c = list[i];
            sx += Math.cos(c.hslHue * Math.PI * 2) * w;
            sy += Math.sin(c.hslHue * Math.PI * 2) * w;
            sSum += c.hslSaturation * w;
            lSum += c.hslLightness * w;
            wSum += w;
        }
        let hue = Math.atan2(sy, sx) / (Math.PI * 2);
        if (hue < 0)
            hue += 1;
        // Keep the picture's own saturation (bounded so it never screams)
        // and its own brightness feel — but never brighter than ink text
        // can clear (0.30 lightness is the hard ceiling).
        const sat = Math.max(0.16, Math.min(0.6, sSum / wSum));
        const light = Math.max(0.05, Math.min(0.30, (lSum / wSum) * 0.8 + root.lift));
        return Qt.hsla(hue, sat, light, 1);
    }

    readonly property color wallpaperGlow: {
        const list = quantizer.colors;
        let best = null;
        let bestS = -1;
        if (list && list.length > 0) {
            for (let i = 0; i < list.length; i++) {
                const c = list[i];
                const s = c.hslSaturation;
                if (s > bestS && c.hslLightness > 0.3 && c.hslLightness < 0.82) {
                    bestS = s;
                    best = c;
                }
            }
        }
        return best ?? root.accent;
    }

    // ------------------------------------------------------------------ ground
    // `surfaceLift` raises the whole dark end. Deep black looks great in a
    // screenshot and is tiring on a real panel at night.
    readonly property real lift: Math.max(0, Math.min(0.2, Config.appearance.surfaceLift))
    readonly property real tint: Math.max(0, Math.min(0.9, Config.appearance.surfaceTint)) * (Config.appearance.groundColour === "auto" ? 1 : Math.min(1, root.groundSource.hslSaturation * 6))

    // NOTE these take their hue from accentSource, not from `accent`. `accent`
    // is contrast-checked against `surface`, so hanging `surface` off `accent`
    // would close a binding loop — and QML would resolve it by leaving one of
    // them at whatever it happened to hold first.
    readonly property color groundSource: Config.appearance.groundColour !== "auto" && /^#[0-9a-fA-F]{6}$/.test(Config.appearance.groundColour) ? Config.appearance.groundColour : accentSource
    readonly property real hue: groundSource.hslHue

    // GROUND: dark (the house) or light — a printed page. A light ground turns
    // every ground colour over: the paper is bright, the ink is dark, and
    // everything that is measured against them (readable(), on()) follows.
    readonly property bool light: Config.appearance.ground === "light"

    readonly property color paper: light ? Qt.hsla(hue, Math.min(0.95, tint * 1.5), Math.max(0.72, 0.88 - lift * 0.5), 1) : Qt.hsla(hue, tint * 0.6, 0.045 + lift * 0.7, 1)
    readonly property color surface: light ? Qt.hsla(hue, Math.min(0.9, tint * 1.1), Math.max(0.8, 0.94 - lift * 0.4), 1) : Qt.hsla(hue, tint * 0.45, 0.085 + lift, 1)
    readonly property color surfaceHigh: light ? Qt.hsla(hue, Math.min(0.7, tint * 0.5), Math.max(0.86, 0.985 - lift * 0.3), 1) : Qt.hsla(hue, tint * 0.36, 0.135 + lift * 1.15, 1)
    readonly property color outline: light ? Qt.hsla(hue, tint * 0.6, 0.6 - lift, 1) : Qt.hsla(hue, tint * 0.28, 0.30 + lift, 1)

    readonly property color ink: light ? Qt.hsla(hue, Math.min(0.3, 0.1 + tint * 0.5), 0.08, 1) : Qt.hsla(hue, 0.08, 0.97, 1)
    // Secondary text, held above the AA threshold whatever the accent did.
    readonly property color inkDim: root.readable(light ? Qt.hsla(hue, 0.08, 0.34, 1) : Qt.hsla(hue, 0.06, 0.70, 1), root.surface, 4.5)

    // ── THE EDGE (VISUALS → OUTLINE COLOUR): what every card is outlined and
    // shadowed with when a vibe draws an outline. "auto" follows the ground.
    readonly property color edge: {
        switch (Config.appearance.edge) {
        case "ink":
            return root.ink;
        case "accent":
            return root.accent;
        case "black":
            return root.ink0;
        case "soft":
            return root.alpha(root.ink, root.light ? 0.11 : 0.13);
        default:
            return root.light ? root.alpha(root.ink, 0.85) : root.alpha(root.ink, 0.28);
        }
    }
    // The block a hard shadow is made of, and the glow's colour.
    readonly property color shadowHard: root.light ? root.alpha(root.ink0, 0.92) : (Config.appearance.edge === "accent" ? root.alpha(root.accentDeep, 0.95) : root.alpha(root.ink0, 0.9))
    readonly property color glow: Config.appearance.edge === "ink" ? root.ink : root.accent

    readonly property color success: root.readable("#3ddc84", root.surface, 4.5)
    readonly property color warning: root.readable("#ffb300", root.surface, 4.5)
    readonly property color danger: root.readable("#ff5566", root.surface, 4.5)

    // ── the soft looks' tone (VISUALS → SOFT TONE): the colour of every
    // round pill — the soft lock, the soft widgets, a TONE bar or frame.
    // By default the accent's own deep shade, so a pink accent gives plum
    // pills and a peach one warm brown ones.
    readonly property color tone: {
        switch (Config.appearance.softTone) {
        case "surface":
            return root.surfaceHigh;
        case "black":
            return Qt.hsla(root.hue, 0.06, 0.05 + root.lift * 0.4, 1);
        default:
            return Qt.hsla(root.accent.hslHue, Math.min(0.6, root.accent.hslSaturation * 0.42 * Math.max(0, Math.min(2, Config.appearance.softToneStrength))), Math.max(0.04, Math.min(0.4, Config.appearance.softToneLight)) + root.lift * 0.5, 1);
        }
    }
    readonly property color toneHigh: Qt.hsla(root.tone.hslHue, root.tone.hslSaturation * 0.92, Math.min(0.6, root.tone.hslLightness + 0.06), 1)

    // TASKBAR → BAR COLOUR and → FRAME COLOUR (alpha is the caller's).
    readonly property color ink0: Qt.hsla(root.hue, 0.06, 0.04 + root.lift * 0.4, 1)
    readonly property color barBase: Config.bar.colour === "tone" ? root.tone : (Config.bar.colour === "black" ? root.ink0 : root.surface)
    readonly property color frameBase: {
        switch (Config.bar.frameColour) {
        case "tone":
            return root.tone;
        case "black":
            return root.ink0;
        case "accent":
            return root.accentDeep;
        default:
            return root.barBase;
        }
    }

    readonly property color panel: alpha(surface, Config.appearance.transparency)
    readonly property color panelHigh: alpha(surfaceHigh, Math.min(1, Config.appearance.transparency + 0.08))

    // ------------------------------------------------------------------ extract
    property string sourceImage: Config.wallpaper.current

    ColorQuantizer {
        id: quantizer

        source: root.sourceImage ? Qt.resolvedUrl("file://" + root.sourceImage) : ""
        depth: 4
        rescaleSize: 96

        onColorsChanged: root.recompute()
    }

    // MANUAL → WALLPAPER must pick the wallpaper's accent up at once, not
    // sit on the fallback red until the next wallpaper change.
    Connections {
        target: Config.appearance
        function onAccentSourceChanged(): void {
            root.recompute();
        }
    }

    function recompute(): void {
        if (Config.appearance.accentSource !== "wallpaper")
            return;

        const list = quantizer.colors;
        if (!list || list.length === 0) {
            root.rawAccent = root.fallback;
            return;
        }

        let best = null;
        let bestScore = -1;
        for (let i = 0; i < list.length; i++) {
            const c = list[i];
            const s = c.hslSaturation;
            const l = c.hslLightness;
            // Prefer colour that is present and mid-bright. The exponent used to
            // be 1.35, which chased the single most saturated pixel in the image
            // and produced accents far louder than the wallpaper looked.
            const score = Math.pow(s, 0.85) * (1.0 - Math.abs(0.58 - l) * 1.15);
            if (score > bestScore) {
                bestScore = score;
                best = c;
            }
        }

        if (!best || bestScore < 0.03) {
            root.rawAccent = root.fallback;
            return;
        }

        // Land it in a range that reads as confident rather than neon, and
        // bright enough to sit on a dark panel. The old floor was 0.44, which is
        // where "a bit dark" came from.
        root.rawAccent = Qt.hsla(best.hslHue, Math.max(0.42, Math.min(0.92, best.hslSaturation * 1.02)), Math.max(0.52, Math.min(0.68, best.hslLightness + 0.06)), 1);
    }

    Timer {
        running: true
        interval: 1
        onTriggered: root.recompute()
    }

    // ══════════════════════════════════════════════════════════ the palette file
    //  The little terminal programs on the desktop are not QML and cannot read
    //  any of this, so the finished palette is written out as plain JSON for
    //  them. They watch its timestamp, which means changing wallpaper
    //  recolours the clock in the corner without restarting anything.
    readonly property string palettePath: `${Quickshell.env("HOME")}/.config/velvet/palette.json`

    readonly property var paletteSnapshot: [root.accent, root.accentAlt, root.ink, root.inkDim, root.surface, root.paper]

    onPaletteSnapshotChanged: paletteWrite.restart()

    Timer {
        id: paletteWrite

        interval: 400
        onTriggered: {
            const body = {
                accent: `${root.accent}`,
                accentAlt: `${root.accentAlt}`,
                ink: `${root.ink}`,
                inkDim: `${root.inkDim}`,
                surface: `${root.surface}`,
                paper: `${root.paper}`
            };
            paletteFile.setText(JSON.stringify(body, null, 1));
        }
    }

    FileView {
        id: paletteFile

        path: root.palettePath
        printErrors: false
    }
}
