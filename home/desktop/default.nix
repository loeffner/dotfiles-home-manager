{ ... }:
# Minimal, portable Hyprland desktop. The real config is hand-written in
# ./hyprland.lua (Lua format — what start-hyprland reads); home-manager just
# deploys it verbatim. We deliberately do NOT use the
# wayland.windowManager.hyprland module: its settings->Lua translation emits
# invalid binds (legacy comma-strings instead of `hl.bind("MOD + KEY", hl.dsp.*)`).
#
# Bare on purpose — grow it yourself (bar, notifications, theming, more binds).
# All hardware machinery (GPU drivers, PRIME offload, autologin, AQ_DRM_DEVICES,
# audio, fonts, the dock, the terminal+launcher) lives in NixOS (~/beehive).
{
  xdg.configFile."hypr/hyprland.lua".source = ./hyprland.lua;
}
