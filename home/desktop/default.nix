{ pkgs, ... }:
# Desktop environment: Niri#

# All hardware machinery (GPU drivers, PRIME offload, autologin, AQ_DRM_DEVICES,
# audio, fonts, the dock, the terminal+launcher binaries) lives in NixOS
{
  imports = [
    ./niri.nix
    ./wofi.nix
  ];

  # Cursor theme — sets XCURSOR_THEME/XCURSOR_SIZE/HYPRCURSOR_* and wires up GTK.
  home.pointerCursor = {
    gtk.enable = true;
    hyprcursor.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 22;
  };

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
  xdg.dataFile."applications/.desktop".text = ''
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
