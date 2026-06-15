-- Minimal Hyprland config (Lua). Hand-written and deployed verbatim via
-- home-manager (see default.nix: xdg.configFile."hypr/hyprland.lua".source).
-- Launched by start-hyprland, which reads the Lua config format.
--
-- Deliberately bare — a starting point to grow yourself. Add a bar, notifs,
-- theming, more keybinds as you explore.
--   Reference: https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua
--   Wiki:      https://wiki.hypr.land/

local mainMod  = "SUPER"
local terminal = "kitty"
local menu     = "wofi --show drun"

-- Monitors: auto-detect whatever is attached (incl. the USB4 dock).
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})

-- Core
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + R",      hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + Q",      hl.dsp.window.close())
hl.bind(mainMod .. " + V",      hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F",      hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + M",      hl.dsp.exec_cmd("hyprctl dispatch exit"))

-- Move focus
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces 1-5: switch (mainMod + N) and move active window (mainMod + SHIFT + N)
for i = 1, 5 do
    local key = tostring(i)
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Mouse: move (left) / resize (right) windows while holding mainMod
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
