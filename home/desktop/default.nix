{
  config,
  pkgs,
  dms,
  ...
}:
# Desktop environment: Niri#

# All hardware machinery (GPU drivers, PRIME offload, autologin, AQ_DRM_DEVICES,
# audio, fonts, the dock, the terminal+launcher binaries) lives in NixOS
{
  imports = [
    ./niri
    ./wofi.nix
    ./camera-import.nix
    ./geeqie.nix
    # DankMaterialShell, kept installed alongside the custom shell in
    # ./quickshell for feature-by-feature comparison. It runs its QML from the
    # Nix store (`dms run` wraps `qs -c <store>`), so it doesn't collide with the
    # custom config at ~/.config/quickshell. Autostart stays off — shell-switch
    # (niri) drives which one runs and remembers the choice.
    dms.homeModules.dank-material-shell
  ];

  programs.dank-material-shell.enable = true; # `dms run`

  # Cursor theme — sets XCURSOR_THEME/XCURSOR_SIZE/HYPRCURSOR_* and wires up GTK.
  home.pointerCursor = {
    gtk.enable = true;
    hyprcursor.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 22;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.niri = {
      default = [
        "gnome"
        "gtk"
      ];
      # File dialogs via the GTK portal so we don't need nautilus (the gnome
      # portal's FileChooser shells out to nautilus on v47+).
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      # This whole file *replaces* the niri module's /etc/xdg niri-portals.conf
      # (first-found-wins, no merging), so the Secret backend must be named
      # here explicitly — only gnome-keyring implements it, and dropping it
      # leaves the Secret portal with no backend.
      "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
    };
  };

  gtk = {
    enable = true;
    theme = {
      name = "Gruvbox-Dark";
      package = pkgs.gruvbox-gtk-theme;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    # Keep the pre-26.05 behavior of theming GTK4 apps with the GTK3 theme
    # (gruvbox-gtk-theme ships gtk-4.0 assets). The default changed to `null`;
    # set it explicitly to silence the deprecation warning.
    gtk4.theme = config.gtk.theme;
  };

  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  # When SSHing from Kitty, copy the xterm-kitty terminfo to the remote
  # automatically so the remote shell knows how to handle the terminal.
  home.shellAliases.ssh = "TERM=xterm-256color ssh";

  # Hide terminal-only apps from the launcher — override the system .desktop
  # entries with NoDisplay=true so all launchers ignore them.
  xdg.dataFile."applications/htop.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=htop
    NoDisplay=true
  '';
  xdg.dataFile."applications/nvim.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Neovim
    NoDisplay=true
  '';
  xdg.dataFile."applications/yazi.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Yazi
    NoDisplay=true
  '';

  # Extra desktop GUI tools.
  home.packages = with pkgs; [
    networkmanagerapplet # nm-connection-editor — the bar's "advanced" net escape hatch
    swaybg
    libnotify # notify-send — emit notifications (testing the bar's notif server)
    playerctl # MPRIS control for the media function-key binds (niri.nix)
    quickshell # QtQuick desktop-shell toolkit; runs the bar in ./quickshell
    material-symbols # Material Symbols Rounded — icon font for the DMS-grade cluster
    libcanberra-gtk3 # canberra-gtk-play — notification sound effects (Sound.qml)
    sound-theme-freedesktop # the freedesktop sound theme canberra plays from
    dgop # system-metrics helper (same as DMS); backs SystemStats / the Processes panel
  ];

  # Quickshell bar config (hand-written QML, see ./quickshell). Static QML, so
  # the whole tree is symlinked verbatim. Autostarted from niri (see niri.nix).
  # NOTE: new files here must be `git add`-ed before the flake will see them.
  xdg.configFile."quickshell" = {
    source = ./quickshell;
    recursive = true;
  };

  # Screen locker (ext-session-lock, works on niri). swaylock-effects rather
  # than vanilla swaylock: plain swaylock draws NOTHING at idle (just the flat
  # background color; the ring only appears while typing), which reads as a
  # broken empty screen. This shows a blurred screenshot of the session with a
  # clock inside an always-visible Gruvbox ring. daemonize=true makes every
  # plain `swaylock` invocation fork — required for the swayidle before-sleep
  # hook (swayidle -w would otherwise wait for the unlock before allowing the
  # suspend). Triggers: Mod+Escape (binds.nix), the lock button in the bar's
  # control center, idle timeout and before-sleep (both niri/settings.nix).
  #
  # NixOS side (NOT applied by home-manager — add to terra's system config):
  # swaylock authenticates through PAM, and a user-installed swaylock has no
  # /etc/pam.d/swaylock, so unlocking would ALWAYS fail (test with a throwaway
  # lock before relying on it). The binary and PAM service are still named
  # `swaylock` in the -effects fork. Register the PAM service system-side:
  #
  #   security.pam.services.swaylock = { };
  programs.swaylock = {
    enable = true;
    package = pkgs.swaylock-effects;
    settings = {
      daemonize = true;
      ignore-empty-password = true;
      show-failed-attempts = true;

      # Blurred screenshot of the session as the backdrop; flat color is only
      # the fallback if the screenshot fails. No vignette — its radial
      # gradient bands visibly (discrete brightness steps) on this monitor.
      screenshots = true;
      effect-blur = "20x6";
      fade-in = 0.15;
      color = "1d2021";
      # The xkb layout indicator ("English (US)" in a box while typing) is
      # ugly; the bar already shows a DE badge when the alternate is active.
      hide-keyboard-layout = true;

      # Clock inside an always-visible ring (typing state replaces the time).
      clock = true;
      timestr = "%H:%M";
      datestr = "%a, %d %b";
      indicator = true;
      indicator-idle-visible = true;
      indicator-radius = 110;
      indicator-thickness = 8;
      font = "MesloLGS Nerd Font";

      # Gruvbox: translucent plate so the blur shows through. The resting /
      # verifying ring color is the BAR'S CURRENT ACCENT, injected at lock
      # time by the swaylock-themed wrapper (niri/default.nix) — the values
      # here are only the fallback for a bare `swaylock` call. Typing flashes
      # near-white and backspace/wrong flash bright red, so both contrast
      # against every accent hue.
      inside-color = "282828aa";
      line-color = "00000000";
      separator-color = "00000000";
      text-color = "ebdbb2";
      ring-color = "458588";
      key-hl-color = "fbf1c7";
      bs-hl-color = "fb4934";
      inside-ver-color = "282828aa";
      ring-ver-color = "458588";
      text-ver-color = "ebdbb2";
      inside-wrong-color = "282828aa";
      ring-wrong-color = "fb4934";
      text-wrong-color = "ebdbb2";
    };
  };

  # Kitty — home-manager module: gruvbox dark + transparency.
  programs.kitty = {
    enable = true;
    font = {
      name = "MesloLGS Nerd Font";
      size = 11;
    };
    themeFile = "gruvbox-dark"; # from the kitty-themes package
    settings = {
      background_opacity = "0.80"; # transparency; tweak 0.0-1.0
      window_padding_width = 0;
      enable_audio_bell = "no";
      confirm_os_window_close = 0;
    };
  };
}
