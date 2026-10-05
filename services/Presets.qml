//  VELVET  ·  services/Presets.qml
//  LOOKS — whole-shell presets, one click each (SETTINGS → LOOKS).
//
//  A look is a list of ordinary settings: the palette, the type, the bar
//  and its frame, the lock, the music along the edge, the widgets' style.
//  Applying one writes exactly those settings — nothing else, nothing
//  hidden — so every part of it can be tuned afterwards in its own row.
//
//  The first look you apply remembers how the shell looked BEFORE (every
//  key any look can touch), on disk, so BACK TO YOUR OWN LOOK always
//  returns to your setup — even after trying three looks in a row or a
//  restart in between. KEEP forgets that memory and makes the look yours.
//
//  COLOURS: with "use the look's colours" off, a look leaves the palette
//  alone and the shell keeps following your wallpaper.
//
//  From a terminal:  qs -c velvet ipc call looks apply sakura
//                    qs -c velvet ipc call looks undo
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string path: `${Quickshell.env("HOME")}/.config/velvet/looks-before.json`

    // What the shell looked like before the first look was put on, and
    // which look is on now ("" = none since the last KEEP / BACK).
    property var before: null
    property string applied: ""
    property bool loaded: false
    // Whether a look brings its own palette (SETTINGS → LOOKS → COLOURS).
    property bool withColours: true

    readonly property bool canUndo: root.before !== null

    // ────────────────────────────────────────────────────────── the looks
    // The shared soft base: round upright type, no Persona tilt or print
    // dots, a clean strip for a bar and the SOFT lock.
    readonly property var softBase: ({
            "appearance.typeStyle": "soft",
            "appearance.fontDisplay": "auto",
            "appearance.fontBody": "auto",
            "appearance.skew": 0,
            "appearance.halftone": false,
            "appearance.sharpCorners": false,
            "appearance.roundingScale": 1.3,
            "bar.style": "clean",
            "lock.look": "soft",
            "lock.softPower": true,
            "lock.softStatus": true,
            "lock.softMedia": true,
            "lock.softEdit": true
        })

    // The house values of everything a VIBE turns: every look starts from
    // these, so putting a plain look on after a vibe really takes the vibe off.
    readonly property var vibeDefaults: ({
            "appearance.shape": "slash",
            "appearance.outline": 0,
            "appearance.edge": "auto",
            "appearance.shadow": "none",
            "appearance.shadowSize": 0,
            "appearance.ground": "dark",
            "appearance.caps": "upper",
            "appearance.motion": "punchy",
            "appearance.scanlines": 0,
            "appearance.backdrop": "persona",
            "appearance.skin": "persona",
            "appearance.vibe": "",
            "appearance.groundColour": "auto",
            "sfx.pack": "velvet",
            // THIS LOOK: the shared dials start from their designed values
            "appearance.depth": 1.0,
            "appearance.gloss": 1.0,
            "appearance.patternStrength": 1.0,
            "appearance.glassFrost": 1.0,
            "appearance.glassSmoke": 0.24,
            "appearance.glassRim": 0.55,
            "appearance.auroraStrength": 1.0,
            "appearance.auroraPalette": "violet",
            "appearance.neuLight": "top-left",
            "appearance.clayTint": "accent",
            "appearance.cleanRows": "lines",
            "appearance.cleanSide": "tinted",
            "lock.vClock": "auto",
            "lock.vSeconds": false,
            "lock.vDate": "long",
            "lock.vScale": 1.0,
            "lock.vMask": "dots",
            "lock.vHello": "",
            "lock.vUser": true,
            "lock.vInfo": true,
            "lock.vMedia": false,
            "lock.vWeather": false,
            "lock.vBlur": "auto",
            "lock.vDim": "auto",
            "lock.vEntrance": "fade",
            "lock.vHints": true,
            "lock.vFx": "none",
            "lock.vFxStrength": 1.0,
            "lock.vGlow": false,
            "lock.vViz": false,
            "lock.vVizEdge": "bottom",
            "lock.vVizStyle": "wave",
            "lock.vVizReach": 0.09,
            "lock.vClockColour": "auto",
            "lock.vClockFont": "",
            "appearance.launcherStyle": "auto",
            "appearance.notifStyle": "auto",
            "appearance.osdStyle": "auto",
            "appearance.sessionStyle": "auto"
        })

    // The keys THIS LOOK adds: they travel with a saved look and BACK restores them.
    readonly property var tuneKeys: ["appearance.depth", "appearance.gloss", "appearance.patternStrength", "appearance.glassFrost", "appearance.glassSmoke", "appearance.glassRim", "appearance.auroraStrength", "appearance.auroraPalette", "appearance.neuLight", "appearance.clayTint", "appearance.cleanRows", "appearance.cleanSide", "lock.vClock", "lock.vSeconds", "lock.vDate", "lock.vScale", "lock.vMask", "lock.vHello", "lock.vUser", "lock.vInfo", "lock.vMedia", "lock.vWeather", "lock.vBlur", "lock.vDim", "lock.vEntrance", "lock.vHints", "lock.vFx", "lock.vFxStrength", "lock.vGlow", "lock.vViz", "lock.vVizEdge", "lock.vVizStyle", "lock.vVizReach", "lock.vClockColour", "lock.vClockFont", "appearance.launcherStyle", "appearance.notifStyle", "appearance.osdStyle", "appearance.sessionStyle"]

    // What each look remembers of your tuning: { id: { key: value } }. Only
    // what differs from how the look was designed is kept.
    property var tunes: ({})
    // Your names for the looks ({ id: "NAME" }); a saved look keeps its name in
    // its own entry. LOOKS → click a name to change it.
    property var names: ({})

    function nameOf(look: var): string {
        if (!look)
            return "";
        if (look.custom === true)
            return look.name ?? "";
        const own = root.names[look.id];
        return own ? own : (look.name ?? "");
    }

    function rename(id: string, name: string): bool {
        const t = String(name ?? "").trim().slice(0, 32);
        const i = root.custom.findIndex(l => l.id === id);
        if (i >= 0) {
            if (t === "")
                return false;
            const next = root.custom.slice();
            next[i] = Object.assign({}, next[i], {
                name: t.toUpperCase()
            });
            root.custom = next;
            root.persistCustom();
            return true;
        }
        if (!root.find(id))
            return false;
        const n = Object.assign({}, root.names);
        if (t === "")
            delete n[id];
        else
            n[id] = t.toUpperCase();
        root.names = n;
        root.persist();
        return true;
    }

    readonly property var vibeOwned: ["hypr.rounding", "hypr.borderSize", "hypr.gapsIn", "hypr.gapsOut", "hypr.manageBorders"]

    // Your own looks (SAVE WHAT I HAVE AS A LOOK), kept in looks-custom.json.
    property var custom: []
    readonly property string customPath: `${Quickshell.env("HOME")}/.config/velvet/looks-custom.json`

    // Every card on the page: the built-in looks, then yours.
    readonly property var looks: root.builtIn.concat(root.winLooks, root.custom)

    // The cards of the VIBES section: every vibe once — WINDOWS as the
    // edition you chose last.
    readonly property var vibeCards: root.builtIn.filter(l => l.vibe === true).concat([root.winCurrent])

    // Settings no built-in look spells out but every look should carry, so
    // BACK restores them and a saved look remembers them.
    readonly property var extraKeys: ["bar.frameConnect", "bar.frameColour", "bar.frameOpacity", "bar.frameShadow", "bar.frameOutline", "bar.colour", "appearance.softTone", "appearance.softToneStrength", "appearance.softToneLight", "lock.clockColours", "lock.visualizerDensity", "services.audioWaveDensity", "lock.passwordShapes", "lock.ambientAfter", "lyrics.mode", "lyrics.enabled", "wallpaper.livingOpacity", "appearance.accentSaturation", "lock.softPlace", "lock.softStyle", "lock.softAnimation", "lock.softStagger", "lock.softGlide", "lock.softShapeSpin", "lock.softDigitMotion", "lock.softHoverMorph", "lock.softOpacity", "wallpaper.shapeHoverMorph", "appearance.shape", "appearance.outline", "appearance.edge", "appearance.shadow", "appearance.shadowSize", "appearance.ground", "appearance.caps", "appearance.motion", "appearance.scanlines", "appearance.backdrop", "appearance.skin", "appearance.vibe", "appearance.winVersion", "appearance.typeStyle", "sfx.pack", "appearance.depth", "appearance.gloss", "appearance.patternStrength", "appearance.glassFrost", "appearance.glassSmoke", "appearance.glassRim", "appearance.auroraStrength", "appearance.auroraPalette", "appearance.neuLight", "appearance.clayTint", "appearance.cleanRows", "appearance.cleanSide", "lock.vClock", "lock.vSeconds", "lock.vDate", "lock.vScale", "lock.vMask", "lock.vHello", "lock.vUser", "lock.vInfo", "lock.vMedia", "lock.vWeather", "lock.vBlur", "lock.vDim", "lock.vEntrance", "lock.vHints", "lock.vFx", "lock.vFxStrength", "lock.vGlow", "lock.vViz", "lock.vVizEdge", "lock.vVizStyle", "lock.vVizReach", "lock.vClockColour", "lock.vClockFont", "appearance.launcherStyle", "appearance.notifStyle", "appearance.osdStyle", "appearance.sessionStyle"]
    readonly property var colourKeys: ["appearance.accentSource", "appearance.accentColour", "appearance.accentSaturation", "appearance.surfaceTint", "appearance.surfaceLift", "appearance.transparency", "appearance.groundColour"]

    // ────────────────────────────────────────────────── the WINDOWS look
    //  One vibe in five editions (SETTINGS → VISUALS → VIBE → WINDOWS VERSION,
    //  or the strip under the vibes on the LOOKS tab). Each edition is a
    //  look of its own — a different shape, ground, accent, taskbar and
    //  settings window — and the card on the LOOKS tab always shows the one
    //  you chose last.
    readonly property var winIds: ["95", "xp", "7", "10", "11"]

    readonly property var winBase: ({
            "appearance.vibe": "windows",
            "appearance.skin": "win",
            "appearance.typeStyle": "win",
            "appearance.skew": 0,
            "appearance.halftone": false,
            "appearance.sharpCorners": false,
            "appearance.roundingScale": 1.0,
            "appearance.caps": "upper",
            "appearance.scanlines": 0,
            "appearance.backdrop": "plain",
            "bar.style": "clean",
            "bar.position": "bottom",
            "bar.margin": 0,
            "bar.rounding": 0,
            "bar.padding": 5,
            "bar.frame": false,
            "bar.colour": "surface",
            "bar.layout": ["logo", "workspaces", "activeWindow", "spacer", "tray", "statusIcons", "clock", "power"],
            "map.islandTheme": "dark",
            "map.islandAccent": true,
            "services.audioReactive": true,
            "services.audioWave": false,
            "lyrics.mode": "stack",
            "lyrics.blocky": false,
            "lyrics.shadow": false,
            "wallpaper.livingChips": "soft",
            "lock.look": "vibe",
            "hypr.manageBorders": true
        })

    readonly property var winSpecs: ({
            "95": {
                name: "WINDOWS 95",
                by: "grey, bevelled and square",
                blurb: "1995: grey boxes with a raised bevel, a navy title bar, a Start button in the corner and a plain teal desktop. Chunky, flat colours, nothing soft.",
                accent: "#000080",
                parts: ["BEVELLED BOXES", "NAVY TITLE BAR", "START BUTTON", "GREY TASKBAR", "SQUARE EVERYTHING"],
                mood: "win",
                shape: "bevel",
                outline: 0,
                edgeHex: "#000000",
                shadow: "none",
                shadowSize: 0,
                swatch: { paper: "#008080", surface: "#c0c0c0", ink: "#000000", accent: "#000080" },
                backdrop: "plain",
                barEdge: "bottom",
                colours: {
                    "appearance.accentSource": "manual",
                    "appearance.accentColour": "#000080",
                    "appearance.groundColour": "#c0c0c0",
                    "appearance.surfaceTint": 0.0,
                    "appearance.surfaceLift": 0.2,
                    "appearance.transparency": 1.0,
                    "appearance.accentSaturation": 1.0
                },
                settings: {
                    "appearance.shape": "bevel",
                    "appearance.outline": 0,
                    "appearance.edge": "ink",
                    "appearance.shadow": "none",
                    "appearance.shadowSize": 0,
                    "appearance.ground": "light",
                    "appearance.motion": "crisp",
                    "appearance.sharpCorners": true,
                    "sfx.pack": "windows",
                    "bar.thickness": 36,
                    "bar.opacity": 1,
                    "bar.blur": false,
                    "bar.workspaces.style": "numbers",
                    "wallpaper.livingOpacity": 1.0,
                    "hypr.rounding": 0,
                    "hypr.borderSize": 3,
                    "hypr.gapsIn": 0,
                    "hypr.gapsOut": 0
                }
            },
            "xp": {
                name: "WINDOWS XP",
                by: "luna blue and green",
                blurb: "2001: a bright blue title bar, round buttons, a green Start button, a cream window face and the green hill behind it. Friendly and colourful.",
                accent: "#2a5fd3",
                parts: ["LUNA BLUE TITLE BAR", "GREEN START BUTTON", "ROUND BUTTONS", "CREAM WINDOW FACE", "BLISS BACKDROP"],
                mood: "win",
                shape: "round",
                outline: 1,
                edgeHex: "#0b3fb8",
                shadow: "soft",
                shadowSize: 6,
                swatch: { paper: "#5a95e0", surface: "#ece9d8", ink: "#161616", accent: "#2a5fd3", accent2: "#3c9a2f" },
                backdrop: "plain",
                barEdge: "bottom",
                colours: {
                    "appearance.accentSource": "manual",
                    "appearance.accentColour": "#2a5fd3",
                    "appearance.groundColour": "#ece9d8",
                    "appearance.surfaceTint": 0.22,
                    "appearance.surfaceLift": 0.0,
                    "appearance.transparency": 1.0,
                    "appearance.accentSaturation": 1.0
                },
                settings: {
                    "appearance.shape": "round",
                    "appearance.outline": 1,
                    "appearance.edge": "accent",
                    "appearance.shadow": "soft",
                    "appearance.shadowSize": 6,
                    "appearance.ground": "light",
                    "appearance.motion": "smooth",
                    "sfx.pack": "windows",
                    "bar.thickness": 40,
                    "bar.opacity": 1,
                    "bar.blur": false,
                    "bar.workspaces.style": "numbers",
                    "wallpaper.livingOpacity": 1.0,
                    "hypr.rounding": 8,
                    "hypr.borderSize": 3,
                    "hypr.gapsIn": 2,
                    "hypr.gapsOut": 3
                }
            },
            "7": {
                name: "WINDOWS 7",
                by: "aero glass",
                blurb: "2009: glass frames with a soft shine, a glossy blue Start orb, a dark glass taskbar, a light-blue hover on everything and big soft shadows. Shiny, but friendly.",
                accent: "#3a8ee6",
                parts: ["AERO GLASS FRAMES", "START ORB", "GLASS TASKBAR", "BLUE HOVER GLOW", "SOFT SHADOWS"],
                mood: "win",
                shape: "round",
                outline: 1,
                edgeHex: "#cfe3fa",
                shadow: "soft",
                shadowSize: 12,
                swatch: { paper: "#1d4e89", surface: "#4a78b4", ink: "#ffffff", accent: "#3a8ee6" },
                backdrop: "plain",
                barEdge: "bottom",
                colours: {
                    "appearance.accentSource": "manual",
                    "appearance.accentColour": "#3a8ee6",
                    "appearance.groundColour": "#1c3558",
                    "appearance.surfaceTint": 0.5,
                    "appearance.surfaceLift": 0.05,
                    "appearance.transparency": 0.74,
                    "appearance.accentSaturation": 1.0
                },
                settings: {
                    "appearance.shape": "round",
                    "appearance.outline": 1,
                    "appearance.edge": "auto",
                    "appearance.shadow": "soft",
                    "appearance.shadowSize": 12,
                    "appearance.ground": "dark",
                    "appearance.motion": "smooth",
                    "sfx.pack": "windows",
                    "bar.thickness": 42,
                    "bar.opacity": 0.64,
                    "bar.blur": true,
                    "bar.workspaces.style": "pills",
                    "wallpaper.livingOpacity": 0.8,
                    "hypr.rounding": 6,
                    "hypr.borderSize": 1,
                    "hypr.gapsIn": 3,
                    "hypr.gapsOut": 4
                }
            },
            "10": {
                name: "WINDOWS 10",
                by: "flat and sharp",
                blurb: "2015: flat panels with sharp corners, a dark taskbar, the accent only on what is active, light thin type and a home of plain tiles.",
                accent: "#0078d7",
                parts: ["FLAT SHARP PANELS", "DARK TASKBAR", "ACCENT ON ACTIVE", "TILE HOME", "THIN TYPE"],
                mood: "win",
                shape: "square",
                outline: 0,
                edgeHex: "#3a3a3a",
                shadow: "none",
                shadowSize: 0,
                swatch: { paper: "#1c1c1c", surface: "#2b2b2b", ink: "#ffffff", accent: "#0078d7" },
                backdrop: "plain",
                barEdge: "bottom",
                colours: {
                    "appearance.accentSource": "manual",
                    "appearance.accentColour": "#0078d7",
                    "appearance.groundColour": "#000000",
                    "appearance.surfaceTint": 0.0,
                    "appearance.surfaceLift": 0.06,
                    "appearance.transparency": 0.95,
                    "appearance.accentSaturation": 1.0
                },
                settings: {
                    "appearance.shape": "square",
                    "appearance.outline": 0,
                    "appearance.edge": "soft",
                    "appearance.shadow": "none",
                    "appearance.shadowSize": 0,
                    "appearance.ground": "dark",
                    "appearance.motion": "crisp",
                    "appearance.sharpCorners": true,
                    "sfx.pack": "windows",
                    "bar.thickness": 40,
                    "bar.opacity": 0.95,
                    "bar.blur": false,
                    "bar.workspaces.style": "pills",
                    "wallpaper.livingOpacity": 0.9,
                    "hypr.rounding": 0,
                    "hypr.borderSize": 1,
                    "hypr.gapsIn": 2,
                    "hypr.gapsOut": 2
                }
            },
            "11": {
                name: "WINDOWS 11",
                by: "mica and rounded",
                blurb: "2021: soft rounded cards on a light mica ground, hairline edges, gentle shadows, a calm taskbar with room around it and a pill-shaped switch for everything.",
                accent: "#0067c0",
                parts: ["ROUNDED CARDS", "MICA GROUND", "HAIRLINE EDGES", "SOFT SHADOWS", "PILL SWITCHES"],
                mood: "win",
                shape: "round",
                outline: 1,
                edgeHex: "#dfe3ea",
                shadow: "soft",
                shadowSize: 10,
                swatch: { paper: "#e3e8f2", surface: "#fafbfd", ink: "#1b1b1b", accent: "#0067c0" },
                backdrop: "plain",
                barEdge: "bottom",
                colours: {
                    "appearance.accentSource": "manual",
                    "appearance.accentColour": "#0067c0",
                    "appearance.groundColour": "#c4d0ea",
                    "appearance.surfaceTint": 0.1,
                    "appearance.surfaceLift": 0.0,
                    "appearance.transparency": 0.94,
                    "appearance.accentSaturation": 1.0
                },
                settings: {
                    "appearance.shape": "round",
                    "appearance.outline": 1,
                    "appearance.edge": "soft",
                    "appearance.shadow": "soft",
                    "appearance.shadowSize": 10,
                    "appearance.ground": "light",
                    "appearance.motion": "smooth",
                    "sfx.pack": "windows",
                    "bar.thickness": 46,
                    "bar.opacity": 0.9,
                    "bar.blur": true,
                    "bar.workspaces.style": "dots",
                    "wallpaper.livingOpacity": 0.96,
                    "hypr.rounding": 8,
                    "hypr.borderSize": 1,
                    "hypr.gapsIn": 6,
                    "hypr.gapsOut": 10
                }
            }
        })

    function winLook(v: string): var {
        const s = root.winSpecs[v];
        return {
            id: `win${v}`,
            vibe: true,
            family: "windows",
            version: v,
            name: s.name,
            by: s.by,
            blurb: s.blurb,
            accent: s.accent,
            parts: s.parts,
            mood: s.mood,
            shape: s.shape,
            outline: s.outline,
            edgeHex: s.edgeHex,
            shadow: s.shadow,
            shadowSize: s.shadowSize,
            swatch: s.swatch,
            backdrop: s.backdrop,
            scanlines: 0,
            barEdge: s.barEdge,
            waveEdge: "",
            waveStyle: "hairline",
            clock: "none",
            colours: s.colours,
            settings: Object.assign({}, root.winBase, s.settings, { "appearance.winVersion": v })
        };
    }

    readonly property var winLooks: root.winIds.map(v => root.winLook(v))
    // The edition the WINDOWS card on the LOOKS tab shows.
    readonly property var winCurrent: root.winLooks[Math.max(0, root.winIds.indexOf(Config.appearance.winVersion))]

    // ───────────────────────────────────────────────────── VELVET, the original
    //  Not a look: the shell as it was made. Everything below dresses it, and
    //  putting this on takes every look off again (the settings a look never
    //  touches stay yours). It lives next to the looks, never among them.
    readonly property var original: ({
        id: "velvet",
        original: true,
        name: "VELVET",
        by: "the original · not a look",
        blurb: "Velvet as it was made: heavy italic Persona type, the tilt, the halftone print, the accent wedge on a left bar, the FLUID lock, colours from your wallpaper. Every look on this page dresses it — and this takes everything off again.",
        accent: "#e4002b",
        parts: ["PERSONA TYPE", "LEFT BAR", "FLUID LOCK", "WALLPAPER COLOURS"],
        barEdge: "left",
        waveEdge: "",
        waveStyle: "hairline",
        clock: "none",
        house: true,
        colours: {
            "appearance.accentSource": "wallpaper",
            "appearance.surfaceTint": 0.22,
            "appearance.surfaceLift": 0.035,
            "appearance.transparency": 0.82
        },
        settings: {
            "appearance.typeStyle": "persona",
            "appearance.skew": 4.0,
            "appearance.halftone": true,
            "appearance.roundingScale": 1.0,
            "bar.style": "velvet",
            "bar.position": "left",
            "bar.thickness": 46,
            "bar.margin": 8,
            "bar.rounding": 18,
            "bar.padding": 8,
            "bar.opacity": 0.82,
            "bar.frame": false,
            "bar.colour": "surface",
            "bar.workspaces.style": "slash",
            "bar.layout": ["logo", "workspaces", "spacer", "activeWindow", "spacer", "tray", "clock", "statusIcons", "power"],
            "services.audioWaveStyle": "hairline",
            "lyrics.mode": "word",
            "wallpaper.livingChips": "glass",
            "wallpaper.livingOpacity": 0.72,
            "lock.look": "fluid",
            "lock.clockShape": "none",
            "lock.clockFace": ""
        }
    })

    readonly property var builtIn: [
        {
            id: "arcade",
            vibe: true,
            name: "ARCADE",
            by: "retro game menu · yellow on navy",
            blurb: "A tidy retro game menu: pixel headings, flat cards with a thin dark edge, warm yellow on deep navy. Playful, but calm.",
            accent: "#f4c542",
            parts: ["GAME-MENU SETTINGS", "PIXEL HEADINGS", "FLAT CARDS", "BOTTOM BAR", "ARCADE CLICKS"],
            mood: "arcade",
            shape: "pixel",
            outline: 2,
            edgeHex: "#0a0d2a",
            shadow: "hard",
            shadowSize: 3,
            swatch: { paper: "#151a45", surface: "#212868", ink: "#f6f1de", accent: "#f4c542", accent2: "#ff6f9f" },
            backdrop: "plain",
            scanlines: 0,
            barEdge: "bottom",
            waveEdge: "bottom",
            waveStyle: "bars",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#f4c542",
                "appearance.groundColour": "#3a4398",
                "appearance.surfaceTint": 0.55,
                "appearance.surfaceLift": 0.06,
                "appearance.transparency": 1.0,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "arcade",
                "appearance.skin": "arcade",
                "appearance.typeStyle": "arcade",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": false,
                "appearance.roundingScale": 1.0,
                "appearance.shape": "pixel",
                "appearance.outline": 2,
                "appearance.edge": "black",
                "appearance.shadow": "hard",
                "appearance.shadowSize": 3,
                "appearance.ground": "dark",
                "appearance.caps": "upper",
                "appearance.motion": "punchy",
                "appearance.scanlines": 0,
                "appearance.backdrop": "plain",
                "sfx.pack": "arcade",
                "bar.style": "clean",
                "bar.position": "bottom",
                "bar.thickness": 46,
                "bar.margin": 8,
                "bar.rounding": 0,
                "bar.padding": 6,
                "bar.opacity": 1,
                "bar.frame": false,
                "bar.colour": "surface",
                "bar.workspaces.style": "slash",
                "bar.layout": ["logo", "workspaces", "spacer", "media", "spacer", "statusIcons", "clock", "power"],
                "map.islandTheme": "dark",
                "map.islandAccent": true,
                "services.audioReactive": true,
                "services.audioWave": true,
                "services.audioWaveStyle": "bars",
                "services.audioWaveEdge": "bottom",
                "services.audioWaveReach": 0.08,
                "lyrics.mode": "line",
                "lyrics.blocky": false,
                "lyrics.shadow": false,
                "wallpaper.livingChips": "glass",
                "wallpaper.livingOpacity": 0.95,
                "lock.vFx": "stars",
                "lock.vEntrance": "drop",
                "lock.vViz": true,
                "lock.vVizStyle": "bars",
                "lock.vVizEdge": "bottom",
                "lock.look": "vibe",
                "hypr.rounding": 0,
                "hypr.borderSize": 2,
                "hypr.gapsIn": 5,
                "hypr.gapsOut": 10,
                "hypr.manageBorders": true
            }
        },
        {
            id: "cyber",
            vibe: true,
            name: "CYBER",
            by: "quiet HUD · cyan on midnight",
            blurb: "A sci-fi interface kept clean: notched panels with a hairline edge, light wide-set type, cyan only where something is active. No glow, no noise.",
            accent: "#3bd3e6",
            parts: ["HUD SETTINGS", "NOTCHED PANELS", "HAIRLINE EDGES", "WIDE LIGHT TYPE", "CYBER CLICKS"],
            mood: "tech",
            shape: "notch",
            outline: 1,
            edgeHex: "#2a4a63",
            shadow: "none",
            shadowSize: 0,
            swatch: { paper: "#060d1a", surface: "#0c1a2e", ink: "#dbeaf2", accent: "#3bd3e6", accent2: "#ff5ec8" },
            backdrop: "plain",
            scanlines: 0,
            barEdge: "top",
            waveEdge: "top",
            waveStyle: "hairline",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#3bd3e6",
                "appearance.groundColour": "#0a1830",
                "appearance.surfaceTint": 0.55,
                "appearance.surfaceLift": 0.03,
                "appearance.transparency": 0.94,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "cyber",
                "appearance.skin": "hud",
                "appearance.typeStyle": "tech",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": false,
                "appearance.roundingScale": 1.0,
                "appearance.shape": "notch",
                "appearance.outline": 1,
                "appearance.edge": "auto",
                "appearance.shadow": "none",
                "appearance.shadowSize": 0,
                "appearance.ground": "dark",
                "appearance.caps": "upper",
                "appearance.motion": "crisp",
                "appearance.scanlines": 0,
                "appearance.backdrop": "plain",
                "sfx.pack": "cyber",
                "bar.style": "clean",
                "bar.position": "top",
                "bar.thickness": 34,
                "bar.margin": 0,
                "bar.rounding": 0,
                "bar.padding": 6,
                "bar.opacity": 0.92,
                "bar.frame": true,
                "bar.colour": "surface",
                "bar.workspaces.style": "numbers",
                "bar.layout": ["logo", "workspaces", "spacer", "activeWindow", "spacer", "tray", "clock", "statusIcons", "power"],
                "map.islandTheme": "glass",
                "map.islandAccent": true,
                "services.audioReactive": true,
                "services.audioWave": true,
                "services.audioWaveStyle": "hairline",
                "services.audioWaveEdge": "bottom",
                "services.audioWaveReach": 0.08,
                "lyrics.mode": "line",
                "lyrics.blocky": false,
                "lyrics.shadow": false,
                "wallpaper.livingChips": "glass",
                "wallpaper.livingOpacity": 0.8,
                "lock.vFx": "scanlines",
                "lock.vEntrance": "glitch",
                "lock.vGlow": true,
                "lock.vViz": true,
                "lock.vVizStyle": "bars",
                "lock.vVizEdge": "bottom",
                "lock.vSeconds": true,
                "lock.look": "vibe",
                "hypr.rounding": 0,
                "hypr.borderSize": 1,
                "hypr.gapsIn": 4,
                "hypr.gapsOut": 8,
                "hypr.manageBorders": true
            }
        },
        {
            id: "terminal",
            vibe: true,
            name: "TERMINAL",
            by: "mint on near-black",
            blurb: "A modern terminal: everything lowercase in monospace, square boxes with a one-pixel line, a statusline for a bar and one soft green. No CRT tricks.",
            accent: "#7be0a6",
            parts: ["SETTINGS AS A TERMINAL", "MONOSPACE", "LOWERCASE", "STATUSLINE BAR", "KEY CLICKS"],
            mood: "mono",
            shape: "square",
            outline: 1,
            edgeHex: "#2b3a31",
            shadow: "none",
            shadowSize: 0,
            swatch: { paper: "#090c0a", surface: "#0f1511", ink: "#cfe9d8", accent: "#7be0a6" },
            backdrop: "plain",
            scanlines: 0,
            barEdge: "bottom",
            waveEdge: "bottom",
            waveStyle: "bars",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#7be0a6",
                "appearance.groundColour": "#2f6b4a",
                "appearance.surfaceTint": 0.3,
                "appearance.surfaceLift": 0.01,
                "appearance.transparency": 0.97,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "terminal",
                "appearance.skin": "console",
                "appearance.typeStyle": "mono",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": true,
                "appearance.roundingScale": 1.0,
                "appearance.shape": "square",
                "appearance.outline": 1,
                "appearance.edge": "auto",
                "appearance.shadow": "none",
                "appearance.shadowSize": 0,
                "appearance.ground": "dark",
                "appearance.caps": "lower",
                "appearance.motion": "crisp",
                "appearance.scanlines": 0,
                "appearance.backdrop": "plain",
                "sfx.pack": "terminal",
                "bar.style": "clean",
                "bar.position": "bottom",
                "bar.thickness": 26,
                "bar.margin": 0,
                "bar.rounding": 0,
                "bar.padding": 4,
                "bar.opacity": 1,
                "bar.frame": false,
                "bar.colour": "black",
                "bar.workspaces.style": "numbers",
                "bar.layout": ["workspaces", "activeWindow", "spacer", "resources", "clock"],
                "map.islandTheme": "dark",
                "map.islandAccent": true,
                "services.audioReactive": true,
                "services.audioWave": true,
                "services.audioWaveStyle": "bars",
                "services.audioWaveEdge": "bottom",
                "services.audioWaveReach": 0.05,
                "lyrics.mode": "line",
                "lyrics.blocky": false,
                "lyrics.shadow": false,
                "wallpaper.livingChips": "ink",
                "wallpaper.livingOpacity": 0.92,
                "lock.vFx": "scanlines",
                "lock.vEntrance": "glitch",
                "lock.vSeconds": true,
                "lock.look": "vibe",
                "hypr.rounding": 0,
                "hypr.borderSize": 1,
                "hypr.gapsIn": 3,
                "hypr.gapsOut": 6,
                "hypr.manageBorders": true
            }
        },
        {
            id: "paper",
            vibe: true,
            name: "PAPER",
            by: "an editorial page · ink on cream",
            blurb: "A printed page: warm paper, dark ink, a serif voice, square cards with a hairline rule and no shadows. Terracotta is the only colour.",
            accent: "#c4502f",
            parts: ["SETTINGS AS A MAGAZINE", "LIGHT GROUND", "SERIF TYPE", "HAIRLINE RULES", "PAPER CLICKS"],
            mood: "serif",
            shape: "square",
            outline: 1,
            edgeHex: "#3a3126",
            shadow: "none",
            shadowSize: 0,
            swatch: { paper: "#ece1c8", surface: "#f6efdc", ink: "#241d12", accent: "#c4502f" },
            backdrop: "plain",
            scanlines: 0,
            barEdge: "top",
            waveEdge: "",
            waveStyle: "hairline",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#c4502f",
                "appearance.groundColour": "#e9d9b4",
                "appearance.surfaceTint": 0.45,
                "appearance.surfaceLift": 0.0,
                "appearance.transparency": 1.0,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "paper",
                "appearance.skin": "ledger",
                "appearance.typeStyle": "serif",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": true,
                "appearance.roundingScale": 1.0,
                "appearance.shape": "square",
                "appearance.outline": 1,
                "appearance.edge": "soft",
                "appearance.shadow": "none",
                "appearance.shadowSize": 0,
                "appearance.ground": "light",
                "appearance.caps": "upper",
                "appearance.motion": "smooth",
                "appearance.scanlines": 0,
                "appearance.backdrop": "plain",
                "sfx.pack": "paper",
                "bar.style": "clean",
                "bar.position": "top",
                "bar.thickness": 38,
                "bar.margin": 0,
                "bar.rounding": 0,
                "bar.padding": 6,
                "bar.opacity": 1,
                "bar.frame": false,
                "bar.colour": "surface",
                "bar.workspaces.style": "numbers",
                "bar.layout": ["workspaces", "spacer", "activeWindow", "spacer", "tray", "statusIcons", "clock", "power"],
                "map.islandTheme": "dark",
                "map.islandAccent": false,
                "services.audioReactive": true,
                "services.audioWave": false,
                "lyrics.mode": "stack",
                "lyrics.blocky": false,
                "lyrics.shadow": false,
                "wallpaper.livingChips": "soft",
                "wallpaper.livingOpacity": 0.98,
                "lock.vFx": "grain",
                "lock.vEntrance": "rise",
                "lock.look": "vibe",
                "hypr.rounding": 0,
                "hypr.borderSize": 1,
                "hypr.gapsIn": 6,
                "hypr.gapsOut": 12,
                "hypr.manageBorders": true
            }
        },
        {
            id: "glass",
            vibe: true,
            name: "GLASSMORPHISM",
            by: "frosted glass over a glowing aurora",
            blurb: "Glassmorphism: translucent frosted panes with a bright edge and a sheen, floating over big soft clouds of violet, cyan and pink. Deep shadows under the glass, a floating bar, light airy type, slow motion.",
            accent: "#8ab4ff",
            parts: ["FROSTED GLASS PANES", "BRIGHT GLASS EDGE", "AURORA BEHIND", "DEEP SHADOWS", "FLOATING BAR", "GLASS CLICKS"],
            mood: "soft",
            shape: "round",
            outline: 1,
            edgeHex: "#ffffff",
            shadow: "soft",
            shadowSize: 16,
            swatch: { paper: "#251f58", surface: "#4a4290", ink: "#f6f4ff", accent: "#9ec1ff" },
            backdrop: "aurora",
            scanlines: 0,
            barEdge: "top",
            waveEdge: "top",
            waveStyle: "wave",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#8ab4ff",
                "appearance.groundColour": "#4a3f9c",
                "appearance.surfaceTint": 0.35,
                "appearance.surfaceLift": 0.05,
                "appearance.transparency": 0.38,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "glass",
                "appearance.skin": "glass",
                "appearance.typeStyle": "soft",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": false,
                "appearance.roundingScale": 1.5,
                "appearance.shape": "round",
                "appearance.outline": 1,
                "appearance.edge": "auto",
                "appearance.shadow": "soft",
                "appearance.shadowSize": 16,
                "appearance.ground": "dark",
                "appearance.caps": "upper",
                "appearance.motion": "smooth",
                "appearance.scanlines": 0,
                "appearance.backdrop": "aurora",
                "sfx.pack": "glass",
                "bar.style": "floating",
                "bar.position": "top",
                "bar.thickness": 42,
                "bar.margin": 10,
                "bar.rounding": 22,
                "bar.padding": 8,
                "bar.opacity": 0.55,
                "bar.blur": true,
                "bar.frame": false,
                "bar.colour": "surface",
                "bar.workspaces.style": "pills",
                "bar.layout": ["logo", "workspaces", "spacer", "media", "spacer", "tray", "statusIcons", "clock", "power"],
                "map.islandTheme": "glass",
                "map.islandAccent": true,
                "services.audioReactive": true,
                "services.audioWave": true,
                "services.audioWaveStyle": "wave",
                "services.audioWaveEdge": "top",
                "services.audioWaveReach": 0.05,
                "lyrics.mode": "stack",
                "lyrics.blocky": false,
                "lyrics.shadow": false,
                "wallpaper.livingChips": "glass",
                "wallpaper.livingOpacity": 0.55,
                "lock.vEntrance": "zoom",
                "lock.vViz": true,
                "lock.vVizStyle": "wave",
                "lock.vGlow": true,
                "lock.vFx": "stars",
                "lock.vFxStrength": 0.6,
                "lock.look": "vibe",
                "hypr.rounding": 16,
                "hypr.borderSize": 1,
                "hypr.gapsIn": 8,
                "hypr.gapsOut": 16,
                "hypr.manageBorders": true
            }
        },
        {
            id: "rpg",
            vibe: true,
            name: "RPG",
            by: "a fantasy tome · gold on leather",
            blurb: "An old role-playing menu, understated: dark leather panels, a thin gold line, a serif voice and a soft candle glow. The book is in the margins, not in your face.",
            accent: "#d2ae62",
            parts: ["SETTINGS AS A BOOK", "THIN GOLD LINES", "SERIF TYPE", "LEATHER GROUND", "RPG CLICKS"],
            mood: "serif",
            shape: "square",
            outline: 1,
            edgeHex: "#8a7440",
            shadow: "soft",
            shadowSize: 6,
            swatch: { paper: "#1a130d", surface: "#2a1f15", ink: "#efe3c8", accent: "#d2ae62" },
            backdrop: "plain",
            scanlines: 0,
            barEdge: "bottom",
            waveEdge: "",
            waveStyle: "hairline",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#d2ae62",
                "appearance.groundColour": "#5a4128",
                "appearance.surfaceTint": 0.45,
                "appearance.surfaceLift": 0.02,
                "appearance.transparency": 0.97,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "rpg",
                "appearance.skin": "tome",
                "appearance.typeStyle": "serif",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": true,
                "appearance.roundingScale": 1.0,
                "appearance.shape": "square",
                "appearance.outline": 1,
                "appearance.edge": "accent",
                "appearance.shadow": "soft",
                "appearance.shadowSize": 6,
                "appearance.ground": "dark",
                "appearance.caps": "upper",
                "appearance.motion": "smooth",
                "appearance.scanlines": 0,
                "appearance.backdrop": "plain",
                "sfx.pack": "rpg",
                "bar.style": "floating",
                "bar.position": "bottom",
                "bar.thickness": 50,
                "bar.margin": 14,
                "bar.rounding": 6,
                "bar.padding": 8,
                "bar.opacity": 0.97,
                "bar.frame": false,
                "bar.colour": "surface",
                "bar.workspaces.style": "numbers",
                "bar.layout": ["workspaces", "spacer", "media", "spacer", "statusIcons", "clock", "power"],
                "map.islandTheme": "dark",
                "map.islandAccent": true,
                "services.audioReactive": true,
                "services.audioWave": false,
                "lyrics.mode": "stack",
                "lyrics.blocky": false,
                "lyrics.shadow": false,
                "wallpaper.livingChips": "glass",
                "wallpaper.livingOpacity": 0.9,
                "lock.vFx": "embers",
                "lock.vEntrance": "rise",
                "lock.vGlow": true,
                "lock.look": "vibe",
                "hypr.rounding": 0,
                "hypr.borderSize": 1,
                "hypr.gapsIn": 4,
                "hypr.gapsOut": 10,
                "hypr.manageBorders": true
            }
        },
        {
            id: "brutal",
            vibe: true,
            name: "BRUTAL",
            by: "a plain poster · black on butter",
            blurb: "Neo-brutalism, tamed: a warm paper ground, white cards with a two-pixel black outline and a small hard shadow, a heavy sans and one coral for every button.",
            accent: "#ff6b57",
            parts: ["SETTINGS AS A POSTER", "WARM PAPER", "BLACK OUTLINES", "SMALL HARD SHADOWS", "POSTER TYPE", "THUD CLICKS"],
            mood: "block",
            shape: "square",
            outline: 2,
            edgeHex: "#0b0b0b",
            shadow: "hard",
            shadowSize: 3,
            swatch: { paper: "#f1e7c1", surface: "#fffaea", ink: "#0b0b0b", accent: "#ff6b57", accent2: "#2bd9a4" },
            backdrop: "plain",
            scanlines: 0,
            barEdge: "top",
            waveEdge: "bottom",
            waveStyle: "bars",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#ff6b57",
                "appearance.groundColour": "#f1e7c1",
                "appearance.surfaceTint": 0.4,
                "appearance.surfaceLift": 0.0,
                "appearance.transparency": 1.0,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "brutal",
                "appearance.skin": "poster",
                "appearance.typeStyle": "block",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": true,
                "appearance.roundingScale": 1.0,
                "appearance.shape": "square",
                "appearance.outline": 2,
                "appearance.edge": "black",
                "appearance.shadow": "hard",
                "appearance.shadowSize": 3,
                "appearance.ground": "light",
                "appearance.caps": "upper",
                "appearance.motion": "punchy",
                "appearance.scanlines": 0,
                "appearance.backdrop": "plain",
                "sfx.pack": "brutal",
                "bar.style": "clean",
                "bar.position": "top",
                "bar.thickness": 52,
                "bar.margin": 0,
                "bar.rounding": 0,
                "bar.padding": 8,
                "bar.opacity": 1,
                "bar.frame": false,
                "bar.colour": "black",
                "bar.workspaces.style": "numbers",
                "bar.layout": ["logo", "workspaces", "spacer", "activeWindow", "spacer", "tray", "statusIcons", "clock", "power"],
                "map.islandTheme": "dark",
                "map.islandAccent": false,
                "services.audioReactive": true,
                "services.audioWave": true,
                "services.audioWaveStyle": "bars",
                "services.audioWaveEdge": "bottom",
                "services.audioWaveReach": 0.07,
                "lyrics.mode": "line",
                "lyrics.blocky": false,
                "lyrics.shadow": true,
                "wallpaper.livingChips": "soft",
                "wallpaper.livingOpacity": 1.0,
                "lock.vEntrance": "slam",
                "lock.vFx": "grain",
                "lock.vFxStrength": 1.4,
                "lock.look": "vibe",
                "hypr.rounding": 0,
                "hypr.borderSize": 2,
                "hypr.gapsIn": 6,
                "hypr.gapsOut": 12,
                "hypr.manageBorders": true
            }
        },
        {
            id: "clean",
            vibe: true,
            name: "CLEAN",
            by: "light, calm, quiet",
            blurb: "Nothing but what you need: a soft white ground, one blue accent, hairline edges, gentle shadows and a neutral sans. The settings become a quiet single column.",
            accent: "#4a69e8",
            parts: ["QUIET SETTINGS COLUMN", "SOFT WHITE GROUND", "HAIRLINE EDGES", "NEUTRAL SANS", "CALM MOTION", "SOFT CLICKS"],
            mood: "clean",
            shape: "round",
            outline: 1,
            edgeHex: "#d9dde6",
            shadow: "soft",
            shadowSize: 8,
            swatch: { paper: "#e9ecf2", surface: "#fbfbfd", ink: "#1b1f2a", accent: "#4a69e8" },
            backdrop: "plain",
            scanlines: 0,
            barEdge: "top",
            waveEdge: "",
            waveStyle: "hairline",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#4a69e8",
                "appearance.groundColour": "#c9d3ee",
                "appearance.surfaceTint": 0.12,
                "appearance.surfaceLift": 0.0,
                "appearance.transparency": 0.96,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "clean",
                "appearance.skin": "clean",
                "appearance.typeStyle": "clean",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": false,
                "appearance.roundingScale": 1.0,
                "appearance.shape": "round",
                "appearance.outline": 1,
                "appearance.edge": "soft",
                "appearance.shadow": "soft",
                "appearance.shadowSize": 8,
                "appearance.ground": "light",
                "appearance.caps": "upper",
                "appearance.motion": "smooth",
                "appearance.scanlines": 0,
                "appearance.backdrop": "plain",
                "sfx.pack": "clean",
                "bar.style": "clean",
                "bar.position": "top",
                "bar.thickness": 38,
                "bar.margin": 0,
                "bar.rounding": 0,
                "bar.padding": 6,
                "bar.opacity": 0.94,
                "bar.blur": true,
                "bar.frame": false,
                "bar.colour": "surface",
                "bar.workspaces.style": "dots",
                "bar.layout": ["workspaces", "spacer", "activeWindow", "spacer", "tray", "statusIcons", "clock", "power"],
                "map.islandTheme": "light",
                "map.islandAccent": true,
                "services.audioReactive": true,
                "services.audioWave": false,
                "lyrics.mode": "stack",
                "lyrics.blocky": false,
                "lyrics.shadow": false,
                "wallpaper.livingChips": "soft",
                "wallpaper.livingOpacity": 0.96,
                "lock.vEntrance": "rise",
                "lock.look": "vibe",
                "hypr.rounding": 10,
                "hypr.borderSize": 1,
                "hypr.gapsIn": 5,
                "hypr.gapsOut": 10,
                "hypr.manageBorders": true
            }
        },
        {
            id: "minimal",
            vibe: true,
            name: "MINIMAL",
            by: "black on warm white · nothing else",
            blurb: "Less, on purpose: warm white paper, black ink, no colour at all, no shadows, no icons — just type, space and hairlines. The settings become a plain list of words.",
            accent: "#16161a",
            parts: ["A LIST OF WORDS", "NO COLOUR", "NO SHADOWS", "NO ICONS", "LOTS OF SPACE", "SOFT CLICKS"],
            mood: "clean",
            shape: "square",
            outline: 1,
            edgeHex: "#dcd9d0",
            shadow: "none",
            shadowSize: 0,
            swatch: { paper: "#f4f2ec", surface: "#f4f2ec", ink: "#16161a", accent: "#16161a" },
            backdrop: "plain",
            scanlines: 0,
            barEdge: "top",
            waveEdge: "",
            waveStyle: "hairline",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#16161a",
                "appearance.groundColour": "#d8d2c0",
                "appearance.surfaceTint": 0.08,
                "appearance.surfaceLift": 0.0,
                "appearance.transparency": 1.0,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "minimal",
                "appearance.skin": "clean",
                "appearance.typeStyle": "clean",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": false,
                "appearance.roundingScale": 1.0,
                "appearance.shape": "square",
                "appearance.outline": 1,
                "appearance.edge": "soft",
                "appearance.shadow": "none",
                "appearance.shadowSize": 0,
                "appearance.ground": "light",
                "appearance.caps": "upper",
                "appearance.motion": "smooth",
                "appearance.scanlines": 0,
                "appearance.backdrop": "plain",
                "sfx.pack": "clean",
                "bar.style": "clean",
                "bar.position": "top",
                "bar.thickness": 28,
                "bar.margin": 0,
                "bar.rounding": 0,
                "bar.padding": 6,
                "bar.opacity": 1,
                "bar.blur": false,
                "bar.frame": false,
                "bar.colour": "surface",
                "bar.workspaces.style": "dots",
                "bar.layout": ["workspaces", "spacer", "clock"],
                "map.islandTheme": "light",
                "map.islandAccent": true,
                "services.audioReactive": true,
                "services.audioWave": false,
                "lyrics.mode": "stack",
                "lyrics.blocky": false,
                "lyrics.shadow": false,
                "wallpaper.livingChips": "soft",
                "wallpaper.livingOpacity": 0.96,
                "lock.vEntrance": "fade",
                "lock.vFx": "vignette",
                "lock.vFxStrength": 0.5,
                "lock.look": "vibe",
                "hypr.rounding": 0,
                "hypr.borderSize": 1,
                "hypr.gapsIn": 10,
                "hypr.gapsOut": 20,
                "hypr.manageBorders": true
            }
        },
        {
            id: "flat",
            vibe: true,
            name: "FLAT",
            by: "solid colour blocks · no depth",
            blurb: "Flat design: solid colour blocks, no shadows, no gradients, no outlines. A dark navy sidebar, a turquoise accent, sharp little corners and a bold geometric sans — depth comes from colour alone.",
            accent: "#1abc9c",
            parts: ["SOLID COLOUR BLOCKS", "NO SHADOWS", "NO GRADIENTS", "NAVY SIDEBAR", "BOLD SANS", "SOFT CLICKS"],
            mood: "soft",
            shape: "square",
            outline: 0,
            edgeHex: "#bdc3c7",
            shadow: "none",
            shadowSize: 0,
            swatch: { paper: "#ecf0f1", surface: "#ffffff", ink: "#2c3e50", accent: "#1abc9c", accent2: "#e74c3c" },
            backdrop: "plain",
            scanlines: 0,
            barEdge: "top",
            waveEdge: "",
            waveStyle: "hairline",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#1abc9c",
                "appearance.groundColour": "#9aa9b8",
                "appearance.surfaceTint": 0.14,
                "appearance.surfaceLift": 0.0,
                "appearance.transparency": 1.0,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "flat",
                "appearance.skin": "clean",
                "appearance.typeStyle": "soft",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": false,
                "appearance.roundingScale": 1.0,
                "appearance.shape": "square",
                "appearance.outline": 0,
                "appearance.edge": "soft",
                "appearance.shadow": "none",
                "appearance.shadowSize": 0,
                "appearance.ground": "light",
                "appearance.caps": "upper",
                "appearance.motion": "crisp",
                "appearance.scanlines": 0,
                "appearance.backdrop": "plain",
                "sfx.pack": "clean",
                "bar.style": "clean",
                "bar.position": "top",
                "bar.thickness": 44,
                "bar.margin": 0,
                "bar.rounding": 0,
                "bar.padding": 6,
                "bar.opacity": 1,
                "bar.blur": false,
                "bar.frame": false,
                "bar.colour": "tone",
                "bar.workspaces.style": "numbers",
                "bar.layout": ["workspaces", "spacer", "activeWindow", "spacer", "tray", "statusIcons", "clock", "power"],
                "map.islandTheme": "light",
                "map.islandAccent": true,
                "services.audioReactive": true,
                "services.audioWave": false,
                "lyrics.mode": "stack",
                "lyrics.blocky": false,
                "lyrics.shadow": false,
                "wallpaper.livingChips": "soft",
                "wallpaper.livingOpacity": 0.96,
                "lock.vEntrance": "drop",
                "lock.look": "vibe",
                "hypr.rounding": 3,
                "hypr.borderSize": 1,
                "hypr.gapsIn": 4,
                "hypr.gapsOut": 8,
                "hypr.manageBorders": true
            }
        },
        {
            id: "neu",
            vibe: true,
            name: "NEUMORPH",
            by: "soft extruded · light from the top left",
            blurb: "Neumorphism: everything is pushed out of one blue-grey surface — a light shadow on one side, a dark one on the other. Buttons rise, the chosen entry sinks in, switches and sliders are moulded. No lines, no outlines.",
            accent: "#6d7cff",
            parts: ["EXTRUDED SURFACES", "TWO-SIDED SOFT SHADOWS", "PRESSED-IN SELECTION", "MOULDED SWITCHES", "ONE GREY-BLUE GROUND", "SOFT CLICKS"],
            mood: "soft",
            shape: "round",
            outline: 0,
            edgeHex: "#c9d0dc",
            shadow: "neu",
            shadowSize: 8,
            swatch: { paper: "#dfe5ee", surface: "#e8edf5", ink: "#3a4256", accent: "#6d7cff" },
            backdrop: "plain",
            scanlines: 0,
            barEdge: "bottom",
            waveEdge: "",
            waveStyle: "hairline",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#6d7cff",
                "appearance.groundColour": "#8d9bb8",
                "appearance.surfaceTint": 0.2,
                "appearance.surfaceLift": 0.0,
                "appearance.transparency": 1.0,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "neu",
                "appearance.skin": "clean",
                "appearance.typeStyle": "soft",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": false,
                "appearance.roundingScale": 1.2,
                "appearance.shape": "round",
                "appearance.outline": 0,
                "appearance.edge": "soft",
                "appearance.shadow": "neu",
                "appearance.shadowSize": 8,
                "appearance.ground": "light",
                "appearance.caps": "upper",
                "appearance.motion": "smooth",
                "appearance.scanlines": 0,
                "appearance.backdrop": "plain",
                "sfx.pack": "clean",
                "bar.style": "floating",
                "bar.position": "bottom",
                "bar.thickness": 52,
                "bar.margin": 14,
                "bar.rounding": 26,
                "bar.padding": 6,
                "bar.opacity": 1,
                "bar.blur": false,
                "bar.frame": false,
                "bar.colour": "surface",
                "bar.workspaces.style": "dots",
                "bar.layout": ["workspaces", "spacer", "media", "spacer", "statusIcons", "clock", "power"],
                "map.islandTheme": "light",
                "map.islandAccent": true,
                "services.audioReactive": true,
                "services.audioWave": false,
                "lyrics.mode": "stack",
                "lyrics.blocky": false,
                "lyrics.shadow": false,
                "wallpaper.livingChips": "soft",
                "wallpaper.livingOpacity": 0.96,
                "lock.vEntrance": "zoom",
                "lock.look": "vibe",
                "hypr.rounding": 14,
                "hypr.borderSize": 1,
                "hypr.gapsIn": 8,
                "hypr.gapsOut": 18,
                "hypr.manageBorders": true
            }
        },
        {
            id: "clay",
            vibe: true,
            name: "CLAY",
            by: "puffy pastel · a friendly lump",
            blurb: "Claymorphism: fat, pillowy shapes in pastel peach and violet, a lit top and a shaded belly like modelling clay, a thick tinted shadow underneath and bouncy motion. Everything looks squeezable.",
            accent: "#8a66ff",
            parts: ["PILLOWY SHAPES", "PASTEL PEACH", "LIT TOP, SHADED BELLY", "TINTED SHADOWS", "BOUNCY MOTION", "SOFT CLICKS"],
            mood: "soft",
            shape: "round",
            outline: 0,
            edgeHex: "#f4d9cc",
            shadow: "clay",
            shadowSize: 12,
            swatch: { paper: "#fbe3d6", surface: "#fff4ec", ink: "#4a3358", accent: "#8a66ff", accent2: "#ff8fb1" },
            backdrop: "plain",
            scanlines: 0,
            barEdge: "top",
            waveEdge: "",
            waveStyle: "hairline",
            clock: "none",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#8a66ff",
                "appearance.groundColour": "#e8a58a",
                "appearance.surfaceTint": 0.45,
                "appearance.surfaceLift": 0.0,
                "appearance.transparency": 1.0,
                "appearance.accentSaturation": 1.0
            },
            settings: {
                "appearance.vibe": "clay",
                "appearance.skin": "clean",
                "appearance.typeStyle": "soft",
                "appearance.skew": 0,
                "appearance.halftone": false,
                "appearance.sharpCorners": false,
                "appearance.roundingScale": 1.7,
                "appearance.shape": "round",
                "appearance.outline": 0,
                "appearance.edge": "soft",
                "appearance.shadow": "clay",
                "appearance.shadowSize": 12,
                "appearance.ground": "light",
                "appearance.caps": "upper",
                "appearance.motion": "bouncy",
                "appearance.scanlines": 0,
                "appearance.backdrop": "plain",
                "sfx.pack": "clean",
                "bar.style": "floating",
                "bar.position": "top",
                "bar.thickness": 48,
                "bar.margin": 12,
                "bar.rounding": 26,
                "bar.padding": 6,
                "bar.opacity": 1,
                "bar.blur": false,
                "bar.frame": false,
                "bar.colour": "surface",
                "bar.workspaces.style": "pills",
                "bar.layout": ["workspaces", "spacer", "activeWindow", "spacer", "tray", "statusIcons", "clock", "power"],
                "map.islandTheme": "light",
                "map.islandAccent": true,
                "services.audioReactive": true,
                "services.audioWave": false,
                "lyrics.mode": "stack",
                "lyrics.blocky": false,
                "lyrics.shadow": false,
                "wallpaper.livingChips": "soft",
                "wallpaper.livingOpacity": 0.96,
                "lock.vEntrance": "drop",
                "lock.vFx": "snow",
                "lock.vFxStrength": 0.7,
                "lock.look": "vibe",
                "hypr.rounding": 20,
                "hypr.borderSize": 1,
                "hypr.gapsIn": 10,
                "hypr.gapsOut": 20,
                "hypr.manageBorders": true
            }
        },
        {
            id: "sakura",
            name: "SAKURA",
            by: "plum and pink · the whole desktop",
            blurb: "Plum and pink, a thin top bar in a rounded screen frame, cava bars hanging from the top, the greeting lock with its shapes.",
            accent: "#f4a6c7",
            parts: ["TOP BAR + FRAME", "PILL WORKSPACES", "CAVA BARS", "GREETING LOCK", "SOFT TYPE", "SOFT WIDGETS"],
            barEdge: "top",
            waveEdge: "top",
            waveStyle: "bars",
            clock: "sun",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#f4a6c7",
                "appearance.surfaceTint": 0.5,
                "appearance.surfaceLift": 0.03,
                "appearance.transparency": 0.94
            },
            settings: {
                "bar.position": "top",
                "bar.thickness": 40,
                "bar.margin": 0,
                "bar.rounding": 0,
                "bar.padding": 6,
                "bar.opacity": 1,
                "bar.frame": true,
                "bar.frameWidth": 6,
                "bar.frameRounding": 22,
                "bar.frameConnect": true,
                "bar.frameColour": "bar",
                "bar.frameOpacity": 1,
                "bar.frameShadow": true,
                "bar.frameOutline": false,
                "bar.colour": "tone",
                "appearance.softTone": "accent",
                "bar.workspaces.style": "pills",
                "bar.layout": ["launcher", "workspaces", "clock", "spacer", "media", "spacer", "tray", "statusIcons", "power"],
                "services.audioReactive": true,
                "services.audioWave": true,
                "services.audioWaveStyle": "bars",
                "services.audioWaveEdge": "top",
                "services.audioWaveReach": 0.1,
                "wallpaper.livingChips": "soft",
                "wallpaper.livingOpacity": 0.94,
                "lock.layout": "greeting",
                "lock.clockShape": "sun",
                "lock.clockFace": "",
                "lock.clockScale": 1.0,
                "lock.clockFontScale": 1.0,
                "lock.visualizer": true,
                "lock.visualizerEdge": "top",
                "lock.visualizerStyle": "bars",
                "lock.visualizerReach": 0.1,
                "lock.blur": 0.9,
                "lock.backgroundDim": 0.12
            }
        },
        {
            id: "softlock",
            name: "SOFT LOCK",
            by: "only the lock",
            blurb: "Only the lock: a big two-tone clock over round brown pills, the password with its pencil, cava bars from the top. The desktop stays yours.",
            accent: "#f2b391",
            parts: ["SOFT LOCK", "VERTICAL CLOCK", "CAVA BARS", "PEACH"],
            barEdge: "",
            waveEdge: "top",
            waveStyle: "bars",
            clock: "none",
            lockOnly: true,
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#f2b391",
                "appearance.surfaceTint": 0.5,
                "appearance.surfaceLift": 0.03
            },
            settings: {
                "lock.look": "soft",
                "lock.layout": "vertical",
                "lock.clockShape": "none",
                "lock.clockFace": "",
                "lock.clockFont": "",
                "lock.clockScale": 1.0,
                "lock.clockFontScale": 1.0,
                "lock.visualizer": true,
                "lock.visualizerEdge": "top",
                "lock.visualizerStyle": "bars",
                "lock.visualizerReach": 0.07,
                "lock.blur": 0.8,
                "lock.backgroundDim": 0.08,
                "lock.softPower": true,
                "lock.softStatus": true,
                "lock.softMedia": true,
                "lock.softEdit": true
            }
        },
        {
            id: "ember",
            name: "EMBER",
            by: "warm, slim and lyrical",
            blurb: "Warm dark brown and peach, a slim bar on the left, a soft wave dripping from the top, the lyric card, a one-line clock on the lock.",
            accent: "#f0a47a",
            parts: ["LEFT BAR", "PILL WORKSPACES", "TOP WAVE", "LYRICS CARD", "LINE CLOCK", "SOFT TYPE"],
            barEdge: "left",
            waveEdge: "top",
            waveStyle: "wave",
            clock: "line",
            colours: {
                "appearance.accentSource": "manual",
                "appearance.accentColour": "#f0a47a",
                "appearance.surfaceTint": 0.34,
                "appearance.surfaceLift": 0.09,
                "appearance.transparency": 0.95
            },
            settings: {
                "bar.position": "left",
                "bar.thickness": 44,
                "bar.margin": 0,
                "bar.rounding": 0,
                "bar.padding": 7,
                "bar.opacity": 1,
                "bar.frame": false,
                "bar.colour": "tone",
                "appearance.softTone": "accent",
                "bar.workspaces.style": "pills",
                "bar.layout": ["launcher", "workspaces", "spacer", "media", "spacer", "tray", "clock", "statusIcons", "power"],
                "services.audioReactive": true,
                "services.audioWave": true,
                "services.audioWaveStyle": "wave",
                "services.audioWaveEdge": "top",
                "services.audioWaveReach": 0.05,
                "lyrics.enabled": true,
                "lyrics.mode": "stack",
                "lyrics.tile": true,
                "lyrics.position": "bottom",
                "wallpaper.livingChips": "soft",
                "wallpaper.livingOpacity": 0.94,
                "lock.layout": "vertical",
                "lock.clockShape": "line",
                "lock.clockFace": "",
                "lock.clockScale": 1.0,
                "lock.clockFontScale": 0.8,
                "lock.visualizer": false,
                "lock.blur": 1.0,
                "lock.backgroundDim": 0.2,
                "lock.ambientAfter": "15"
            }
        }
    ]

    // The vibes in card order, and the one after (or before) the one on now —
    // QUICK SETTINGS → VIBE steps through them without opening the LOOKS tab.
    readonly property var vibeIds: root.vibeCards.map(l => l.family === "windows" ? "windows" : l.id)

    function cycleVibe(dir: int): string {
        const ids = root.vibeIds;
        if (ids.length === 0)
            return "";
        const at = ids.indexOf(Config.appearance.vibe);
        const next = ids[at < 0 ? (dir > 0 ? 0 : ids.length - 1) : (at + dir + ids.length) % ids.length];
        root.apply(next);
        return next;
    }

    // WINDOWS VERSION: wearing the Windows look, the whole shell turns into
    // the chosen edition; otherwise it only remembers which edition the
    // WINDOWS card should show.
    function setWinVersion(v: string): void {
        if (root.winIds.indexOf(v) < 0)
            return;
        if (Config.appearance.skin === "win" || Config.appearance.vibe === "windows")
            root.apply(`win${v}`);
        else
            Config.set("appearance.winVersion", v);
    }

    function find(id: string): var {
        // "windows" is whichever edition you chose last.
        if (id === "windows")
            return root.winCurrent;
        if (id === "velvet")
            return root.original;
        for (let i = 0; i < root.looks.length; i++)
            if (root.looks[i].id === id)
                return root.looks[i];
        return null;
    }

    // Everything a look writes, as one flat map (soft base, the look's own
    // rows, and — if wanted — its colours).
    function plan(look: var): var {
        const out = {};
        if (!look.lockOnly)
            Object.assign(out, root.vibeDefaults);
        if (!look.lockOnly && !look.house && !look.custom && !look.vibe)
            Object.assign(out, root.softBase);
        Object.assign(out, look.settings);
        // A built-in look with a lock layout shows that layout as it was
        // drawn: places and element looks made by hand step aside (BACK
        // brings them back; a saved look of your own keeps its own).
        if (!look.custom && out["lock.layout"] !== undefined) {
            out["lock.softPlace"] = {};
            out["lock.softStyle"] = {};
        }
        if (root.withColours) {
            Object.assign(out, look.colours);
            // VISUALS → THIS LOOK → COLOURS: the look follows the wallpaper —
            // its accent and the hue of its ground come from the picture;
            // its strength, tint and lightness stay the look's.
            if (Config.appearance.lookColours !== "own" && !look.custom) {
                out["appearance.accentSource"] = "wallpaper";
                out["appearance.groundColour"] = "auto";
            }
        }
        return out;
    }

    // The colour switch changed while a look is on: its colours follow at once.
    Connections {
        target: Config.appearance

        function onLookColoursChanged(): void {
            const look = root.applied !== "" ? root.find(root.applied) : null;
            if (!look || !root.withColours || look.lockOnly)
                return;
            const p = root.plan(look);
            const batch = {};
            for (const k of root.colourKeys)
                if (p[k] !== undefined)
                    batch[k] = root.copy(p[k]);
            Config.setMany(batch);
        }
    }

    // Every key any look can touch — what BACK restores.
    readonly property var allKeys: {
        const keys = {};
        for (const k in root.softBase)
            keys[k] = true;
        for (let i = 0; i < root.builtIn.length; i++) {
            for (const k in root.builtIn[i].settings)
                keys[k] = true;
            for (const k in root.builtIn[i].colours)
                keys[k] = true;
        }
        for (const k in root.original.settings)
            keys[k] = true;
        for (const k in root.original.colours)
            keys[k] = true;
        for (let i = 0; i < root.winLooks.length; i++) {
            for (const k in root.winLooks[i].settings)
                keys[k] = true;
            for (const k in root.winLooks[i].colours)
                keys[k] = true;
        }
        for (const k of root.extraKeys)
            keys[k] = true;
        for (const k of root.colourKeys)
            keys[k] = true;
        return Object.keys(keys);
    }

    function copy(v: var): var {
        return v === undefined ? null : JSON.parse(JSON.stringify(v));
    }

    function same(a: var, b: var): bool {
        return JSON.stringify(a) === JSON.stringify(b);
    }

    // Is this look what the shell wears right now?
    function wearing(id: string): bool {
        const look = root.find(id);
        if (!look)
            return false;
        const p = root.plan(look);
        for (const k in p)
            if (!root.same(root.copy(Config.get(k)), p[k]))
                return false;
        return true;
    }

    // What you tuned on the look you wear is remembered for that look, so it
    // comes back with it. Only the difference to the design is kept.
    // A remembered tuning that names another look's identity is not a tuning
    // but a stale snapshot (see stash()): it is dropped when it is read.
    function sane(t: var): var {
        const out = {};
        for (const id in t) {
            const look = root.find(id);
            const tune = t[id];
            if (!look || !tune)
                continue;
            const factory = root.plan(look);
            let stale = false;
            for (const k of root.identityKeys)
                if (tune[k] !== undefined && factory[k] !== undefined && !root.same(tune[k], factory[k]))
                    stale = true;
            if (!stale)
                out[id] = tune;
        }
        return out;
    }

    // What makes a look that look: never part of its tuning.
    readonly property var identityKeys: ["appearance.vibe", "appearance.skin", "appearance.winVersion", "appearance.typeStyle"]

    function stash(): void {
        const id = root.applied;
        if (id === "" || id === "velvet")
            return;
        const look = root.find(id);
        if (!look || look.lockOnly)
            return;
        const factory = root.plan(look);
        // Only while that look is really on: a config that changed under a
        // stale `applied` (a reload between the two files' writes) once filed
        // all of Velvet as WINDOWS 11's "tuning".
        for (const k of root.identityKeys)
            if (factory[k] !== undefined && !root.same(root.copy(Config.get(k)), factory[k]))
                return;
        const diff = {};
        for (const k in factory) {
            if (root.identityKeys.indexOf(k) >= 0)
                continue;
            const cur = root.copy(Config.get(k));
            if (cur === null)
                continue;
            if (!root.same(cur, factory[k]))
                diff[k] = cur;
        }
        const next = Object.assign({}, root.tunes);
        if (Object.keys(diff).length > 0)
            next[id] = diff;
        else
            delete next[id];
        root.tunes = next;
    }

    function apply(id: string): bool {
        return root.applyLook(id, false);
    }

    // `fresh` puts the look on as designed and forgets its tuning.
    function applyLook(id: string, fresh: bool): bool {
        const look = root.find(id);
        if (!look || !Config.loaded)
            return false;
        if (fresh) {
            const next = Object.assign({}, root.tunes);
            delete next[id];
            root.tunes = next;
        } else if (root.applied !== id) {
            root.stash();
        }
        // The first look remembers your own setup; later ones keep that.
        if (root.before === null) {
            const snap = {};
            for (let i = 0; i < root.allKeys.length; i++)
                snap[root.allKeys[i]] = root.copy(Config.get(root.allKeys[i]));
            root.before = snap;
        }
        const p = root.plan(look);
        // …and what you tuned on this look last time
        const mine = root.tunes[id];
        if (mine && !fresh) {
            for (const k in mine)
                if (root.identityKeys.indexOf(k) < 0 && (root.withColours || root.colourKeys.indexOf(k) < 0))
                    p[k] = mine[k];
        }
        const batch = {};
        for (const k in p)
            batch[k] = root.copy(p[k]);
        // What only a vibe touches (the windows' borders and gaps) goes back
        // to your own values when a look that leaves them alone is put on.
        for (const k of root.vibeOwned)
            if (!(k in p) && root.before !== null && root.before[k] !== null && root.before[k] !== undefined)
                batch[k] = root.copy(root.before[k]);
        Config.setMany(batch);
        root.applied = id;
        root.persist();
        return true;
    }

    // THIS LOOK → RESET THIS LOOK: the look you wear, as designed, with its tuning forgotten.
    function resetTune(): bool {
        const id = root.applied !== "" ? root.applied : "velvet";
        return root.applyLook(id, true);
    }

    function undo(): bool {
        if (root.before === null)
            return false;
        const batch = {};
        for (const k in root.before) {
            // A key that did not exist before (older config) stays as is.
            if (root.before[k] !== null)
                batch[k] = root.copy(root.before[k]);
        }
        Config.setMany(batch);
        root.before = null;
        root.applied = "";
        root.persist();
        return true;
    }

    function keep(): void {
        root.before = null;
        root.persist();
    }

    // ── your own looks
    // Everything the looks know about, as it is right now, becomes a card.
    function saveCurrent(): string {
        if (!Config.loaded)
            return "";
        const settings = {};
        const colours = {};
        for (const k of root.allKeys) {
            const v = root.copy(Config.get(k));
            if (v === null)
                continue;
            if (root.colourKeys.indexOf(k) >= 0)
                colours[k] = v;
            else
                settings[k] = v;
        }
        let n = 1;
        const names = root.custom.map(l => l.name);
        while (names.indexOf(`MY LOOK ${n}`) >= 0)
            n++;
        const wave = Config.services.audioReactive && Config.services.audioWave && Config.services.audioWaveStyle !== "hairline";
        const lockClock = Config.lock.clockFace === "analog" ? "circle" : (Config.lock.clockShape || "none");
        const parts = [];
        parts.push(Config.bar.enabled ? `${String(Config.bar.position).toUpperCase()} BAR · ${String(Config.bar.style).toUpperCase()}` : "NO BAR");
        if (Config.bar.frame)
            parts.push(Config.bar.frameConnect ? "CONNECTED FRAME" : "FRAME");
        parts.push(`${String(Config.lock.look).toUpperCase()} LOCK`);
        if (wave)
            parts.push(`${String(Config.services.audioWaveStyle).toUpperCase()} ${String(Config.services.audioWaveEdge).toUpperCase()}`);
        parts.push(Config.appearance.typeStyle === "soft" ? "SOFT TYPE" : "PERSONA TYPE");
        parts.push(`${String(Config.wallpaper.livingChips).toUpperCase()} WIDGETS`);
        const look = {
            id: `custom-${Date.now()}`,
            name: `MY LOOK ${n}`,
            by: `saved ${Qt.formatDateTime(new Date(), "d MMM yyyy · HH:mm")}`,
            blurb: "Your own setup, exactly as it was when you saved it — bar, frame, lock, type, colours, the music along the edge.",
            accent: `${Colours.accent}`,
            parts: parts,
            barEdge: Config.bar.enabled && Config.bar.style !== "floating" ? Config.bar.position : "",
            waveEdge: wave ? Config.services.audioWaveEdge : "",
            waveStyle: Config.services.audioWaveStyle,
            clock: Config.lock.look === "soft" ? lockClock : "none",
            house: Config.appearance.typeStyle !== "soft",
            custom: true,
            colours: colours,
            settings: settings
        };
        root.custom = root.custom.concat([look]);
        root.persistCustom();
        return look.id;
    }

    function removeCustom(id: string): bool {
        const next = root.custom.filter(l => l.id !== id);
        if (next.length === root.custom.length)
            return false;
        root.custom = next;
        if (root.applied === id)
            root.applied = "";
        root.persistCustom();
        root.persist();
        return true;
    }

    function persistCustom(): void {
        customFile.setText(JSON.stringify(root.custom, null, 1));
    }

    FileView {
        id: customFile

        path: root.customPath
        printErrors: false

        onLoaded: {
            try {
                const d = JSON.parse(customFile.text());
                if (Array.isArray(d))
                    root.custom = d.filter(l => l && l.id && l.settings);
            } catch (e) {}
        }
    }

    function persist(): void {
        file.setText(JSON.stringify({
            before: root.before,
            applied: root.applied,
            withColours: root.withColours,
            tunes: root.tunes,
            names: root.names
        }, null, 1));
    }

    FileView {
        id: file

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const d = JSON.parse(file.text());
                root.before = d.before ?? null;
                root.applied = d.applied ?? "";
                root.withColours = d.withColours ?? true;
                root.tunes = root.sane(d.tunes ?? ({}));
                root.names = d.names ?? ({});
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    IpcHandler {
        target: "looks"

        function rename(id: string, name: string): string {
            return root.rename(id, name) ? `${id} is now ${root.nameOf(root.find(id))}` : `unknown look: ${id}`;
        }
        function apply(id: string): string {
            return root.apply(id) ? `applied ${id}` : `unknown look: ${id} (${root.looks.map(l => l.id).join(", ")})`;
        }
        function undo(): string {
            return root.undo() ? "back to your own look" : "nothing to undo";
        }
        function keep(): string {
            root.keep();
            return "kept";
        }
        function save(): string {
            const id = root.saveCurrent();
            return id !== "" ? `saved as ${id}` : "not ready";
        }
        function remove(id: string): string {
            return root.removeCustom(id) ? `removed ${id}` : `no custom look ${id}`;
        }
        function list(): string {
            return ["velvet (the original)" + (root.wearing("velvet") ? " (on)" : "")].concat(root.looks.map(l => `${l.id}${root.wearing(l.id) ? " (on)" : ""}`)).join("\n");
        }
    }
}
