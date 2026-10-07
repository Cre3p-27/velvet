//  VELVET  ·  config/Shortcuts.qml
//  Every shortcut in the shell, in one table. The help overlay renders this
//  and nothing else, so the list you see is the list that exists — the
//  ANYWHERE section reads its combos straight from the bind service, which
//  is what the key menu (Super+Shift+K) edits.
//
//  Named Shortcuts, not Keys: `Keys` is QML's own attached type for key
//  handling, and a singleton by that name shadows it wherever both are in
//  scope — including inside this shell's own Keys.onPressed handlers.
pragma Singleton

import qs.services
import Quickshell
import QtQuick

Singleton {
    id: root

    function k(key: string, what: string): var {
        return {
            k: key,
            v: what
        };
    }

    readonly property var sections: [
        {
            name: "ANYWHERE",
            sub: "CHANGE THEM IN THE KEY MENU  ·  SUPER + SHIFT + K",
            keys: [root.k("Super + Alt + scroll", "Zoom the windows in and out (the bar stays) · zoomed, everything works as usual"), root.k("Super + Alt + left click", "Back to 1:1"), root.k("Super + Alt + right click", "Zoom out until every window shows"), root.k("Super + Z / X", "Previous / next desktop (Shift takes the window along)"), root.k("Super + D", "Floating windows ⇄ tiled"), root.k("Super + Shift / Ctrl / Alt + arrows", "Move the window · jump to the next one · swap places with its neighbour"), root.k(Binds.display("settings"), "Settings"), root.k(Binds.display("launcher"), "Launcher"), root.k(Binds.display("notifications"), "Notifications"), root.k(Binds.display("session"), "Power menu"), root.k(Binds.display("lock"), "Lock the screen"), root.k(Binds.display("record"), "Record · stop recording"), root.k(Binds.display("focus"), "Focus mode on · off"), root.k(Binds.display("wheel"), "Wallpaper wheel"), root.k(Binds.display("windowMap"), "The mini desktop"), root.k(Binds.display("scene"), "Open the desktop you arranged"), root.k(Binds.display("lyrics"), "Lyrics"), root.k(Binds.display("keys"), "This list, from anywhere")]
        },
        {
            name: "SETTINGS",
            sub: "SUPER + TAB",
            keys: [root.k("↑ ↓", "Move the cursor"), root.k("← →", "Adjust · step a choice · switch · open a page"), root.k("Ctrl + ← →", "Adjust in big steps"), root.k("Enter", "Open a page · show a slider or all the options · toggle"), root.k("Space", "Toggle"), root.k("click", "The same as Enter, on the row you click"), root.k("‹ ›  − +", "Step without opening"), root.k("wheel", "Scrolls the list — never changes a value"), root.k("Esc  Backspace", "Back a step: close a slider, leave a page · then out"), root.k("mouse back button", "Back a step (never closes the menu)"), root.k("PgUp PgDn", "Jump five rows"), root.k("Home End", "First · last row"), root.k("Tab", "Next category"), root.k("Ctrl + 1…9", "Jump to a category"), root.k("any letter", "Search every setting and page"), root.k("F1  or  ?", "This list")]
        },
        {
            name: "THE MINI DESKTOP",
            sub: "TOP EDGE, OR SUPER + SHIFT + M",
            keys: [root.k("click a window", "Go to it"), root.k("drag a window", "Move it · drop it on another desktop to send it there"), root.k("click bare desktop", "Switch to that desktop"), root.k("scroll", "Zoom out to the other desktops, and back"), root.k("drag bare desktop", "Move around"), root.k("middle-click", "Close that window"), root.k("← → ↑ ↓", "Pick, by where it is"), root.k("Enter", "Go there"), root.k("B", "Bring it to you instead"), root.k("1…9", "Send it to that desktop"), root.k("F", "Float · tile"), root.k("Del", "Close"), root.k("Home", "Back to your own desktop"), root.k("Esc", "Done")]
        },
        {
            name: "THE DESKTOP TAB",
            sub: "SUPER + TAB → DESKTOP",
            keys: [root.k("drag from the tray", "Put a program on the desktop"), root.k("click a tray chip", "Same, dropped in the middle"), root.k("drag a tile", "Move it"), root.k("drag its corner", "Resize it"), root.k("double-click a tile", "Open it right now"), root.k("SNAP", "Grid on · off, while you drag"), root.k("← →", "Select"), root.k("Del", "Take it off the desktop")]
        },
        {
            name: "THE LAYOUT TAB",
            sub: "SUPER + TAB → LAYOUT",
            keys: [root.k("drag a chip", "Reorder · drag off the strip to remove"), root.k("click a chip", "Its own settings, beside it"), root.k("click a tray chip", "Add it to the end"), root.k("click an edge of the screen", "Move the bar there"), root.k("drag the bar's inner edge", "Thickness"), root.k("← →", "Select"), root.k("Shift + ← →", "Move it"), root.k("Del", "Remove")]
        },
        {
            name: "WALLPAPER CAROUSEL",
            sub: "SUPER + W",
            keys: [root.k("← →", "Step through"), root.k("wheel", "Step through"), root.k("click a side card", "Bring it to the middle"), root.k("Enter · click the middle", "Apply"), root.k("F", "Favourite"), root.k("Tab", "Favourites only"), root.k("R", "Random"), root.k("PgUp PgDn", "Jump ten"), root.k("S", "Save this look for this wallpaper"), root.k("Esc", "Close")]
        },
        {
            name: "WALLPAPERS",
            sub: "WALLPAPER → BROWSE",
            keys: [root.k("← →", "Browse"), root.k("PgUp PgDn", "Jump ten"), root.k("Home End", "First · last"), root.k("Enter", "Apply"), root.k("F", "Favourite"), root.k("Tab", "Favourites only"), root.k("R", "Random"), root.k("Esc", "Back")]
        },
        {
            name: "LAUNCHER",
            sub: "SUPER + SPACE",
            keys: [root.k("↑ ↓", "Move"), root.k("Ctrl + J / K", "Move"), root.k("Ctrl + N / P", "Move"), root.k("Tab", "Next result"), root.k("Enter", "Run"), root.k("> command", "Run a shell command"), root.k("2 + 2 * 8", "Calculate, Enter copies"), root.k("Esc", "Close")]
        },
        {
            name: "NOTIFICATIONS",
            sub: "SUPER + N",
            keys: [root.k("↑ ↓", "Move"), root.k("Enter", "Activate"), root.k("Del  or  Backspace", "Dismiss"), root.k("Shift + Del", "Clear all"), root.k("D", "Do not disturb"), root.k("Esc", "Close")]
        },
        {
            name: "POWER MENU",
            sub: "SUPER + ESCAPE",
            keys: [root.k("← →", "Move"), root.k("L S R P E", "Lock · Sleep · Restart · Power off · Exit"), root.k("Enter", "Confirm"), root.k("Esc", "Close")]
        },
        {
            name: "LOCK SCREEN",
            sub: "IF YOU TURNED IT ON",
            keys: [root.k("type", "Password"), root.k("Enter", "Unlock"), root.k("Esc", "Clear the field"), root.k("Ctrl+Alt+F2", "TTY, then loginctl unlock-session")]
        },
        {
            name: "THE BAR",
            sub: "POINTER ONLY",
            keys: [root.k("wheel · top third", "Workspace"), root.k("wheel · middle", "Volume"), root.k("wheel · bottom", "Brightness"), root.k("hover the status cluster", "Quick panel"), root.k("right-click the logo", "Launcher"), root.k("right-click power", "Lock"), root.k("right-click a module", "Its own setting")]
        }
    ]
}
