-- Minimal Hyprland config (Lua). Hand-written and deployed verbatim via
-- home-manager (see default.nix: xdg.configFile."hypr/hyprland.lua".source).
-- Launched by start-hyprland, which reads the Lua config format.
--
-- Deliberately bare — a starting point to grow yourself. Add a bar, notifs,
-- theming, more keybinds as you explore.
--   Reference: https://github.com/hyprwm/Hyprland/blob/main/example/hyprland.lua
--   Wiki:      https://wiki.hypr.land/

---------------------
---- Programs    ----
---------------------

local mainMod = "SUPER"
local terminal = "kitty"
local menu = "pkill wofi || wofi --show drun"

---------------------
---- Monitors    ----
---------------------

-- Monitors: auto-detect whatever is attached (incl. the USB4 dock).
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = "auto",
})

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
	general = {
		--		gaps_in = 5,
		gaps_out = 5,
		border_size = 2,
		col = {
			active_border = { colors = { "rgba(98971Aff)", "rgba(d65d0eff)" }, angle = 45 },
			inactive_border = "rgba(595959aa)",
		},
	},

	decoration = {
		rounding = 10,
		rounding_power = 2,

		-- Change transparency of focused and unfocused windows
		active_opacity = 1.0,
		inactive_opacity = 1.0,
	},

	-- Animations: default speeds halved (50% faster).
	-- speed is duration in deciseconds at 60 fps — lower = faster.
	animations = {
		enabled = true,
		bezier = {
			{ name = "easeOut", x1 = 0.16, y1 = 1.0, x2 = 0.3, y2 = 1.0 },
		},
		animation = {
			{ name = "windows",    enabled = true, speed = 4, bezier = "easeOut" },
			{ name = "windowsOut", enabled = true, speed = 4, bezier = "easeOut", style = "popin 80%" },
			{ name = "border",     enabled = true, speed = 5, bezier = "easeOut" },
			{ name = "fade",       enabled = true, speed = 4, bezier = "easeOut" },
			{ name = "workspaces", enabled = true, speed = 4, bezier = "easeOut" },
		},
	},
})

hl.config({
    scrolling = {
        fullscreen_on_one_column = true,
    },
})

---------------------
---- Autostart   ----
---------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("swaybg -i /home/loeffner/Images/earth.png -m fill")
    hl.exec_cmd("waybar")
    hl.exec_cmd("hyprpolkitagent")
end)

---------------------
---- Keybinds    ----
---------------------

-- Core
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + E",      hl.dsp.exec_cmd("kitty -e yazi"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + Backspace", hl.dsp.window.close())
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + M", hl.dsp.exit())

-- Move focus
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))

-- Workspaces 1-5: switch (mainMod + N) and move active window (mainMod + SHIFT + N)
for i = 1, 5 do
	local key = tostring(i)
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Mouse: move (left) / resize (right) windows while holding mainMod
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
