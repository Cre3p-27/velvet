-- ─────────────────────────────────────────────────────────────────────────────
--  VELVET · the infinite desktop, the zoom and the window tools (Lua config)
--
--  Pulled in by install.sh with   require("velvet-desktop")   — only when your
--  own config does not already bind these keys. Everything runs from the shell's
--  own folder, so it works for every user and every install location.
--
--    Super + Z / X               previous / next desktop
--    Super + Shift + Z / X       take the window along
--    Super + D                   floating windows ⇄ tiled
--    Super + Shift + arrows      move the window on the canvas
--    Super + Ctrl + arrows       jump to the next window in that direction
--    Super + Alt + arrows        swap places with the window in that direction
--    Super + Alt + H J K L       move a tiled window through the layout
--    Super + Alt + mouse wheel   zoom the desktop out and back
--    Super + Alt + left click    zoom back to 1:1 (middle click too)
--    Super + Alt + right click   zoom out until every window shows
--    zoomed out, the mouse works as at 1:1: click, type, Super+drag, resize
--    Super + left-drag on empty  pan the canvas (the infinite desktop)
-- ─────────────────────────────────────────────────────────────────────────────

local mainMod = "SUPER"
local home = os.getenv("HOME") or ""
local V = (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")) .. "/quickshell/velvet"
local function py(script, args)
    return hl.dsp.exec_cmd("python3 " .. V .. "/scripts/" .. script .. (args and (" " .. args) or ""))
end

-- the canvas engine (needs python-evdev and your user in the `input` group)
hl.on("hyprland.start", function()
    local cmd = "python3 " .. V .. "/scripts/infinite_desktop_core.py 1.6 > /tmp/velvet-infinite-desktop.log 2>&1"
    if pcall(function() hl.exec_cmd(cmd) end) then
        return
    end
    pcall(function() hl.dsp.exec_cmd(cmd) end)
end)

-- desktops
hl.bind(mainMod .. " + Z", hl.dsp.focus({ workspace = "-1" }))
hl.bind(mainMod .. " + X", hl.dsp.focus({ workspace = "+1" }))
hl.bind(mainMod .. " + SHIFT + Z", hl.dsp.window.move({ workspace = "-1" }))
hl.bind(mainMod .. " + SHIFT + X", hl.dsp.window.move({ workspace = "+1" }))

-- floating ⇄ tiled
hl.bind(mainMod .. " + D", py("floating_tile_toggle.py"))

-- moving, jumping, swapping
for _, d in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mainMod .. " + SHIFT + " .. d, py("move_window.py", d), { repeating = true })
    hl.bind(mainMod .. " + CTRL + " .. d, py("navigate_windows.py", d))
    -- Hyprland's own swap: the window trades places with its neighbour
    hl.bind(mainMod .. " + ALT + " .. d, hl.dsp.window.swap({ direction = d }))
end
-- the same as a script (floating windows hop a step, tiled ones move in the layout)
hl.bind(mainMod .. " + ALT + H", py("move_window_tiled.py", "left"))
hl.bind(mainMod .. " + ALT + L", py("move_window_tiled.py", "right"))
hl.bind(mainMod .. " + ALT + K", py("move_window_tiled.py", "up"))
hl.bind(mainMod .. " + ALT + J", py("move_window_tiled.py", "down"))

-- the zoom (the velvetzoom plugin takes the wheel itself once it is loaded;
-- these binds are its fallback)
hl.bind(mainMod .. " + ALT + mouse_up", py("desktop_zoom.py", "in"))
hl.bind(mainMod .. " + ALT + mouse_down", py("desktop_zoom.py", "out"))
hl.bind(mainMod .. " + ALT + mouse:274", py("desktop_zoom.py", "reset"))
hl.bind(mainMod .. " + ALT + mouse:272", py("desktop_zoom.py", "reset"))
hl.bind(mainMod .. " + ALT + mouse:273", py("desktop_zoom.py", "fit"))
