//  VELVET  ·  modules/wallpaper/WidgetActions.qml
//  What a click on a desktop widget does — one table for every look, so a
//  GLASS clock and a SHAPES clock answer the same way. `hint()` is the
//  same table in words: the label the wallpaper shows under a widget you
//  rest the pointer on. Right-click on any widget opens it in DESKTOP.
pragma Singleton

import qs.config
import qs.services
import Quickshell
import QtQuick

Singleton {
    id: root

    // "" = no primary action: the widget lights up but keeps an arrow.
    // `shaped`: the SHAPES look splits some widgets into parts (the media
    // art is the button, the clock and calendar peek); GLASS · INK · RAW
    // are one surface each.
    function hint(wid: string, shaped: bool): string {
        switch (wid) {
        case "notifs":
            return "OPEN NOTIFICATIONS";
        case "user":
        case "avatar":
            return "SESSION";
        case "greeting":
            return "LAUNCHER";
        case "resources":
            return "SYSTEM MONITOR";
        case "media":
            if (!(Lyrics.bridge?.has ?? false))
                return "";
            return shaped ? "TAP THE ART · WHEEL FOR VOLUME" : "PLAY · PAUSE · WHEEL FOR VOLUME";
        case "weather":
            return "REFRESH THE SKY";
        case "net":
            return "QUICK SETTINGS";
        case "clock":
            return shaped ? "PEEK THE DATE" : "";
        case "calendar":
            return shaped ? "PEEK THE WEEK" : "";
        default:
            return "";
        }
    }

    // The SHAPES containers — three tones from the accent's hue. One place,
    // so the DESKTOP inspector's colour swatches are the widget's colours.
    function bases(pastel: bool): var {
        const h = Colours.accent.hslHue;
        const h2 = Colours.accentAlt.hslHue;
        return [pastel ? Qt.hsla(h, 0.62, 0.80, 1) : Qt.hsla(h, 0.44, 0.27, 1), pastel ? Qt.hsla(h2, 0.45, 0.80, 1) : Qt.hsla(h2, 0.36, 0.25, 1), pastel ? Qt.hsla(h, 0.30, 0.91, 1) : Qt.hsla(h, 0.18, 0.15, 1)];
    }

    function clickable(wid: string, shaped: bool): bool {
        return root.hint(wid, shaped) !== "";
    }

    function volume(steps: int): void {
        for (let i = 0; i < Math.abs(steps); i++) {
            if (steps > 0)
                Audio.incrementVolume();
            else
                Audio.decrementVolume();
        }
    }

    // The shell-wide half of a click. Clock and calendar only peek, which
    // is their own business; everything else lands here.
    function run(wid: string): void {
        switch (wid) {
        case "notifs":
            Panels.toggleNotifCentre();
            break;
        case "user":
        case "avatar":
            Panels.toggleSession();
            break;
        case "greeting":
            Panels.toggleLauncher();
            break;
        case "resources":
            root.monitor();
            break;
        case "media":
            Lyrics.bridge?.toggle();
            break;
        case "weather":
            Weather.refresh();
            break;
        case "net":
            Panels.openSettingsZoneNamed("QUICK");
            break;
        default:
            break;
        }
        Sfx.select();
    }

    // btop if it is there, htop if not, plain top as the last resort.
    function monitor(): void {
        const id = !TermApps.isMissing("btop") ? "btop" : (!TermApps.isMissing("htop") ? "htop" : "");
        const cmd = id !== "" ? (TermApps.resolvedRun(id) || id) : "top";
        const line = Term.wrap("dev.velvet.monitor", id || "top", cmd, "");
        if (line !== "")
            Actions.run(line);
    }

    function edit(): void {
        Sfx.open();
        Panels.openSettingsTabNamed("DESKTOP");
    }
}
