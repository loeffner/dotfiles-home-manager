{ config, pkgs, dms, ... }:
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
      default = [ "gnome" "gtk" ];
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
