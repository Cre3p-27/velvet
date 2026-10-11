//  VELVET  ·  services/Bridge.qml
//  The one place that knows how a schema entry maps onto an actual value.
//  Rows call get/set/act and stay completely dumb.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Bumped whenever a live (non-Config) value changes, so bindings that read
    // through get() re-evaluate.
    property int revision: 0

    Connections {
        target: Audio
        function onVolumeChangedByUser(): void {
            root.revision++;
        }
        function onMicChangedByUser(): void {
            root.revision++;
        }
    }

    // Live rows read through `revision`, so anything that can change behind
    // the settings menu's back has to bump it.
    readonly property var liveWatch: [Desk.status, Lyrics.status, Looks.count, Locker.status, Scenes.status, Term.status, Hypr.status, Tasks.pill, Velly.facts, Velly.sessions, Velly.brain]

    onLiveWatchChanged: root.revision++

    Connections {
        target: Brightness
        function onChangedByUser(): void {
            root.revision++;
        }
    }

    function get(item: var): var {
        root.revision;  // dependency
        if (item.live) {
            switch (item.live) {
            case "volume":
                return Audio.volume;
            case "micVolume":
                return Audio.micVolume;
            case "muteSpeaker":
                return Audio.muted;
            case "muteMic":
                return Audio.micMuted;
            case "brightness":
                return Brightness.brightness;
            case "lockStatus":
                return Locker.status;
            case "lockError":
                return Locker.pamError || "—";
            case "version":
                return Build.loaded ? Build.version : "VERSION FILE MISSING";
            case "deskStatus":
                return Desk.status;
            case "sceneStatus":
                return Scenes.status;
            case "termStatus":
                return Term.status;
            case "dispatchStatus":
                return Hypr.status;
            case "lyricsStatus":
                return Lyrics.status === "SYNCED" ? `${Lyrics.lines.length} TIMED LINES` : Lyrics.status;
            case "looksCount":
                return `${Looks.count} SAVED${Looks.hasLook ? "  ·  THIS WALLPAPER HAS ONE" : ""}`;
            case "tasksPill":
                return Tasks.pill;
            case "vellyFacts":
                return `${Velly.facts} FAKTEN  ·  ${Velly.sessions} SESSIONS  ·  ${(Velly.brain || "—").toUpperCase()}`;
            }
            return 0;
        }
        if (item.valueKey)
            return Config.get(item.valueKey);
        if (item.key)
            return Config.get(item.key);
        return 0;
    }

    function set(item: var, value: var): void {
        if (item.live) {
            switch (item.live) {
            case "volume":
                Audio.setVolume(value);
                return;
            case "micVolume":
                Audio.setMicVolume(value);
                return;
            case "muteSpeaker":
                if (Audio.muted !== value)
                    Audio.toggleMute();
                return;
            case "muteMic":
                if (Audio.micMuted !== value)
                    Audio.toggleMicMute();
                return;
            case "brightness":
                Brightness.setBrightness(value);
                return;
            }
            return;
        }
        // The Windows edition is a whole look, not one value.
        if (item.key === "appearance.winVersion") {
            Presets.setWinVersion(`${value}`);
            return;
        }
        if (item.key)
            Config.set(item.key, value);
    }

    // 0..1 position of a slider, from its real value.
    function fraction(item: var): real {
        const v = Number(root.get(item));
        const lo = item.min ?? 0;
        const hi = item.max ?? 1;
        if (hi === lo)
            return 0;
        return Math.max(0, Math.min(1, (v - lo) / (hi - lo)));
    }

    function fromFraction(item: var, f: real): real {
        const lo = item.min ?? 0;
        const hi = item.max ?? 1;
        const step = item.step ?? 0.01;
        const raw = lo + (hi - lo) * Math.max(0, Math.min(1, f));
        const snapped = Math.round(raw / step) * step;
        return Math.max(lo, Math.min(hi, Number(snapped.toFixed(6))));
    }

    // `times` is how many steps at once — Ctrl+arrow moves in tens so a slider
    // with a wide range is not a hundred keypresses wide.
    function nudge(item: var, direction: int, times: int): void {
        const step = (item.step ?? 0.01) * Math.max(1, times);
        const lo = item.min ?? 0;
        const hi = item.max ?? 1;
        const next = Math.max(lo, Math.min(hi, Number(root.get(item)) + step * direction));
        root.set(item, Number(next.toFixed(6)));
    }

    function display(item: var): string {
        const v = root.get(item);
        const unit = item.unit ?? "";
        switch (item.fmt) {
        case "percent":
            return `${Math.round(Number(v) * 100)}%`;
        case "int":
            return `${Math.round(Number(v))}${unit}`;
        case "float1":
            return `${Number(v).toFixed(1)}${unit}`;
        case "float2":
            return `${Number(v).toFixed(2)}${unit}`;
        default:
            return `${v}${unit}`;
        }
    }

    function choiceLabel(item: var): string {
        const v = root.get(item);
        const opts = item.options ?? [];
        for (let i = 0; i < opts.length; i++)
            if (opts[i].value === v)
                return opts[i].label;
        return `${v}`.toUpperCase();
    }

    function cycleChoice(item: var, direction: int): void {
        const opts = item.options ?? [];
        if (opts.length === 0)
            return;
        const v = root.get(item);
        let i = 0;
        for (let k = 0; k < opts.length; k++)
            if (opts[k].value === v)
                i = k;
        const next = (i + direction + opts.length) % opts.length;
        root.set(item, opts[next].value);
    }

    // Fired for action rows.
    // The colour row had a swatch and no way to change it: left and right fell
    // through to "go back a level", so the one setting whose whole job is to
    // pick a colour could not pick one.
    function shiftHue(item: var, direction: int, times: int): void {
        const key = item.valueKey ?? item.key;
        if (!key)
            return;
        const c = Config.get(key);
        const col = Qt.color(c ?? "#e4002b");
        const step = (times > 1 ? 0.055 : 0.012) * (direction > 0 ? 1 : -1);
        const hue = ((col.hslHue < 0 ? 0 : col.hslHue) + step + 1) % 1;
        Config.set("appearance.accentSource", "manual");
        Config.set(key, Qt.hsla(hue, Math.max(0.35, col.hslSaturation), Math.min(0.72, Math.max(0.34, col.hslLightness)), 1).toString());
        root.revision++;
    }

    function setHue(item: var, hue: real): void {
        const key = item.valueKey ?? item.key;
        if (!key)
            return;
        const col = Qt.color(Config.get(key) ?? "#e4002b");
        Config.set("appearance.accentSource", "manual");
        Config.set(key, Qt.hsla(hue, Math.max(0.5, col.hslSaturation), Math.min(0.68, Math.max(0.4, col.hslLightness)), 1).toString());
        root.revision++;
    }

    function act(item: var): void {
        if (item.exec) {
            Actions.run(item.exec);
            return;
        }
        switch (item.fn) {
        case "lock":
            Actions.lock();
            break;
        case "suspend":
            Actions.suspend();
            break;
        case "hibernate":
            Actions.hibernate();
            break;
        case "reboot":
            Actions.reboot();
            break;
        case "shutdown":
            Actions.shutdown();
            break;
        case "logout":
            Actions.logout();
            break;
        case "reloadHyprland":
            Actions.reloadHyprland();
            break;
        case "restartShell":
            Actions.restartShell();
            break;
        case "randomWallpaper":
            Wallpapers.random();
            break;
        case "rescanWallpapers":
            Wallpapers.scan();
            break;
        case "testLock":
            Locker.testLock();
            break;
        case "openLayoutTab":
            // LAYOUT is a page inside TASKBAR now; the name is the page's.
            Panels.openSettingsTabNamed("ARRANGE MODULES");
            break;
        case "openWallpaperTab":
            Panels.openSettingsTabNamed("PER WALLPAPER");
            break;
        case "openDesktopTab":
            Panels.openSettingsTabNamed("DESKTOP");
            break;
        case "sceneStart":
            Scenes.launchAll(false);
            break;
        case "sceneRestart":
            Scenes.launchAll(true);
            break;
        case "sceneCapture":
            Scenes.captureOpen();
            break;
        case "sceneClear":
            Scenes.clearScene();
            Toast.show("DESKTOP CLEARED FOR THIS WALLPAPER", "info", 2600);
            break;
        case "sceneEverywhere":
            Scenes.makeDefault();
            break;
        case "openMap":
            Panels.toggleWindowMap();
            break;
        case "openWheel":
            Panels.toggleWheel();
            break;
        case "openLauncher":
            Panels.toggleLauncher();
            break;
        case "islandJoinFrame":
            // the island, the screen frame and the bar as one surface
            Config.setMany({
                "bar.frame": true,
                "bar.frameConnect": true,
                "map.islandFrame": true,
                "map.islandDock": true
            });
            Toast.ok("ISLAND, FRAME AND BAR ARE ONE SURFACE NOW");
            break;
        case "resetLauncherLook":
            // only the look-and-motion dials; what it searches stays yours
            Config.setMany({
                "launcher.scale": 1,
                "launcher.speed": 1,
                "launcher.dim": 1,
                "launcher.aura": 0.6,
                "launcher.highlight": true,
                "launcher.quickKeys": true,
                "launcher.subtitles": true,
                "launcher.hints": true,
                "launcher.launchFx": "burst",
                "launcher.entrance": "auto",
                "launcher.cascade": "slide",
                "launcher.motion": "spring",
                "launcher.position": "auto",
                "launcher.preview": true,
                "launcher.orbitEntrance": "bloom",
                "launcher.orbitSpin": 1,
                "launcher.orbitTilt": 1,
                "launcher.orbitRing": true,
                "launcher.reticle": true,
                "launcher.stars": true
            });
            Toast.ok("THE LAUNCHER LOOKS AND MOVES AS DESIGNED AGAIN");
            break;
        case "resetThisLook":
            if (Presets.resetTune())
                Toast.ok("THIS LOOK IS BACK AS IT WAS DESIGNED");
            else
                Toast.show("NOTHING TO RESET — NO LOOK IS ON", "info", 2400);
            break;
        case "saveLook":
            Looks.save();
            Toast.ok("LOOK SAVED FOR THIS WALLPAPER");
            break;
        case "forgetLook":
            Looks.forget();
            Toast.show("LOOK FORGOTTEN", "info", 2400);
            break;
        case "resetSoftArrangement":
            Config.setMany({
                "lock.softStyle": {},
                "lock.softPlace": {},
                "lock.layout": Config.lock.layout === "custom" ? "vertical" : Config.lock.layout
            });
            Toast.show("SOFT LOCK · BACK TO ITS LAYOUT'S OWN ARRANGEMENT", "info", 2400);
            break;
        case "forgetAllLooks":
            Looks.forgetAll();
            Toast.show("EVERY LOOK FORGOTTEN", "warn", 3000);
            break;
        case "refetchLyrics":
            Lyrics.lastKey = "";
            Lyrics.look();
            Toast.show("LOOKING FOR LYRICS…", "info", 2000);
            break;
        case "openBluetooth":
            // The in-shell bluetooth panel: pairing, connecting, trust —
            // everything blueman used to be for, without the app.
            Panels.pendingQuickSection = "bluetooth";
            Panels.openSettingsZoneNamed("QUICK");
            break;
        case "openQuick":
            Panels.openSettingsZoneNamed("QUICK");
            break;
        case "openWorkflow":
            Panels.openSettingsZoneNamed("WORKFLOW");
            break;
        case "updateVelvet":
            Updates.run();
            break;
        case "resetSettings":
            // Written while the shell is down, so its own in-memory settings
            // cannot be saved back over the fresh file on the way out.
            Quickshell.execDetached(["bash", "-c", `cfg="$1"; walls="$2"
qs -c velvet kill >/dev/null 2>&1
for i in $(seq 40); do qs -c velvet ipc show >/dev/null 2>&1 || break; sleep 0.2; done
[ -f "$cfg" ] && mv -f "$cfg" "$cfg.before-reset-$(date +%Y%m%d-%H%M%S)"
python3 "$3" "$cfg" "$walls" >/dev/null 2>&1 || printf '{}\n' > "$cfg"
setsid -f "$4" >/dev/null 2>&1`, "velvet", Config.path, Config.wallpaper.directory, Quickshell.shellPath("tools/seed-config.py"), Quickshell.shellPath("bin/velvet-session")]);
            break;
        case "uninstall": {
            // in a terminal, so its questions (and the password) can be answered
            const line = Term.wrap("dev.velvet.uninstall", "velvet-uninstall", `bash ${Quickshell.shellPath("uninstall.sh")}`, "");
            if (line)
                Quickshell.execDetached(["sh", "-c", line]);
            else
                Toast.show("NO TERMINAL FOUND  ·  RUN:  bash ~/.config/quickshell/velvet/uninstall.sh", "error", 9000);
            break;
        }
        case "openWelcome":
            Panels.welcome = true;
            break;
        case "openHome":
            Panels.openSettingsZoneNamed("HOME");
            break;
        case "openFacePicker":
            Panels.pendingFacePicker = true;
            Panels.openSettingsZoneNamed("HOME");
            break;
        case "vellySetup":
            // Setup needs somewhere to type, and the only text field this
            // shell owns that is also the assistant's own body is the island.
            Velly.setupOpen = true;
            showIsland();
            Velly.wake();
            break;
        case "vellyWake":
            showIsland();
            Velly.wake();
            break;
        case "vellyTest":
            Velly.probe();
            Toast.show("FRAGE DEN ANBIETER…", "info", 2000);
            break;
        case "vellyForgetFacts":
            Velly.forgetAll();
            break;
        case "vellyPrune":
            pruneProc.running = false;
            pruneProc.running = true;
            break;
        }
    }

    // The island exists once per screen, and a settings row has to name the
    // one the pointer is on: the focused screen first, the first screen as the
    // floor. Velly is then told the module is wanted — the island picks that up
    // whether it was already up or is only waking now.
    function showIsland(): void {
        const screen = Hypr.focusedScreen ?? Quickshell.screens[0];
        Panels.islandScreen = screen?.name ?? "";
        Velly.wantIsland = true;
    }

    // SPEICHER FREIGEBEN: velvet-local deletes the brain sizes nobody uses and
    // says how much that was.
    Process {
        id: pruneProc

        command: ["python3", Quickshell.shellPath("bin/velvet-local"), "prune"]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = null;
                try {
                    r = JSON.parse(this.text);
                } catch (e) {}
                if (!r)
                    Toast.show("COULD NOT FREE THE SPACE — SEE velvet-local prune", "error", 5000);
                else if (r.freed_mb > 0)
                    Toast.show(`${(r.freed_mb / 1024).toFixed(1)} GB FREED — KEPT: ${r.kept.join(", ").toUpperCase()}`, "info", 5000);
                else
                    Toast.show("NOTHING TO FREE — ONLY THE MODELS IN USE ARE ON DISK", "info", 4000);
            }
        }
    }
}
