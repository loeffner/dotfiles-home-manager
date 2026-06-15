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
    # Write classic hyprland.conf syntax (the home-manager default for this
    # stateVersion); pinned so the choice is explicit and the deprecation
    # warning is silenced.
    configType = "hyprlang";

    settings = {
      # Auto-detect whatever monitor is attached (incl. the USB4 dock).
      monitor = ",preferred,auto,auto";

      "$mod" = "SUPER";

      bind = [
        "$mod, Return, exec, kitty" # terminal (provided by NixOS)
        "$mod, R, exec, wofi --show drun" # app launcher (provided by NixOS)
        "$mod, Q, killactive,"
        "$mod, M, exit,"

        # Move focus
        "$mod, left, movefocus, l"
        "$mod, right, movefocus, r"
        "$mod, up, movefocus, u"
        "$mod, down, movefocus, d"

        # Workspaces
        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"
        "$mod, 4, workspace, 4"
        "$mod, 5, workspace, 5"
        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"
        "$mod SHIFT, 4, movetoworkspace, 4"
        "$mod SHIFT, 5, movetoworkspace, 5"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
    };
  };
}
