{ ... }:
# Minimal, portable Hyprland desktop.
#
# Convention: use the home-manager module for an app where the module works
# well (type-checked options, built-in themes); fall back to a hand-written
# config file (deployed via xdg.configFile) only where the module is broken or
# limiting. Right now that exception is Hyprland: the
# wayland.windowManager.hyprland module's settings->Lua translation emits
# invalid binds (legacy comma-strings instead of `hl.bind("MOD + KEY", hl.dsp.*)`),
# so we deploy a hand-written ./hyprland.lua verbatim.
#
# All hardware machinery (GPU drivers, PRIME offload, autologin, AQ_DRM_DEVICES,
# audio, fonts, the dock, the terminal+launcher binaries) lives in NixOS
# (~/beehive). Grow this file out yourself: bar, notifications, more keybinds.
{
  # Hyprland — hand-written Lua (module's Lua output is broken).
  xdg.configFile."hypr/hyprland.lua".source = ./hyprland.lua;

  # Kitty — home-manager module: gruvbox dark + transparency.
  programs.kitty = {
    enable = true;
    font = {
      name = "MesloLGS Nerd Font";
      size = 11;
    };
    themeFile = "gruvbox-dark"; # from the kitty-themes package
    settings = {
      background_opacity = "0.90"; # transparency; tweak 0.0-1.0
      window_padding_width = 6;
      enable_audio_bell = "no";
      confirm_os_window_close = 0;
    };
  };
}
