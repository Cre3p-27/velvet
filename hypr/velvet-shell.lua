-- ─────────────────────────────────────────────────────────────────────────────
--  VELVET · Hyprland integration for a Lua config
--
--  Add ONE line at the very END of your hyprland.lua:
--
--      require("velvet-shell")
--
--  (install.sh does that for you.)
--
--  This file holds what Velvet needs but does not manage: the keybinds and
--  autostart. The values you change inside Super+Tab — gaps, blur, rounding,
--  shadows — are written to a separate velvet.lua, which is required at the
--  bottom of this file so it always wins.
--
--  Layer rules (blur behind the bar) are NOT here: the shell registers them
--  itself over hyprctl at startup, so there is nothing to keep in sync.
-- ─────────────────────────────────────────────────────────────────────────────

local mainMod = "SUPER"
-- where the shell lives (install.sh links it here), for every user
VELVET_DIR = (os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")) .. "/quickshell/velvet"

-- Talking to the shell over its IPC socket. This works regardless of whether
-- Hyprland's global-shortcut protocol is available, which the `global`
-- dispatcher would depend on.
local function velvet(panel)
    return hl.dsp.exec_cmd("qs -c velvet ipc call panels " .. panel)
end

-- ══ AUTOSTART ═══════════════════════════════════════════════════════════════
-- velvet-session starts the shell and looks after it: a crash brings it back,
-- and with LOCK AT BOOT the session is never left open if the lock cannot come
-- up (hyprlock stands in, or the session ends and the login screen asks).
--
-- NOTE: if you already have an hl.on("hyprland.start", ...) block of your own,
-- check after the first reboot that your other autostart apps still come up.
-- Event handlers should stack, but if yours stopped firing, delete this block
-- and put the one line inside your own handler instead:
--
--     hl.exec_cmd(VELVET_DIR .. "/bin/velvet-session")
--
hl.on("hyprland.start", function()
    local cmd = VELVET_DIR .. "/bin/velvet-session"
    -- Two spellings, tried in order. Which one exists depends on your
    -- Hyprland version, and calling the wrong one raises "attempt to call a
    -- nil value" at event time — a failure whose only symptom is that the
    -- shell never starts and nothing says why.
    if pcall(function() hl.exec_cmd(cmd) end) then
        return
    end
    pcall(function() hl.dsp.exec_cmd(cmd) end)
end)

-- ══ KEYBINDS ════════════════════════════════════════════════════════════════
hl.bind(mainMod .. " + Tab", velvet("settings"))         -- the Persona menu
hl.bind(mainMod .. " + space", velvet("launcher"))       -- app launcher
hl.bind(mainMod .. " + N", velvet("notifications"))      -- notification centre
hl.bind(mainMod .. " + Escape", velvet("session"))       -- power menu
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("qs -c velvet ipc call lock lock"))  -- lock the session
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(VELVET_DIR .. "/hypr/scripts/velvet-record.sh"))  -- record · stop recording
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd("qs -c velvet ipc call focus toggle"))  -- focus mode
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("qs -c velvet ipc call wheel toggle"))  -- wallpaper wheel
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("qs -c velvet ipc call map toggle"))  -- the mini desktop
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("qs -c velvet ipc call scene start"))  -- open the desktop you arranged
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.exec_cmd("qs -c velvet ipc call lyrics toggle"))  -- lyrics
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.exec_cmd("qs -c velvet ipc call keys toggle"))  -- every shortcut

-- ══ MEDIA KEYS ══════════════════════════════════════════════════════════════
-- In velvet-media.lua, which install.sh pulls in only when your config does
-- not bind these keys yet — binding them twice makes every press count double.

-- ══ MANAGED DESIGN ══════════════════════════════════════════════════════════
-- Written by the shell whenever you move a slider in Super+Tab → WINDOWS.
-- pcall so a missing file on the very first run cannot take your whole
-- config down with it.
pcall(require, "velvet")
