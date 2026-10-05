//  VELVET  ·  config/Modules.qml
//  Every bar module, described once.
//
//  This used to live in three places at the same time — a switch in Bar.qml, a
//  catalogue in the layout editor, and a scattering of rows in Schema.qml — so
//  adding a module meant remembering all three and a module's own settings
//  lived nowhere near the module. One table now: what it is called, what it
//  looks like, whether you can have more than one, and which settings belong
//  to it. The layout tab reads this and needs to know nothing else.
pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    readonly property var all: [
        {
            id: "logo",
            name: "LOGO",
            icon: "apps",
            sub: "OPENS THIS MENU · RIGHT-CLICK LAUNCHES",
            keys: []
        },
        {
            id: "workspaces",
            name: "WORKSPACES",
            icon: "tune",
            sub: "WORKSPACE INDICATOR",
            keys: ["bar.workspaces.shown", "bar.workspaces.showWindows", "bar.workspaces.activeIndicator", "bar.workspaces.labelOccupied", "bar.scroll.workspaces"]
        },
        {
            id: "activeWindow",
            name: "ACTIVE WINDOW",
            icon: "monitor",
            sub: "WHAT YOU ARE LOOKING AT",
            keys: []
        },
        {
            id: "tray",
            name: "SYSTEM TRAY",
            icon: "folder",
            sub: "BACKGROUND APPS",
            keys: ["bar.tray.background"]
        },
        {
            id: "clock",
            name: "CLOCK",
            icon: "bedtime",
            sub: "TIME AND DATE",
            keys: ["bar.clock.format24h", "bar.clock.showDate", "bar.clock.showSeconds"]
        },
        {
            id: "statusIcons",
            name: "STATUS",
            icon: "network_wifi",
            sub: "NETWORK · SOUND · GAUGES",
            keys: ["bar.status.network", "bar.status.bluetooth", "bar.status.volume", "bar.status.battery", "bar.status.cpu", "bar.status.memory", "bar.status.temperature"]
        },
        {
            id: "power",
            name: "POWER",
            icon: "power_settings_new",
            sub: "SESSION MENU · RIGHT-CLICK LOCKS",
            keys: ["lock.useBuiltin"]
        },
        {
            id: "media",
            name: "NOW PLAYING",
            icon: "music_note",
            sub: "CLICK PLAYS · WHEEL SKIPS",
            keys: []
        },
        {
            id: "resources",
            name: "RESOURCES",
            icon: "graphic_eq",
            sub: "TWO MINUTES OF CPU AND MEMORY",
            keys: ["bar.status.cpu", "bar.status.memory"]
        },
        {
            id: "weather",
            name: "WEATHER",
            icon: "cloud",
            sub: "VIA WTTR.IN, NO ACCOUNT NEEDED",
            keys: ["services.weather", "services.weatherLocation", "services.weatherMetric", "services.weatherInterval"]
        },
        {
            id: "notifications",
            name: "NOTIFICATIONS",
            icon: "notifications",
            sub: "BELL WITH UNREAD COUNT",
            keys: ["notifs.enabled", "notifs.doNotDisturb", "notifs.maxPopups", "notifs.timeout"]
        },
        {
            id: "microphone",
            name: "MICROPHONE",
            icon: "mic",
            sub: "PULSES WHILE THE MIC IS LIVE",
            keys: ["services.volumeStep"]
        },
        {
            id: "keyboard",
            name: "KEYBOARD",
            icon: "keyboard_alt",
            sub: "ACTIVE LAYOUT · CLICK CYCLES",
            keys: []
        },
        {
            id: "uptime",
            name: "UPTIME",
            icon: "timer",
            sub: "SINCE THE LAST REBOOT",
            keys: []
        },
        {
            id: "screenshot",
            name: "SCREENSHOT",
            icon: "photo_camera",
            sub: "REGION TO CLIPBOARD",
            keys: ["services.screenshotCommand"]
        },
        {
            id: "launcher",
            name: "LAUNCHER",
            icon: "search",
            sub: "OPENS THE APP LAUNCHER",
            keys: ["launcher.maxShown", "launcher.fuzzy", "launcher.searchSettings", "launcher.useCalculator"]
        },
        {
            id: "focus",
            name: "FOCUS MODE",
            icon: "do_not_disturb_on",
            sub: "SILENCE EVERYTHING WITH ONE CLICK",
            keys: ["services.focusMode", "services.focusSilences", "services.focusKeepsAwake", "services.focusMutesShell", "services.focusHidesBar", "services.focusDims", "services.focusDimStrength", "services.focusShades"]
        },
        {
            id: "scene",
            name: "DESKTOP",
            icon: "space_dashboard",
            sub: "THE WINDOWS YOU ARRANGED, ONE CLICK AWAY",
            // FOLLOW THE WALLPAPER lives in the DESKTOP tab itself — it is the
            // first thing you see there, not a setting buried in an inspector.
            keys: ["scene.autostart", "scene.terminal"]
        },
        {
            id: "map",
            name: "MINI DESKTOP",
            icon: "grid_view",
            sub: "THE MAP THAT DROPS FROM THE TOP EDGE",
            keys: ["map.enabled", "map.hoverEdge", "map.island", "map.plateWidth", "map.desktops", "map.previews", "map.dragFloats"]
        },
        {
            id: "lyrics",
            name: "LYRICS",
            icon: "lyrics",
            sub: "BEATS ALONG WITH THE SONG",
            keys: ["lyrics.enabled", "lyrics.mode", "lyrics.size", "lyrics.blocky"]
        },
        {
            id: "keys",
            name: "SHORTCUTS",
            icon: "keyboard",
            sub: "EVERY KEY IN THE SHELL",
            keys: []
        },
        // Pure layout. These are the two you can have as many of as you like,
        // which is why `repeatable` exists at all.
        {
            id: "separator",
            name: "SEPARATOR",
            icon: "drag_handle",
            sub: "A HAIRLINE BETWEEN GROUPS",
            repeatable: true,
            keys: []
        },
        {
            id: "spacer",
            name: "SPACER",
            icon: "arrow_forward",
            sub: "PUSHES EVERYTHING AFTER IT AWAY",
            repeatable: true,
            keys: []
        }
    ]

    function byId(id: string): var {
        for (let i = 0; i < root.all.length; i++)
            if (root.all[i].id === id)
                return root.all[i];
        return null;
    }

    function nameOf(id: string): string {
        return root.byId(id)?.name ?? id.toUpperCase();
    }

    function iconOf(id: string): string {
        return root.byId(id)?.icon ?? "widgets";
    }

    function isRepeatable(id: string): bool {
        return root.byId(id)?.repeatable === true;
    }

    // Arrangements worth starting from. The point is not that one of them is
    // right — it is that an empty bar is a bad place to begin.
    readonly property var presets: [
        {
            name: "CLASSIC",
            sub: "WHAT VELVET SHIPS WITH",
            layout: ["logo", "workspaces", "spacer", "activeWindow", "spacer", "tray", "clock", "statusIcons", "power"]
        },
        {
            name: "MINIMAL",
            sub: "WORKSPACES, TIME, AND THE WAY OUT",
            layout: ["workspaces", "spacer", "clock", "spacer", "power"]
        },
        {
            name: "EVERYTHING",
            sub: "ONE OF EACH, IN A SENSIBLE ORDER",
            layout: ["logo", "workspaces", "separator", "media", "spacer", "activeWindow", "spacer", "lyrics", "weather", "resources", "separator", "tray", "notifications", "microphone", "keyboard", "clock", "statusIcons", "focus", "power"]
        },
        {
            name: "DESKTOP",
            sub: "BUILT AROUND THE MAP AND THE SCENE",
            layout: ["logo", "scene", "map", "workspaces", "spacer", "activeWindow", "spacer", "resources", "clock", "statusIcons", "power"]
        },
        {
            name: "MEDIA",
            sub: "FOR WHEN SOMETHING IS ALWAYS PLAYING",
            layout: ["logo", "workspaces", "spacer", "media", "lyrics", "spacer", "microphone", "clock", "statusIcons", "power"]
        }
    ]
}
