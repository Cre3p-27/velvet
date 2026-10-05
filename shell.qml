//  ██╗   ██╗███████╗██╗    ██╗   ██╗███████╗████████╗
//  ██║   ██║██╔════╝██║    ██║   ██║██╔════╝╚══██╔══╝
//  ██║   ██║█████╗  ██║    ██║   ██║█████╗     ██║
//  ╚██╗ ██╔╝██╔══╝  ██║    ╚██╗ ██╔╝██╔══╝     ██║
//   ╚████╔╝ ███████╗███████╗╚████╔╝ ███████╗   ██║
//    ╚═══╝  ╚══════╝╚══════╝ ╚═══╝  ╚══════╝   ╚═╝
//
//  A Quickshell desktop for Hyprland.
//  Bar in the card mould, settings in the Persona mould.
//  Super+Tab is the front door.

import qs.config
import qs.services
import qs.components
import qs.modules.bar
import qs.modules.settings
import qs.modules.launcher
import qs.modules.notifs
import qs.modules.osd
import qs.modules.session
import qs.modules.wallpaper
import qs.modules.welcome
import qs.modules.map
import qs.modules.island
import qs.modules.lyrics
import qs.modules.lock
// Timer and friends come from QtQuick; QML imports are not transitive, so
// `import Quickshell` alone does not make them visible here.
import QtQuick
import Quickshell

ShellRoot {
    id: root

    // ------------------------------------------------------------- per screen
    // Wallpaper first: it sits on the background layer under everything else.
    Variants {
        model: Quickshell.screens

        Wallpaper {}
    }

    // The bar and its popouts, per screen — behind the master switch
    // (MODULES → TASKBAR), so OFF removes them from every monitor.
    LazyLoader {
        active: Config.bar.enabled

        Variants {
            model: Quickshell.screens

            BarWindow {}
        }
    }

    LazyLoader {
        active: Config.bar.enabled

        Variants {
            model: Quickshell.screens

            Popouts {}
        }
    }

    // TASKBAR → SCREEN FRAME: the rounded frame round the desktop.
    LazyLoader {
        active: Config.bar.frame

        Variants {
            model: Quickshell.screens

            ScreenFrame {}
        }
    }

    Variants {
        model: Quickshell.screens

        NotifPopups {}
    }

    // The window map is per screen too: each one is a layer on its own
    // monitor, and only the focused one draws the plate. It is a full-screen
    // layer, so it exists only while it is up (Parked) — opened on purpose on
    // the screen you are looking at, or reached for with the pointer.
    Variants {
        model: Quickshell.screens

        Parked {
            id: mapHost

            required property ShellScreen modelData

            open: (Panels.windowMap && mapHost.modelData === Hypr.focusedScreen) || (Panels.mapHover !== "" && Panels.mapHover === mapHost.modelData?.name)
            keep: 10

            WindowMap {
                modelData: mapHost.modelData
            }
        }
    }

    // The strip at the top edge that raises the island (or opens the map
    // directly when the island is off) — one per screen, like the bar's
    // own reveal sliver.
    Variants {
        model: Quickshell.screens

        EdgeSensor {}
    }

    // The Dynamic Island — one per screen, like the map. Only the screen
    // whose top edge you touch raises the pill.
    Variants {
        model: Quickshell.screens

        Parked {
            id: islandHost

            required property ShellScreen modelData

            open: Panels.islandScreen === islandHost.modelData?.name && !Panels.windowMap && Config.map.island
            keep: 10

            Island {
                modelData: islandHost.modelData
            }
        }
    }

    // -------------------------------------------------- focused screen only
    //  These windows are big and mostly closed, so they are not kept in
    //  memory: each one is created when its flag goes true and let go
    //  `keep` seconds after it closes (components/Parked.qml). That is ~240 MB
    //  less for a shell that is just sitting there. The notification toasts
    //  and the volume pop-up stay: they are small and must be instant.
    Parked {
        open: Panels.settings
        keep: 60

        Settings {}
    }
    // Velvet's own launcher is the orbit; every look has a launcher of its own kind.
    Parked {
        open: Panels.launcher && Appearance.launcherStyle === "velvet"
        keep: 60

        Launcher {}
    }
    Parked {
        open: Panels.launcher && Appearance.launcherStyle !== "velvet"
        keep: 60

        LookLauncher {}
    }
    // the welcome page: once per login (Panels.welcome)
    Parked {
        open: Panels.welcome
        keep: 5

        Welcome {}
    }
    Parked {
        open: Panels.notifCentre
        keep: 30

        NotifCentre {}
    }
    Parked {
        open: Panels.session
        keep: 20

        Session {}
    }
    Parked {
        open: Panels.deskMenuScreen !== ""
        keep: 20

        DesktopMenu {}
    }
    Osd {}
    Toasts {}
    Parked {
        id: flash

        keep: 4

        VibeFlash {}
    }
    Parked {
        // the desktop lyrics only exist while they are switched on
        open: Config.lyrics.enabled && Config.lyrics.desktop
        keep: 5

        LyricsPanel {}
    }
    Parked {
        open: Panels.wheel
        keep: 30

        Wheel {}
    }
    Parked {
        open: Panels.keys
        keep: 20

        KeysPanel {}
    }

    // The beat between two vibes (modules/osd/VibeFlash.qml). Not at start-up,
    // when the saved vibe is only being read in.
    property bool flashArmed: false

    Timer {
        running: true
        interval: 3000
        onTriggered: root.flashArmed = true
    }
    Connections {
        target: Config.appearance

        function onVibeChanged(): void {
            if (!root.flashArmed)
                return;
            flash.pulse();
            if (flash.item)
                flash.item.start();
        }
        function onWinVersionChanged(): void {
            if (!root.flashArmed || Config.appearance.vibe !== "windows")
                return;
            flash.pulse();
            if (flash.item)
                flash.item.start();
        }
    }

    // Only loaded once you have opted in, so a machine without a working PAM
    // setup never even parses it. Covers every screen by itself when locked.
    // The face is a choice — the FLUID card, the round SOFT one
    // or the original look; exactly one exists at a time, and the PAM core
    // is the same.
    LazyLoader {
        active: (Config.lock.useBuiltin || Locker.locked) && ["fluid", "soft", "vibe"].indexOf(Locker.face) < 0

        LockScreen {}
    }

    LazyLoader {
        active: (Config.lock.useBuiltin || Locker.locked) && Locker.face === "fluid"

        FluidLock {}
    }

    // The SOFT face — no card, a big clock and a few round pills.
    LazyLoader {
        active: (Config.lock.useBuiltin || Locker.locked) && Locker.face === "soft"

        SoftLock {}
    }

    // The lock of the vibe you wear: a different face for every look, the same
    // PAM core under all of them.
    LazyLoader {
        active: (Config.lock.useBuiltin || Locker.locked) && Locker.face === "vibe"

        VibeLock {}
    }

    // Services that have to run whether or not a widget is looking at them —
    // the notification daemon, the Hyprland writer, night light, idle inhibit,
    // the palette extractor. A Quickshell singleton is instantiated the first
    // time something references it, and bindings are evaluated at load, so
    // naming them here is what starts them. (ShellRoot is not an Item, so
    // Component.onCompleted is not available on it.)
    readonly property var startedServices: [
        Config.loaded,
        Colours.accent,
        Notifs.unread,
        HyprConf.ready,
        Display.sunsetBackend,
        ZoomPlugin.ready,
        Sfx.player,
        Wallpapers.backend,
        SysInfo.cpuPercent,
        Net.type,
        Bluetooth.available,
        Tasks.openCount,
        Panels.settings,
        Binds.ready,
        Locker.pamState,
        Weather.ready,
        Toast.items,
        Focus.active,
        // Named here so the dialect probe runs at startup rather than
        // whenever some widget first happens to ask Hyprland for something.
        Dispatch.dialectName,
        Desk.ready,
        Scenes.loaded,
        Term.probed,
        Lyrics.ready,
        Looks.ready,
        // The controller's player slot is re-applied at login.
        Pad.player,
        // SETTINGS → LOOKS: loaded at start so `ipc call looks …` answers.
        Presets.loaded,
        // The assistant's shell side: starting the shell writes the closed
        // session file, so a stale session from a crash can never survive.
        Velly.active,
        // The audio-reactive layer: starting the shell starts the meter.
        Spectrum.available
    ]

    // ────────────────────────────────────────────────────────── the health check
    //  A QML file that fails to load does not fail where you can see it. Its
    //  name is still registered, so every call site gets
    //  "Property 'x' of object Y is not a function" from a hollow object — and
    //  the reason is a single line at the very top of a log that has already
    //  scrolled away under forty of those.
    //
    //  So the shell checks itself. Each of these names a singleton and one
    //  function it must have; anything missing is printed once, plainly, and
    //  said out loud on screen.
    readonly property var health: {
        const probes = [
            ["Config", Config, "get"],
            ["Dispatch", Dispatch, "act"],
            ["Hypr", Hypr, "focusWorkspace"],
            ["Desk", Desk, "refresh"],
            ["Scenes", Scenes, "launchAll"],
            ["Term", Term, "wrap"],
            ["Panels", Panels, "toggleSettings"],
            ["Binds", Binds, "display"],
            ["Colours", Colours, "alpha"],
            ["Spectrum", Spectrum, "at"],
            ["Velly", Velly, "wake"],
            ["Bridge", Bridge, "act"],
            ["Toast", Toast, "warn"],
            ["Actions", Actions, "restartShell"],
            ["Looks", Looks, "save"],
            ["Lyrics", Lyrics, "look"],
            ["Locker", Locker, "lock"],
            ["Focus", Focus, "toggle"],
            ["Wallpapers", Wallpapers, "scan"],
            ["Apps", Apps, "search"],
            ["Popout", Popout, "release"],
            ["Sfx", Sfx, "play"],
            ["HyprConf", HyprConf, "hex"]
        ];
        const dead = [];
        for (let i = 0; i < probes.length; i++) {
            const obj = probes[i][1];
            if (!obj || typeof obj[probes[i][2]] !== "function")
                dead.push(probes[i][0]);
        }
        if (dead.length > 0)
            console.warn("VELVET: these singletons did NOT load — everything that uses them "
                + "will report 'is not a function': " + dead.join(", "));
        return dead;
    }

    // Said on screen too, a beat after startup, because the terminal is not
    // where most of this gets run.
    LazyLoader {
        active: root.health.length > 0

        Timer {
            running: true
            interval: 2600
            onTriggered: {
                // If Toast itself is the singleton that failed to load, calling
                // it here would only add another "is not a function" to the
                // very log this message asks you to read.
                if (typeof Toast.show === "function")
                    Toast.show("SHELL INCOMPLETE  ·  " + root.health.join(", ").toUpperCase() + " DID NOT LOAD  ·  SEE THE TERMINAL", "error", 12000);
            }
        }
    }
}
