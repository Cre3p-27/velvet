-- ─────────────────────────────────────────────────────────────────────────────
--  VELVET · volume, brightness and media keys (Lua config)
--
--  Pulled in by install.sh with   require("velvet-media")   — only when your
--  own config does not bind these keys yet (binding them twice makes every
--  press count double). Velvet's OSD shows whatever changes the volume.
-- ─────────────────────────────────────────────────────────────────────────────

local function key(name, cmd, repeating)
    hl.bind(name, hl.dsp.exec_cmd(cmd), { locked = true, repeating = repeating or false })
end

key("XF86AudioRaiseVolume", "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+", true)
key("XF86AudioLowerVolume", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", true)
key("XF86AudioMute", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
key("XF86AudioMicMute", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")
key("XF86MonBrightnessUp", "brightnessctl -q s 5%+", true)
key("XF86MonBrightnessDown", "brightnessctl -q s 5%-", true)
key("XF86AudioPlay", "playerctl play-pause")
key("XF86AudioPause", "playerctl play-pause")
key("XF86AudioNext", "playerctl next")
key("XF86AudioPrev", "playerctl previous")
