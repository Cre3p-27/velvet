//  VELVET  ·  services/HyprConf.qml
//  Two-way Hyprland control. Every change is applied live through
//  `hyprctl --batch` (instant, visible while you drag) and written to a file
//  that survives reboot — velvet.lua if your config is Lua, velvet.conf if it
//  is hyprlang. Source or require that file last and the menu always wins.
pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // XDG_CONFIG_HOME, not a hardcoded ~/.config: the dialect probe already
    // honours it, and a shell that reads its config from one directory and
    // writes its managed half into another is a very quiet kind of broken.
    readonly property string hyprDir: `${Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")}/hypr`
    property bool ready: false

    // Which config language to write. "auto" follows whichever file you have.
    property string detected: "conf"
    readonly property bool lua: {
        const f = Config.hypr.format;
        if (f === "lua")
            return true;
        if (f === "conf")
            return false;
        return root.detected === "lua";
    }

    function hex(c: color): string {
        const to = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return `rgba(${to(c.r)}${to(c.g)}${to(c.b)}${to(c.a)})`;
    }

    readonly property string activeBorder: `${hex(Colours.accent)} ${hex(Colours.accentHot)} 45deg`
    readonly property string inactiveBorder: hex(Colours.alpha(Colours.outline, 0.45))

    // ------------------------------------------------- live apply (both worlds)
    // hyprctl speaks to the running compositor, not to a config file, so this
    // path is identical whether your config is Lua or hyprlang. Hyprland 0.55+
    // dropped the classic `keyword` request (it answers "unknown request" to
    // everything), so the live apply now speaks hl.config through
    // `hyprctl eval` — real Lua types, no keyword strings. The old batch
    // remains as the fallback for builds without eval.
    readonly property var keywords: {
        const h = Config.hypr;
        const b = v => v ? "1" : "0";
        const out = [
            ["general:gaps_in", `${h.gapsIn}`],
            ["general:gaps_out", `${h.gapsOut}`],
            ["general:border_size", `${h.borderSize}`],
            ["general:resize_on_border", b(h.resizeOnBorder)],
            ["general:layout", h.layout],
            ["decoration:rounding", `${h.rounding}`],
            ["decoration:rounding_power", h.roundingPower.toFixed(2)],
            ["decoration:active_opacity", h.activeOpacity.toFixed(2)],
            ["decoration:inactive_opacity", h.inactiveOpacity.toFixed(2)],
            // Live only: while focus mode borrows the dim, a slider change
            // elsewhere must not hand it back. The saved file never sees this.
            ["decoration:dim_inactive", b(h.dimInactive || Focus.dims)],
            ["decoration:dim_strength", (Focus.dims ? Config.services.focusDimStrength : h.dimStrength).toFixed(2)],
            ["decoration:blur:enabled", b(h.blur)],
            ["decoration:blur:size", `${h.blurSize}`],
            ["decoration:blur:passes", `${h.blurPasses}`],
            ["decoration:blur:noise", h.blurNoise.toFixed(3)],
            ["decoration:blur:xray", b(h.blurXray)],
            ["decoration:shadow:enabled", b(h.shadow)],
            ["decoration:shadow:range", `${h.shadowRange}`],
            ["decoration:shadow:render_power", `${Math.round(h.shadowRenderPower)}`],
            ["animations:enabled", b(h.animations)],
            ["misc:vrr", b(h.vrr)],
            // a lock that dies can be replaced by the next one (velvet-session
            // restarts the shell, the shell locks again) — never a dead end
            ["misc:allow_session_lock_restore", "1"],
            ["input:follow_mouse", h.followMouse ? "1" : "0"]
        ];
        if (h.manageBorders) {
            out.push(["general:col.active_border", root.activeBorder]);
            out.push(["general:col.inactive_border", root.inactiveBorder]);
        }
        return out;
    }

    readonly property string batchCommand: keywords.map(k => `keyword ${k[0]} ${k[1]}`).join(" ; ")

    // ------------------------------------------- temporary overrides (focus)
    // Focus mode borrows Hyprland's dim settings for as long as it is on.
    // Putting them back is just re-applying what the config says, so focus
    // never rewrites anything — the same promise the quick panel's switches
    // make. Both calls use the same eval-first fallback as everything else.
    function overrideDim(on: bool, strength: real): void {
        if (!root.ready || !Config.hypr.manage)
            return;
        const lua = `hl.config({ decoration = { dim_inactive = ${on ? "true" : "false"}, dim_strength = ${strength.toFixed(2)} } })`;
        const batch = `keyword decoration:dim_inactive ${on ? "1" : "0"} ; keyword decoration:dim_strength ${strength.toFixed(2)}`;
        focusApply.command = ["bash", "-c", `out=$(hyprctl eval '${lua}' 2>&1); if [ "$out" != "ok" ]; then hyprctl --batch "${batch}"; fi`];
        focusApply.running = false;
        focusApply.running = true;
    }

    // Put everything back to the configured values (focus letting go).
    function reapply(): void {
        if (root.ready && Config.hypr.manage)
            liveDebounce.restart();
    }

    readonly property string luaApply: {
        const h = Config.hypr;
        const b = v => v ? "true" : "false";
        let out = "hl.config({\n" +
            "general = { gaps_in = " + h.gapsIn + ", gaps_out = " + h.gapsOut + ", border_size = " + h.borderSize + ", resize_on_border = " + b(h.resizeOnBorder) + ", layout = \"" + h.layout + "\"";
        if (h.manageBorders) {
            const c = root.activeBorder.split(" ");
            out += ", col = { active_border = { colors = { \"" + c[0] + "\", \"" + c[1] + "\" }, angle = 45 }, inactive_border = \"" + root.inactiveBorder + "\" }";
        }
        out += " },\n" +
            "decoration = {\n" +
            "rounding = " + h.rounding + ", rounding_power = " + h.roundingPower.toFixed(2) + ",\n" +
            "active_opacity = " + h.activeOpacity.toFixed(2) + ", inactive_opacity = " + h.inactiveOpacity.toFixed(2) + ",\n" +
            "dim_inactive = " + b(h.dimInactive || Focus.dims) + ", dim_strength = " + (Focus.dims ? Config.services.focusDimStrength : h.dimStrength).toFixed(2) + ",\n" +
            "blur = { enabled = " + b(h.blur) + ", size = " + h.blurSize + ", passes = " + h.blurPasses + ", noise = " + h.blurNoise.toFixed(3) + ", xray = " + b(h.blurXray) + " },\n" +
            "shadow = { enabled = " + b(h.shadow) + ", range = " + h.shadowRange + ", render_power = " + Math.round(h.shadowRenderPower) + " },\n" +
            "},\n" +
            "animations = { enabled = " + b(h.animations) + " },\n" +
            "misc = { vrr = " + b(h.vrr) + ", allow_session_lock_restore = true },\n" +
            "input = { follow_mouse = " + b(h.followMouse) + " },\n" +
            "})";
        return out;
    }

    // ----------------------------------------------------------- layer rules
    // Applied through hyprctl rather than written into your config, so blur
    // behind the bar works the same on a Lua config as on a hyprlang one and
    // nothing has to be edited by hand. Same eval-first fallback-batch order.
    // TASKBAR → BLUR decides whether the bar is frosted; the other layers
    // always are. (The switch used to be read by nothing at all.)
    readonly property var blurred: (Config.bar.blur ? ["velvet-bar"] : []).concat(["velvet-popout", "velvet-notifs", "velvet-osd", "velvet-notifcentre", "velvet-island"])

    readonly property var layerRules: {
        const blurred = root.blurred;
        const out = [];
        for (let i = 0; i < blurred.length; i++) {
            out.push(`keyword layerrule blur,${blurred[i]}`);
            out.push(`keyword layerrule ignorealpha 0.1,${blurred[i]}`);
        }
        if (!Config.bar.blur)
            out.push("keyword layerrule ignorealpha 0.1,velvet-bar");
        out.push("keyword layerrule animation slide,velvet-bar");
        out.push("keyword layerrule animation popin 90%,velvet-popout");
        out.push("keyword layerrule animation slide,velvet-notifs");
        out.push("keyword layerrule animation fade,velvet-settings");
        out.push("keyword layerrule animation fade,velvet-launcher");
        out.push("keyword layerrule animation fade,velvet-session");
        return out;
    }

    readonly property string luaLayerRules: {
        const blurred = root.blurred;
        let out = "hl.config({ layerrule = {";
        for (let i = 0; i < blurred.length; i++) {
            out += ` { rule = "blur,${blurred[i]}" }, { rule = "ignorealpha 0.1,${blurred[i]}" },`;
        }
        if (!Config.bar.blur)
            out += ` { rule = "ignorealpha 0.1,velvet-bar" },`;
        out += ` { rule = "animation slide,velvet-bar" }, { rule = "animation popin 90%,velvet-popout" }, { rule = "animation slide,velvet-notifs" }, { rule = "animation fade,velvet-settings" }, { rule = "animation fade,velvet-launcher" }, { rule = "animation fade,velvet-session" } } })`;
        return out;
    }

    // ------------------------------------------------------------ hyprlang out
    readonly property string confContents: `# ─────────────────────────────────────────────────────────────
#  velvet.conf — generated by the VELVET shell. Do not hand-edit:
#  it is rewritten whenever you change something in Super+Tab.
#  Source it LAST from hyprland.conf so it wins:
#      source = ~/.config/hypr/velvet.conf
# ─────────────────────────────────────────────────────────────

general {
    gaps_in = ${Config.hypr.gapsIn}
    gaps_out = ${Config.hypr.gapsOut}
    border_size = ${Config.hypr.borderSize}
    resize_on_border = ${Config.hypr.resizeOnBorder ? "true" : "false"}
    layout = ${Config.hypr.layout}
${Config.hypr.manageBorders ? `    col.active_border = ${root.activeBorder}
    col.inactive_border = ${root.inactiveBorder}` : "    # border colours left to your own config"}
}

decoration {
    rounding = ${Config.hypr.rounding}
    rounding_power = ${Config.hypr.roundingPower.toFixed(2)}
    active_opacity = ${Config.hypr.activeOpacity.toFixed(2)}
    inactive_opacity = ${Config.hypr.inactiveOpacity.toFixed(2)}
    dim_inactive = ${Config.hypr.dimInactive ? "true" : "false"}
    dim_strength = ${Config.hypr.dimStrength.toFixed(2)}

    blur {
        enabled = ${Config.hypr.blur ? "true" : "false"}
        size = ${Config.hypr.blurSize}
        passes = ${Config.hypr.blurPasses}
        noise = ${Config.hypr.blurNoise.toFixed(3)}
        xray = ${Config.hypr.blurXray ? "true" : "false"}
    }

    shadow {
        enabled = ${Config.hypr.shadow ? "true" : "false"}
        range = ${Config.hypr.shadowRange}
        render_power = ${Math.round(Config.hypr.shadowRenderPower)}
    }
}

animations {
    enabled = ${Config.hypr.animations ? "true" : "false"}
}

misc {
    vrr = ${Config.hypr.vrr ? "1" : "0"}
    allow_session_lock_restore = 1
}

input {
    follow_mouse = ${Config.hypr.followMouse ? "1" : "0"}
}

# Key menu changes land here, applied last:
${Binds.confBinds}
`

    // ----------------------------------------------------------------- lua out
    readonly property string luaContents: `-- ─────────────────────────────────────────────────────────────
--  velvet.lua — generated by the VELVET shell. Do not hand-edit:
--  it is rewritten whenever you change something in Super+Tab.
--  Require it LAST from hyprland.lua so it wins:
--      require("velvet")
-- ─────────────────────────────────────────────────────────────

hl.config({
    general = {
        gaps_in = ${Config.hypr.gapsIn},
        gaps_out = ${Config.hypr.gapsOut},
        border_size = ${Config.hypr.borderSize},
        resize_on_border = ${Config.hypr.resizeOnBorder ? "true" : "false"},
        layout = "${Config.hypr.layout}",${Config.hypr.manageBorders ? `
        col = {
            active_border = { colors = { "${hex(Colours.accent)}", "${hex(Colours.accentHot)}" }, angle = 45 },
            inactive_border = "${root.inactiveBorder}",
        },` : ""}
    },
    decoration = {
        rounding = ${Config.hypr.rounding},
        rounding_power = ${Config.hypr.roundingPower.toFixed(2)},
        active_opacity = ${Config.hypr.activeOpacity.toFixed(2)},
        inactive_opacity = ${Config.hypr.inactiveOpacity.toFixed(2)},
        dim_inactive = ${Config.hypr.dimInactive ? "true" : "false"},
        dim_strength = ${Config.hypr.dimStrength.toFixed(2)},
        blur = {
            enabled = ${Config.hypr.blur ? "true" : "false"},
            size = ${Config.hypr.blurSize},
            passes = ${Config.hypr.blurPasses},
            noise = ${Config.hypr.blurNoise.toFixed(3)},
            xray = ${Config.hypr.blurXray ? "true" : "false"},
        },
        shadow = {
            enabled = ${Config.hypr.shadow ? "true" : "false"},
            range = ${Config.hypr.shadowRange},
            render_power = ${Math.round(Config.hypr.shadowRenderPower)},
        },
    },
    animations = {
        enabled = ${Config.hypr.animations ? "true" : "false"},
    },
    misc = {
        vrr = ${Config.hypr.vrr ? "1" : "0"},
        allow_session_lock_restore = true,
    },
    input = {
        follow_mouse = ${Config.hypr.followMouse ? "1" : "0"},
    },
})

-- Key menu changes land here, applied last:
${Binds.luaBinds}
`

    readonly property string fileContents: root.lua ? root.luaContents : root.confContents
    readonly property string filePath: `${root.hyprDir}/${root.lua ? "velvet.lua" : "velvet.conf"}`

    // ------------------------------------------------------------ application
    onBatchCommandChanged: {
        if (root.ready && Config.hypr.manage)
            liveDebounce.restart();
    }

    onFileContentsChanged: {
        if (root.ready && Config.hypr.manage)
            saveDebounce.restart();
    }

    // Live apply is near-instant so dragging a slider feels direct…
    Timer {
        id: liveDebounce
        interval: 16
        onTriggered: {
            apply.command = ["bash", "-c", `out=$(hyprctl eval '${root.luaApply}' 2>&1); if [ "$out" != "ok" ]; then hyprctl --batch "${root.batchCommand}"; fi`];
            apply.running = false;
            apply.running = true;
        }
    }

    // …while the disk write waits until you stop moving.
    Timer {
        id: saveDebounce
        interval: 700
        onTriggered: confFile.setText(root.fileContents)
    }

    Process {
        id: apply
        command: ["true"]
    }

    Process {
        id: focusApply
        command: ["true"]
    }

    Process {
        id: rules
        command: ["true"]
    }

    FileView {
        id: confFile
        path: root.filePath
        printErrors: false
    }

    // ------------------------------------------------------------- detection
    Process {
        running: true
        command: ["bash", "-c", 'test -f "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua" && echo lua || echo conf']

        stdout: StdioCollector {
            onStreamFinished: root.detected = text.trim()
        }
    }

    // The layer rules, sent to Hyprland. `clearBar` first drops the bar's
    // old rules (turning BLUR off has to take the frost away again), then
    // everything is registered afresh.
    function pushLayerRules(clearBar: bool): void {
        const clear = clearBar ? `hyprctl eval 'hl.config({ layerrule = { { rule = "unset,velvet-bar" } } })' >/dev/null 2>&1 || hyprctl keyword layerrule "unset,velvet-bar" >/dev/null 2>&1; ` : "";
        // the settings window floats and opens centred (it is a real window since v8.40)
        const win = `hyprctl eval 'hl.window_rule({ name = "velvet-settings", match = { title = "^Velvet Settings$" }, float = true, center = true })' >/dev/null 2>&1; hyprctl eval 'hl.window_rule({ name = "velvet-welcome", match = { title = "^Welcome to Velvet$" }, float = true, center = true })' >/dev/null 2>&1; `;
        rules.command = ["bash", "-c", `${clear}${win}out=$(hyprctl eval '${root.luaLayerRules}' 2>&1); if [ "$out" != "ok" ]; then hyprctl --batch "${root.layerRules.join(" ; ")}"; fi`];
        rules.running = false;
        rules.running = true;
    }

    Connections {
        target: Config.bar

        function onBlurChanged(): void {
            if (root.ready)
                root.pushLayerRules(true);
        }
    }

    // Push everything once at startup so a fresh boot matches the config, and
    // register the layer rules that give the bar its blur.
    Timer {
        running: true
        interval: 1400
        onTriggered: {
            root.ready = true;

            root.pushLayerRules(false);

            if (Config.hypr.manage) {
                liveDebounce.restart();
                saveDebounce.restart();
            }
        }
    }
}
