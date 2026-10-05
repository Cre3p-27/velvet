//  VELVET  ·  services/Panels.qml
//  Which overlay is open, and every way to open it: Hyprland global shortcuts,
//  IPC from the terminal, or a click in the bar.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: root

    property bool settings: false
    // The welcome page (modules/welcome): once per login, if HOME → WELCOME
    // PAGE AT START is on. A marker in $XDG_RUNTIME_DIR (cleared at logout)
    // keeps a shell restart or a reload from showing it again.
    property bool welcome: false

    Process {
        id: welcomeCheck

        command: ["sh", "-c", 'm="${XDG_RUNTIME_DIR:-/tmp}/velvet-welcomed"; [ -e "$m" ] && echo seen || { touch "$m"; echo new; }']
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "new" && Config.home.welcome)
                    root.welcome = true;
            }
        }
    }
    Timer {
        // after the config is read, and a beat after the desktop came up
        interval: 2500
        running: Config.loaded
        onTriggered: welcomeCheck.running = true
    }
    property bool launcher: false
    property bool notifCentre: false
    property bool session: false

    // The window map lives on its own layer and does not belong to the
    // one-overlay-at-a-time rule: you open it by reaching for the top edge,
    // often while something else is up.
    property bool windowMap: false
    // The map reached for with the pointer (screen name). Separate from
    // `windowMap` on purpose: hovering must never take the keyboard.
    property string mapHover: ""

    // The Dynamic Island: which screen's pill is up ("" = none). It shares
    // the map's layer — the island hands its DESKTOP MAP module off to it.
    property string islandScreen: ""
    // One-off module request for the active island (IPC/test hook; -1 = none).
    property int islandSetModule: -1
    // One-off expand request (IPC/test hook; -2 = none).
    property int islandSetExpand: -2

    // The wallpaper wheel and the lyrics panel, same idea.
    property bool wheel: false

    // The desktop's right-click menu: the screen it is up on ("" = closed)
    // and the pixel under the pointer there.
    property string deskMenuScreen: ""
    property real deskMenuX: 0
    property real deskMenuY: 0

    // Settings remembers where you were, so Super+Tab twice returns you there.
    property int settingsTab: 0

    // Set by the launcher when you pick a setting out of its results; Settings
    // consumes it on open and jumps straight to that row.
    property var pendingSetting: null

    function openSettingsAt(entry: var): void {
        root.pendingSetting = entry;
        root.closeAll();
        root.settings = true;
    }

    // Jump straight to one setting by its config key. Used by bar modules that
    // want their own right-click to land on the thing they control.
    function openSettingsKey(key: string): void {
        const flat = Schema.flat;
        for (let i = 0; i < flat.length; i++) {
            if (flat[i].item.key === key) {
                root.openSettingsAt(flat[i]);
                return;
            }
        }
        root.toggleSettings();
    }

    // Same, by the row's visible name — for modules whose "setting" is really
    // just "where do I sit on the bar".
    function openSettingsNamed(name: string): void {
        const flat = Schema.flat;
        for (let i = 0; i < flat.length; i++) {
            if (flat[i].item.name === name) {
                root.openSettingsAt(flat[i]);
                return;
            }
        }
        root.toggleSettings();
    }

    // Open the settings menu on a whole tab rather than on one row — used by
    // the tabs that are an editor rather than a list.
    property string pendingTab: ""

    function openSettingsTabNamed(name: string): void {
        root.pendingTab = name;
        root.closeAll();
        root.settings = true;
    }

    // Same idea for the settings window's three rooms: SETTINGS, WORKFLOW
    // and QUICK SETTINGS. A deep link names the room it wants; the window
    // consumes this on open and lands there instead of on SETTINGS.
    property string pendingZone: ""
    // The QUICK room can be asked to start on a specific section.
    property string pendingQuickSection: ""
    // A deep link may ask the settings window to raise the face picker.
    property bool pendingFacePicker: false

    function openSettingsZoneNamed(name: string): void {
        root.pendingZone = `${name ?? ""}`.trim().toUpperCase();
        root.closeAll();
        root.settings = true;
    }

    // ── staying on your desktop ──────────────────────────────────────────
    //  An overlay takes the keyboard while it is open. Closing it hands the
    //  keyboard back, and Hyprland gives it to the window that had it last —
    //  even on another desktop, which it then switches to: on a desktop with
    //  only click-through modules, closing Super+Tab landed on desktop 2
    //  (where the browser was). Unless the shell itself sent you somewhere,
    //  you stay on the desktop you opened the overlay on. The window is
    //  short, so a workspace you pick yourself right after is left alone.
    // (The settings window is a window: it never holds the keyboard hostage.)
    readonly property bool anyOpen: root.launcher || root.notifCentre || root.session || root.wheel || root.keys || root.deskMenuScreen !== ""
    property int wsAtOpen: -1
    property real closedAt: 0

    onAnyOpenChanged: {
        if (root.anyOpen) {
            root.wsAtOpen = Hypr.activeWsId;
            wsGuard.stop();
        } else {
            root.closedAt = Date.now();
            wsGuard.restart();
        }
    }

    Timer {
        id: wsGuard

        interval: 900
    }

    Connections {
        target: Hypr

        function onActiveWsIdChanged(): void {
            if (!wsGuard.running || root.anyOpen || root.wsAtOpen <= 0 || Hypr.activeWsId === root.wsAtOpen)
                return;
            wsGuard.stop();
            // The shell asked for this jump (WORKFLOW's sectors, a window
            // picked from a list) — that one is wanted.
            if (Hypr.lastJumpAt >= root.closedAt - 2000)
                return;
            Hypr.focusWorkspace(root.wsAtOpen);
        }
    }

    // Closes the overlays — the launcher, the centre, the menus. The settings
    // WINDOW stays: doing something else never closes it (v8.40); only its own
    // close button, Escape on HOME, Super+Tab or closeSettings() do.
    function closeAll(): void {
        root.launcher = false;
        root.notifCentre = false;
        root.session = false;
        root.wheel = false;
        root.keys = false;
        root.deskMenuScreen = "";
        root.islandScreen = "";
    }

    function toggleWelcome(): void {
        root.welcome = !root.welcome;
    }

    function closeSettings(): void {
        root.settings = false;
    }

    // Everything, the settings window too (the "close" shortcut).
    function closeEverything(): void {
        root.closeAll();
        root.settings = false;
    }

    function openDeskMenu(screenName: string, x: real, y: real): void {
        root.closeAll();
        root.deskMenuX = x;
        root.deskMenuY = y;
        root.deskMenuScreen = screenName;
    }

    function toggleSettings(): void {
        // The window is open on another desktop: Super+Tab brings it here
        // instead of closing it out of sight.
        if (root.settings) {
            // (Hyprland's own toplevels: live, unlike the desk's polled list)
            const tops = Hyprland.toplevels?.values ?? [];
            const t = tops.find(x => (x?.title ?? "") === "Velvet Settings");
            const ws = t?.workspace?.id ?? -1;
            if (t && ws > 0 && ws !== Hypr.activeWsId) {
                const a = "0x" + String(t.address ?? t.lastIpcObject?.address ?? "").replace(/^0x/, "");
                Hypr.sendToWorkspace(a, Hypr.activeWsId);
                Hypr.focusWindow(a);
                return;
            }
        }
        const next = !root.settings;
        closeAll();
        root.settings = next;
    }

    function toggleLauncher(): void {
        if (!Config.launcher.enabled)
            return;
        const next = !root.launcher;
        closeAll();
        root.launcher = next;
    }

    function toggleNotifCentre(): void {
        const next = !root.notifCentre;
        closeAll();
        root.notifCentre = next;
    }

    function toggleSession(): void {
        const next = !root.session;
        closeAll();
        root.session = next;
    }

    function toggleWindowMap(): void {
        root.windowMap = !root.windowMap;
    }

    function toggleWheel(): void {
        if (!Config.wallpaper.wheel)
            return;
        const next = !root.wheel;
        closeAll();
        root.wheel = next;
    }

    // ------------------------------------------------------------- shortcuts
    GlobalShortcut {
        name: "settings"
        description: "Open the Velvet settings menu"
        onPressed: root.toggleSettings()
    }

    GlobalShortcut {
        name: "launcher"
        description: "Open the Velvet app launcher"
        onPressed: root.toggleLauncher()
    }

    GlobalShortcut {
        name: "notifications"
        description: "Open the Velvet notification centre"
        onPressed: root.toggleNotifCentre()
    }

    GlobalShortcut {
        name: "session"
        description: "Open the Velvet session menu"
        onPressed: root.toggleSession()
    }

    GlobalShortcut {
        name: "wheel"
        description: "Open the Velvet wallpaper wheel"
        onPressed: root.toggleWheel()
    }

    GlobalShortcut {
        name: "close"
        description: "Close any open Velvet overlay"
        onPressed: root.closeAll()
    }

    // The shortcut list, reachable from anywhere rather than only from inside
    // the settings menu.
    property bool keys: false

    function toggleKeys(): void {
        root.keys = !root.keys;
    }

    // ------------------------------------------------------------------- ipc
    //   qs -c velvet ipc call panels settings
    IpcHandler {
        target: "panels"

        function welcome(): void {
            root.toggleWelcome();
        }
        function settings(): void {
            root.toggleSettings();
        }
        function launcher(): void {
            root.toggleLauncher();
        }
        function notifications(): void {
            root.toggleNotifCentre();
        }
        function session(): void {
            root.toggleSession();
        }
        function close(): void {
            root.closeAll();
        }
        function wheel(): void {
            root.toggleWheel();
        }
        function tab(name: string): void {
            root.openSettingsTabNamed(name);
        }
        function zone(name: string): void {
            root.openSettingsZoneNamed(name);
        }
        function map(): void {
            root.toggleWindowMap();
        }
        function keys(): void {
            root.toggleKeys();
        }
    }

    // Each panel also answers to its own name, because `ipc call wheel toggle`
    // is what anyone writing a keybind reaches for first — and the keybinds
    // this shell ships did exactly that while only `panels wheel` existed.
    IpcHandler {
        target: "wheel"

        function toggle(): void {
            root.toggleWheel();
        }
    }

    IpcHandler {
        target: "map"

        function toggle(): void {
            root.toggleWindowMap();
        }
    }

    IpcHandler {
        target: "keys"

        function toggle(): void {
            root.toggleKeys();
        }
    }

    // The island answers IPC too: `qs -c velvet ipc call island pop <name>`
    // (empty name = first screen), `hide`, and `module <idx>`.
    IpcHandler {
        target: "island"

        function pop(name: string): void {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++) {
                if (name === "" || screens[i].name === name) {
                    root.islandScreen = screens[i].name;
                    return;
                }
            }
        }
        function hide(): void {
            root.islandScreen = "";
        }
        function module(idx: int): void {
            root.islandSetModule = idx;
        }
        function expand(idx: int): void {
            root.islandSetExpand = idx;
        }
    }

    GlobalShortcut {
        name: "keys"
        description: "Show every Velvet shortcut"
        onPressed: root.toggleKeys()
    }
}
