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
    readonly property var liveWatch: [Desk.status, Lyrics.status, Looks.count, Locker.status, Scenes.status, Term.status, Hypr.status, Tasks.pill, Velly.facts, Velly.sessions, Velly.brain, Monitors.status, SoundCheck.facts, LiveWalls.status, LiveWalls.thisLine, LiveWalls.thisMoves, LiveWalls.previewLine, NightShift.status, NightShift.screenLine, NightShift.lastLine, Books.shelfLine, Books.nowLine, Books.engineLine, Time.status, Net.lanLine, Net.onLan, Net.ssid]

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
            case "timeStatus":
                return Time.status;
            case "lanStatus":
                return `${Net.lanLine}  ·  ${Net.onLan ? "YOUR CONNECTION RUNS ON THE CABLE" : (Net.type === "wifi" && Net.connected ? "YOUR CONNECTION RUNS ON WI-FI" : "OFFLINE")}${Net.ownProfileExists ? "  ·  PROFILE: VELVET LAN" : ""}`;
            case "termStatus":
                return Term.status;
            case "dispatchStatus":
                return Hypr.status;
            case "screenStatus":
                return Monitors.status;
            case "liveStatus":
                return LiveWalls.status;
            case "liveThis":
                return LiveWalls.thisLine;
            case "liveThisMoves":
                return LiveWalls.thisMoves;
            case "livePromptRead":
                return LiveWalls.previewShort;
            case "nightStatus":
                return NightShift.status;
            case "nightScreen":
                return NightShift.screenLine;
            case "nightLast":
                return NightShift.lastLine;
            case "booksShelf":
                return Books.shelfLine;
            case "booksNow":
                return Books.nowLine;
            case "booksEngine":
                return Books.engineLine;
            case "soundVerdict":
                return SoundCheck.verdict;
            case "soundPlays":
                return SoundCheck.plays;
            case "soundDrops":
                return SoundCheck.dropLine;
            case "soundWifi":
                return SoundCheck.wifiLine;
            case "keepMusicQuality":
                return SoundCheck.keepQuality;
            case "lyricsStatus":
                return Lyrics.status === "SYNCED" ? `${Lyrics.lines.length} TIMED LINES` : Lyrics.status;
            case "looksCount":
                return `${Looks.count} SAVED${Looks.hasLook ? "  ·  THIS WALLPAPER HAS ONE" : ""}`;
            case "tasksPill":
                return Tasks.pill;
            case "vellyFacts":
                return `${Velly.facts} FACTS  ·  ${Velly.sessions} SESSIONS  ·  ${(Velly.brain || "—").toUpperCase()}`;
            }
            return 0;
        }
        if (item.valueKey)
            return Config.get(item.valueKey);
        // a text row shows its words — or what empty means
        if (item.kind === "text")
            return String(Config.get(item.key) ?? "").trim() || (item.empty ?? "—");
        if (item.key)
            return Config.get(item.key);
        return 0;
    }

    // the value itself, for an editor (get() dresses a text row up for the list)
    function raw(item: var): var {
        return item.key ? Config.get(item.key) : root.get(item);
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
            case "keepMusicQuality":
                SoundCheck.setKeepQuality(!!value);
                return;
            case "liveThisMoves":
                LiveWalls.setThisMoves(!!value);
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
        case "scratchOpen":
            Scratch.open();
            break;
        case "lanUse":
            Net.useLan(true);
            break;
        case "wifiUse":
            Net.useLan(false);
            break;
        case "lanApply":
            Net.applyLan();
            break;
        case "lanSystem":
            Net.lanBackToSystem();
            break;
        case "timeBackToSystem":
            Time.backToSystem();
            Toast.ok("THE SHELL SHOWS YOUR COMPUTER'S TIME AGAIN");
            break;
        case "takeLoginSong":
            LoginSong.takeNow();
            break;
        case "screensForget":
            Monitors.forget();
            break;
        case "liveMakeThis":
            LiveWalls.makeThis(false);
            break;
        case "liveRemakeThis":
            LiveWalls.makeThis(true);
            break;
        case "liveMakeAll":
            LiveWalls.makeFavourites(false);
            break;
        case "liveRemakeAll":
            LiveWalls.makeFavourites(true);
            break;
        case "liveMakePrompt":
            LiveWalls.makeWithPrompt();
            break;
        case "liveUndo":
            LiveWalls.undo();
            break;
        case "liveStop":
            LiveWalls.stop();
            Toast.show("VELLY STOPPED · HER QUEUE IS EMPTY", "info", 2600);
            break;
        case "liveOpenFolder":
            Actions.run(`mkdir -p "${LiveWalls.gifDir}" && xdg-open "${LiveWalls.gifDir}"`);
            break;
        case "liveDeleteAll":
            LiveWalls.removeAll();
            break;
        case "soundTest":
            SoundCheck.test();
            break;
        case "nightStartNow":
            NightShift.startNow();
            break;
        case "nightStop":
            NightShift.stop();
            break;
        case "screenOffNow":
            NightShift.screensOff();
            break;
        case "booksOpenShelf":
            Books.openShelf();
            break;
        case "booksMakeNow":
            Books.makeNow();
            break;
        case "booksInstallEngine":
            Books.installEngine();
            break;
        case "playLoginSong":
            LoginSong.playNow();
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
        case "fluidClassic":
        case "fluidGlass":
        case "fluidMinimal":
        case "fluidFloating":
            root.fluidStyle(item.fn);
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
        case "soundListen":
            Sfx.demo();
            break;
        case "soundFolder":
            // your own WAVs: the folder, with a note of the names
            Quickshell.execDetached(["bash", "-c", `mkdir -p "$1" && printf '%s\n' "Put a WAV here named like a sound to replace it:" "cursor select back toggle snap open close launch whoosh quest charge tick nope pop boing" "(e.g. select.wav). Back to the shell's own: delete the file." > "$1/README.txt"; xdg-open "$1"`, "sounds", Sfx.mine]);
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
    // LOCK SCREEN → FLUID LOCK → QUICK STYLES: one press dresses the cards,
    // the big card, the layout and the centre together. CLASSIC is the lock
    // as it was made; the module order and what each module shows stay yours.
    function fluidStyle(which: string): void {
        const classic = {
            "lock.tileCards": true,
            "lock.fluidCardStyle": "solid",
            "lock.fluidCardOpacity": 1,
            "lock.fluidCorners": "own",
            "lock.fluidWatermark": true,
            "lock.fluidHover": true,
            "lock.fluidPanel": 0.85,
            "lock.fluidSize": 0.7,
            "lock.fluidShape": "wide",
            "lock.fluidCentre": 1,
            "lock.fluidGap": 20,
            "lock.fluidFill": true,
            "lock.fluidAlign": "top",
            "lock.fluidAvatar": "large",
            "lock.fluidDate": "weekday",
            "lock.mediaIdle": "slim",
            "lock.notifsIdle": "slim",
            "lock.fluidDepth": 0.5,
            "lock.fluidGlow": true,
            "lock.fluidStagger": true,
            "lock.fluidDigits": "roll",
            "lock.fluidAurora": true
        };
        const dress = ({
                fluidClassic: {},
                fluidGlass: {
                    "lock.fluidCardStyle": "glass",
                    "lock.fluidCardOpacity": 0.85,
                    "lock.fluidCorners": "24",
                    "lock.fluidWatermark": false,
                    "lock.fluidPanel": 0.3,
                    "lock.fluidGap": 16,
                    "lock.fluidAvatar": "medium"
                },
                fluidMinimal: {
                    "lock.fluidCardStyle": "outline",
                    "lock.fluidCorners": "16",
                    "lock.fluidWatermark": false,
                    "lock.fluidPanel": 0,
                    "lock.fluidGap": 14,
                    "lock.fluidFill": false,
                    "lock.fluidAvatar": "small",
                    "lock.fluidDate": "short",
                    "lock.mediaIdle": "hide",
                    "lock.notifsIdle": "hide",
                    "lock.fluidDepth": 0.25,
                    "lock.fluidAurora": false,
                    "lock.fluidDigits": "fade"
                },
                fluidFloating: {
                    "lock.fluidCardStyle": "tinted",
                    "lock.fluidCardOpacity": 0.9,
                    "lock.fluidCorners": "32",
                    "lock.fluidPanel": 0,
                    "lock.fluidSize": 0.86,
                    "lock.fluidShape": "screen",
                    "lock.fluidCentre": 0.9,
                    "lock.fluidGap": 24,
                    "lock.fluidAvatar": "medium",
                    "lock.fluidDepth": 0.85
                }
            })[which] ?? {};
        Config.setMany(Object.assign({}, classic, dress));
        const names = {
            fluidClassic: "CLASSIC",
            fluidGlass: "GLASS",
            fluidMinimal: "MINIMAL",
            fluidFloating: "FLOATING"
        };
        Toast.ok(`FLUID LOCK · ${names[which] ?? "CLASSIC"}`);
    }

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
