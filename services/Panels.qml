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
    // Which screens' taskbars are out right now (pinned, or slid out on a
    // hover): { "HDMI-A-1": true }. The screen frame widens its band on the
    // bar's edge with it, and a docked island rides out on that band.
    property var barOut: ({})

    function setBarOut(name: string, out: bool): void {
        if (!name || (root.barOut[name] === true) === out)
            return;
        const next = Object.assign({}, root.barOut);
        next[name] = out;
        root.barOut = next;
    }

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
    // ARRANGE: the desk lifted off the screen to be arranged by hand
    // (modules/wallpaper/DeskArrange.qml) — the screen it is on, "" = closed
    property string arrangeScreen: ""
    property real deskMenuX: 0
    property real deskMenuY: 0
    // the desktop widget a right-click was on (its id in the live desk);
    // "" = the bare desktop's menu
    property string deskMenuWidget: ""

    // ───────────────────────────────────────────────────── screen recording
    //  Super+Enter (hypr/scripts/velvet-record.sh) asks the shell first: a
    //  countdown, 3 · 2 · 1 in the middle of the screen (modules/osd/
    //  RecordCountdown.qml), gone before the recorder starts — so it never ends
    //  up in the video. A second press during it cancels. SHELL → SCREEN
    //  RECORDING sets the seconds (0 = the short note as before).
    property int recordLeft: 0
    property int recordFrom: 0
    property bool recording: false

    Timer {
        id: recordTick

        interval: 1000
        repeat: true
        onTriggered: {
            root.recordLeft = Math.max(0, root.recordLeft - 1);
            if (root.recordLeft <= 0)
                recordTick.stop();
            else if (Config.record.sound)
                Sfx.cursor();
        }
    }

    function recordBegin(): int {
        const n = Math.max(0, Math.min(10, Math.round(Config.record.countdown)));
        if (n <= 0)
            return 0;
        // an open launcher or menu would be in the first frames: they go
        root.closeAll();
        root.recordFrom = n;
        root.recordLeft = n;
        recordTick.restart();
        if (Config.record.sound)
            Sfx.cursor();
        return n;
    }

    function recordCancel(): void {
        recordTick.stop();
        root.recordLeft = 0;
    }

    //   qs -c velvet ipc call record begin   (the script's question: seconds to wait)
    IpcHandler {
        target: "record"

        function begin(): string {
            return String(root.recordBegin());
        }
        function cancel(): void {
            root.recordCancel();
            Toast.show("RECORDING CANCELLED", "info", 1600);
        }
        function started(): void {
            root.recording = true;
        }
        function stopped(): void {
            root.recording = false;
        }
    }

    // Settings remembers where you were, so Super+Tab twice returns you there.
    property int settingsTab: 0

    // Set by the launcher when you pick a setting out of its results; Settings
    // consumes it on open and jumps straight to that row.
    property var pendingSetting: null

    function openSettingsAt(entry: var): void {
        root.pendingSetting = entry;
        root.showSettings();
    }

    // The settings window is a real window since v8.40 and may already be
    // open — then the flag does not change and nothing would happen. A deep
    // link asks the open window to go there, and fetches it to this desktop.
    signal settingsAsked

    function showSettings(): void {
        root.closeAll();
        if (!root.settings) {
            root.settings = true;
            return;
        }
        const tops = Hyprland.toplevels?.values ?? [];
        const t = tops.find(x => (x?.title ?? "") === "Velvet Settings");
        const ws = t?.workspace?.id ?? -1;
        if (t) {
            const a = "0x" + String(t.address ?? t.lastIpcObject?.address ?? "").replace(/^0x/, "");
            if (ws > 0 && ws !== Hypr.activeWsId)
                Hypr.sendToWorkspace(a, Hypr.activeWsId);
            Hypr.focusWindow(a);
        }
        root.settingsAsked();
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
        root.showSettings();
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
        root.showSettings();
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
    readonly property bool anyOpen: root.launcher || root.notifCentre || root.session || root.wheel || root.keys || root.deskMenuScreen !== "" || root.arrangeScreen !== ""
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
    // the secret aim trainer (modules/aim)
    property bool aim: false

    function openAim(): void {
        root.closeAll();
        root.aim = true;
    }

    // ↑ ↑ ↓ ↓ ← → ← → B A, fed by whatever has the keyboard (the island)
    property var konami: []
    function konamiKey(key: int): bool {
        const code = [Qt.Key_Up, Qt.Key_Up, Qt.Key_Down, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Left, Qt.Key_Right, Qt.Key_B, Qt.Key_A];
        const k = root.konami.concat([key]).slice(-code.length);
        root.konami = k;
        if (k.length === code.length && k.every((v, i) => v === code[i])) {
            root.konami = [];
            root.openAim();
            return true;
        }
        return false;
    }

    function closeAll(): void {
        root.launcher = false;
        root.notifCentre = false;
        root.session = false;
        root.wheel = false;
        root.keys = false;
        root.deskMenuScreen = "";
        root.islandScreen = "";
        root.arrangeScreen = "";
    }

    function openArrange(screenName: string): void {
        root.closeAll();
        root.arrangeScreen = screenName || Hypr.focusedScreen?.name || Quickshell.screens[0]?.name || "screen";
    }

    function closeArrange(): void {
        root.arrangeScreen = "";
    }

    function toggleWelcome(): void {
        root.welcome = !root.welcome;
    }

    function closeSettings(): void {
        root.settings = false;
    }

    // A whole tab, by its name (e.g. "WIDGET STUDIO"): the window opens there.
    signal settingsTabAsked(int index)

    function openSettingsTab(name: string): void {
        const i = Schema.tabs.findIndex(t => t.name === name);
        if (i < 0)
            return;
        root.showSettings();
        root.settingsTabAsked(i);
    }

    // The settings window's own close button (×). While a full-window tab is
    // up (LOOKS, PER WALLPAPER, DESKTOP …) it closes that tab and takes you
    // back to where you were — the window itself stays (Settings answers
    // settingsCloseAsked). Anywhere else it closes the window.
    property bool settingsHasPane: false
    signal settingsCloseAsked

    function askCloseSettings(): void {
        if (root.settings && root.settingsHasPane) {
            root.settingsCloseAsked();
            return;
        }
        root.settings = false;
    }

    // Everything, the settings window too (the "close" shortcut).
    function closeEverything(): void {
        root.closeAll();
        root.settings = false;
    }

    function openDeskMenu(screenName: string, x: real, y: real): void {
        root.closeAll();
        root.deskMenuWidget = "";
        root.deskMenuX = x;
        root.deskMenuY = y;
        root.deskMenuScreen = screenName;
    }

    // A right-click on a desktop widget: its own menu, at the pointer
    // (modules/wallpaper/WidgetMenuCard.qml).
    function openWidgetMenu(screenName: string, x: real, y: real, id: string): void {
        root.closeAll();
        root.deskMenuWidget = id;
        root.deskMenuX = x;
        root.deskMenuY = y;
        root.deskMenuScreen = screenName;
    }

    // DESKTOP opened for one widget: the tab picks it (DesktopTab.qml)
    property string pendingDeskItem: ""

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

    // With the Dynamic Island on, the map IS the island's DESKTOP module:
    // the shortcut, the bar's button and the menus open it there (and close
    // it again), so there is one map, in one place. Island off: the plate.
    property bool islandWantMap: false
    // the island's map is open (the island says so) — for the bar's button
    property bool islandMapOpen: false

    function toggleWindowMap(): void {
        if (Config.map.enabled && Config.map.island) {
            if (root.islandMapOpen) {
                root.islandScreen = "";
                return;
            }
            const scr = Hypr.focusedScreen ?? (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null);
            if (!scr)
                return;
            root.windowMap = false;
            root.islandWantMap = true;
            root.islandScreen = scr.name;
            return;
        }
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
        // `panels key map.islandDock` opens the settings right at that row
        function key(name: string): void {
            root.openSettingsKey(name);
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
        function aim(): void {
            root.openAim();
        }
        // the desk, lifted to be arranged by hand
        function arrange(): void {
            if (root.arrangeScreen !== "")
                root.closeArrange();
            else
                root.openArrange("");
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
    // (empty name = first screen), `hide`, `module <idx>`, and `state`
    // (where it is open, or "closed").
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
        function state(): string {
            return root.islandScreen === "" ? "closed" : `open on ${root.islandScreen}`;
        }
    }

    GlobalShortcut {
        name: "keys"
        description: "Show every Velvet shortcut"
        onPressed: root.toggleKeys()
    }
}
