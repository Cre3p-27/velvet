//  VELVET  ·  components/AppIcon.qml
//  A window's app icon from its class, never the magenta checkerboard: the
//  icon theme first (through the desktop entry's own icon name), then the
//  hicolor files themselves — the theme lookup misses icons that are right
//  there (spotify, claude-desktop, Steam's game icons) — and when nothing
//  answers, the app's first letter on a tinted disc.
import qs.config
import qs.services
import QtQuick
import Quickshell

Item {
    id: root

    property string cls: ""
    // shared between icons: class → what was found ("" = nothing, letter)
    property var cache: Desk.iconCache

    readonly property var names: {
        const c = `${root.cls ?? ""}`;
        if (c === "")
            return [];
        const out = [];
        const add = n => {
            if (n && out.indexOf(n) < 0)
                out.push(n);
        };
        let entry = null;
        try {
            entry = DesktopEntries.heuristicLookup(c);
        } catch (e) {}
        add(entry?.icon ?? "");
        const steam = /^steam_app_(\d+)$/.exec(c);
        if (steam) {
            add(`steam_icon_${steam[1]}`);
            add("steam");
        }
        // a class that is only an architecture (some native games report
        // "x86_64") names no app at all: nothing to look up, the letter it is
        const arch = /^(x86_64|x86|x64|amd64|i386|arm64|aarch64|exe|bin|appimage)$/;
        if (arch.test(c.toLowerCase()))
            return out;
        add(c);
        add(c.toLowerCase());
        // reverse-DNS names end in the app (org.gnome.Nautilus); a game's
        // binary ends in its architecture (UltimateChickenHorse.x86_64) —
        // there the name is in front
        const parts = c.split(".");
        const last = parts[parts.length - 1].toLowerCase();
        add(arch.test(last) && parts.length > 1 ? parts[0].toLowerCase() : last);
        if (/claude/i.test(c))
            add("claude-desktop");
        return out;
    }

    // every place to try, in order: the theme for every name (no misses
    // logged), then the hicolor files for the lower-case names only — each
    // miss there is one warning, once per class and session (Desk.iconCache)
    readonly property var candidates: {
        const out = [];
        for (let i = 0; i < root.names.length; i++) {
            const n = root.names[i];
            if (n.startsWith("/"))
                out.push(`file://${n}`);
            else {
                const themed = Quickshell.iconPath(n, true);
                if (themed)
                    out.push(themed);
            }
        }
        for (let i = 0; i < root.names.length; i++) {
            const n = root.names[i];
            if (n.startsWith("/") || n !== n.toLowerCase() || n.indexOf(".") >= 0)
                continue;
            out.push(`file:///usr/share/icons/hicolor/48x48/apps/${n}.png`);
            out.push(`file:///usr/share/icons/hicolor/scalable/apps/${n}.svg`);
            out.push(`file:///usr/share/icons/hicolor/128x128/apps/${n}.png`);
            out.push(`file:///usr/share/pixmaps/${n}.png`);
        }
        return out;
    }

    property int tryAt: 0
    readonly property string known: root.cache && root.cls in root.cache ? root.cache[root.cls] : "?"
    readonly property string source: root.known !== "?" ? root.known : (root.tryAt < root.candidates.length ? root.candidates[root.tryAt] : "")
    readonly property bool lettered: root.source === "" || pic.status === Image.Error

    onClsChanged: root.tryAt = 0

    Image {
        id: pic

        anchors.fill: parent
        source: root.source
        sourceSize.width: Math.max(16, Math.ceil(root.width * 2))
        sourceSize.height: Math.max(16, Math.ceil(root.height * 2))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        visible: !root.lettered && status === Image.Ready

        onStatusChanged: {
            if (status === Image.Ready && root.cache && root.known === "?")
                root.cache[root.cls] = root.source;
            else if (status === Image.Error && root.known === "?") {
                if (root.tryAt + 1 < root.candidates.length)
                    root.tryAt = root.tryAt + 1;
                else if (root.cache)
                    root.cache[root.cls] = "";
            }
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        radius: width / 2
        visible: root.lettered && root.cls !== ""
        color: Colours.alpha(Colours.accent, 0.3)
        border.width: 1
        border.color: Colours.alpha(Colours.accent, 0.6)

        Text {
            anchors.centerIn: parent
            text: `${root.cls ?? ""}`.replace(/^(com|org|io|net|app)\./i, "").replace(/^steam_app_\d+$/, "S").charAt(0).toUpperCase()
            color: Colours.ink
            font.family: Appearance.fontFamily.display
            font.pixelSize: Math.max(7, parent.height * 0.55)
            font.weight: Font.DemiBold
        }
    }
}
