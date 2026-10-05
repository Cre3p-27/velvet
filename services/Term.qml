//  VELVET  ·  services/Term.qml
//  Which terminal you have, and how to ask it to run one program in a window
//  with a name we can find again.
//
//  Every emulator spells "set the app-id" differently, and getting it wrong is
//  not a crash — it is a window the scene can never match, float or place. So
//  the spelling lives here, once, and everything else asks.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property string detected: ""
    property bool probed: false

    readonly property string chosen: {
        const forced = Config.scene.terminal;
        if (forced && forced !== "auto")
            return forced;
        return root.detected;
    }

    readonly property bool ready: root.chosen !== ""

    readonly property var known: ["kitty", "foot", "ghostty", "wezterm", "alacritty", "konsole", "xfce4-terminal", "xterm"]

    readonly property string status: {
        if (!root.probed)
            return "LOOKING…";
        if (!root.chosen)
            return `NO TERMINAL FOUND  ·  INSTALL ONE OF ${root.known.slice(0, 4).join(", ").toUpperCase()}`;
        const forced = Config.scene.terminal && Config.scene.terminal !== "auto";
        const how = forced ? "CHOSEN BY HAND" : "FOUND AUTOMATICALLY";
        const named = root.canName() ? "" : "  ·  CANNOT NAME ITS WINDOW CLASS, MATCHED BY TITLE";
        return `${root.chosen.toUpperCase()}  ·  ${how}${named}`;
    }

    Process {
        running: true
        command: ["bash", "-c", "for t in kitty foot ghostty wezterm alacritty konsole xfce4-terminal xterm; do command -v \"$t\" >/dev/null 2>&1 && { printf '%s' \"$t\"; exit 0; }; done"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.detected = text.trim();
                root.probed = true;
            }
        }
    }

    // The command line that runs `cmd` in a terminal window called `cls` with
    // the title `title`. BOTH, always: three of these emulators cannot be told
    // what class to use, and a window the scene cannot recognise is a window
    // it opens a second copy of on every login. `opts` are emulator-specific
    // extras — right now only kitty's background opacity — appended where the
    // emulator takes them; anything that does not support them ignores them.
    function wrap(cls: string, title: string, cmd: string, opts: string): string {
        if (!cmd)
            return "";
        const t = root.chosen;
        // No terminal at all. Returning the bare command would run a program
        // that needs a tty with no tty — nothing appears and nothing says why.
        if (!t)
            return "";
        const c = cls || "dev.velvet.app";
        const n = title || c;
        const q = root.quote(cmd);
        const o = opts || "";
        switch (t) {
        case "kitty":
            return `kitty --class ${c} --title ${n} ${o} -e ${q}`;
        case "foot":
            return `foot --app-id=${c} --title=${n} -e ${q}`;
        case "ghostty":
            return `ghostty --class=${c} --title=${n} -e ${q}`;
        case "wezterm":
            return `wezterm start --class ${c} -- ${q}`;
        case "alacritty":
            return `alacritty --class ${c} --title ${n} -e ${q}`;
        case "konsole":
            return `konsole -p tabtitle=${n} --hide-menubar -e ${q}`;
        case "xfce4-terminal":
            return `xfce4-terminal --title=${n} --disable-server -x ${q}`;
        default:
            return `${t} -title ${n} -e ${q}`;
        }
    }

    // An install path with a space in it would otherwise split into two
    // arguments and nothing would start.
    function quote(cmd: string): string {
        const text = String(cmd ?? "");
        if (!text || text.indexOf(" ") === -1)
            return text;
        // Already a multi-word command line, not a bare path: leave it alone.
        if (text.indexOf("/") === -1 || text.indexOf(" -") !== -1)
            return text;
        return '"' + text.split('"').join('\\"') + '"';
    }

    // Whether this emulator can be told what class to give its window. The
    // ones that cannot still run the program and still get a title, which is
    // what the scene matches them on.
    function canName(): bool {
        const t = root.chosen;
        return t === "kitty" || t === "foot" || t === "ghostty" || t === "wezterm" || t === "alacritty";
    }
}
