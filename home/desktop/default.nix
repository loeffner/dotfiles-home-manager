{ pkgs, ... }:
# Desktop environment: Niri#

# All hardware machinery (GPU drivers, PRIME offload, autologin, AQ_DRM_DEVICES,
# audio, fonts, the dock, the terminal+launcher binaries) lives in NixOS
{
  imports = [ ./niri.nix ./wofi.nix ];

  # Cursor theme — sets XCURSOR_THEME/XCURSOR_SIZE/HYPRCURSOR_* and wires up GTK.
  home.pointerCursor = {
    gtk.enable = true;
    hyprcursor.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # When SSHing from Kitty, copy the xterm-kitty terminfo to the remote
  # automatically so the remote shell knows how to handle the terminal.
  home.shellAliases.ssh = "TERM=xterm-256color ssh";

  # Keep HYPRLAND_INSTANCE_SIGNATURE current when reconnecting to old Zellij
  # sessions — the socket changes every login so stale sessions lose hyprctl.
  programs.zsh.initContent = ''
    _hypr_sync() {
      local sig
      sig=$(ls /run/user/$(id -u)/hypr/ 2>/dev/null | tail -n1)
      [[ -n $sig ]] && export HYPRLAND_INSTANCE_SIGNATURE=$sig
    }
    precmd_functions+=(_hypr_sync)
  '';

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

  # Extra desktop GUI tools.
  home.packages = with pkgs; [
    networkmanagerapplet # nm-connection-editor for network management
    swaybg
  ];

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    settings.theme = {
      manager.syntect_theme = "gruvbox-dark";
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
      background_opacity = "0.90"; # transparency; tweak 0.0-1.0
      window_padding_width = 6;
      enable_audio_bell = "no";
      confirm_os_window_close = 0;
    };
    # Paste stays on kitty's default Ctrl+Shift+V, so plain Ctrl+V reaches the
    # running program (e.g. vim's blockwise-visual). The clipboard-history
    # popup lives on Ctrl+Alt+V in the niri config.
  };
}
