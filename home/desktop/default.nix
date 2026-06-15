{ ... }:
# Minimal, portable Hyprland starting point. Deliberately bare — just enough to
# be usable (terminal, launcher, window/workspace control) so you can add
# everything else (bar, notifications, theming, animations, extra keybinds)
# step by step yourself. All hardware-specific machinery (GPU drivers, PRIME
# offload, autologin, AQ_DRM_DEVICES, audio, fonts, the dock) lives in the
# NixOS config (~/beehive hosts/terra), NOT here.
{
  wayland.windowManager.hyprland = {
    enable = true;
    # The compositor itself comes from NixOS `programs.hyprland`; here we only
    # write the config. null avoids pulling a second, mismatched Hyprland in.
    package = null;
    portalPackage = null;
    # Emit hyprland.lua. The NixOS session launches via `start-hyprland`, which
    # parses the config as Lua, so we must write Lua (not hyprlang/hyprland.conf,
    # which start-hyprland chokes on at line 1). NOTE: don't use a "$mod"
    # variable in `settings` — HM's Lua translator turns it into invalid
    # `hl.$mod(...)`. Inline SUPER in each bind instead.
    configType = "lua";

    settings = {
      # Auto-detect whatever monitor is attached (incl. the USB4 dock).
      monitor = ",preferred,auto,auto";

      bind = [
        "SUPER, Return, exec, kitty" # terminal (provided by NixOS)
        "SUPER, R, exec, wofi --show drun" # app launcher (provided by NixOS)
        "SUPER, Q, killactive,"
        "SUPER, M, exit,"

        # Move focus
        "SUPER, left, movefocus, l"
        "SUPER, right, movefocus, r"
        "SUPER, up, movefocus, u"
        "SUPER, down, movefocus, d"

        # Workspaces
        "SUPER, 1, workspace, 1"
        "SUPER, 2, workspace, 2"
        "SUPER, 3, workspace, 3"
        "SUPER, 4, workspace, 4"
        "SUPER, 5, workspace, 5"
        "SUPER SHIFT, 1, movetoworkspace, 1"
        "SUPER SHIFT, 2, movetoworkspace, 2"
        "SUPER SHIFT, 3, movetoworkspace, 3"
        "SUPER SHIFT, 4, movetoworkspace, 4"
        "SUPER SHIFT, 5, movetoworkspace, 5"
      ];

      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];
    };
  };
}
