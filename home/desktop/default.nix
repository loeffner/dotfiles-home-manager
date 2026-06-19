{ pkgs, ... }:
# Desktop environment: Hyprland + Niri (both deployed; select at login).
#
# Convention: use the home-manager module for an app where the module works
# well (type-checked options, built-in themes); fall back to a hand-written
# config file (deployed via xdg.configFile) only where the module is broken or
# limiting. Current exceptions:
#   Hyprland — wayland.windowManager.hyprland emits invalid Lua binds, so we
#              deploy ./hyprland.lua verbatim.
#   Niri      — hand-written KDL in ./niri.nix (no module dependency needed).
#
# All hardware machinery (GPU drivers, PRIME offload, autologin, AQ_DRM_DEVICES,
# audio, fonts, the dock, the terminal+launcher binaries) lives in NixOS
# (~/beehive). For niri to appear in the SDDM login screen, also add
# `programs.niri.enable = true` there.
{
  imports = [ ./niri.nix ];
  # Hyprland — hand-written Lua (module's Lua output is broken).
  xdg.configFile."hypr/hyprland.lua".source = ./hyprland.lua;

  # Cursor theme — sets XCURSOR_THEME/XCURSOR_SIZE/HYPRCURSOR_* and wires up GTK.
  home.pointerCursor = {
    gtk.enable = true;
    hyprcursor.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  # Wofi — app launcher with Gruvbox dark theme.
  programs.wofi = {
    enable = true;
    settings = {
      width           = 600;
      height          = 400;
      location        = "center";
      show            = "drun";        # desktop apps only; swap for "run" to include $PATH binaries
      prompt          = "Search...";
      filter_rate     = 100;           # debounce ms
      allow_markup    = true;          # pango markup in app names
      insensitive     = true;          # case-insensitive search
      allow_images    = true;          # show app icons
      image_size      = 36;
      no_actions      = true;          # hide secondary actions (e.g. "New Window")
      term            = "kitty";       # terminal used to launch terminal apps
      gtk_dark        = true;
    };
    style = ''
      /* Gruvbox dark palette */
      /* bg shades:  #1d2021  #282828  #3c3836  #504945  #665c54  #7c6f64 */
      /* fg:         #ebdbb2  #d5c4a1  #bdae93                             */
      /* accents:    yellow #d79921  orange #d65d0e  blue #458588          */
      /*             bright-yellow #fabd2f  bright-orange #fe8019          */

      window {
        background-color: #1d2021;
        border:           2px solid #504945;
        border-radius:    10px;
        font-family:      "MesloLGS Nerd Font", monospace;
        font-size:        14px;
        color:            #ebdbb2;
      }

      /* Search input */
      #input {
        background-color: #3c3836;
        color:            #ebdbb2;
        border:           1px solid #504945;
        border-radius:    6px;
        padding:          8px 12px;
        margin:           8px;
        caret-color:      #fabd2f;
      }
      #input:focus {
        border-color:     #d79921;
        outline:          none;
      }

      /* Scroll area + entry list */
      #scroll {
        margin: 0 8px 8px 8px;
      }
      #inner-box {
        background-color: transparent;
      }
      #outer-box {
        background-color: transparent;
        padding:          4px;
      }

      /* Individual entries */
      #entry {
        background-color: transparent;
        border-radius:    6px;
        padding:          6px 10px;
        margin:           2px 0;
      }
      #entry:selected {
        background-color: #3c3836;
        border:           1px solid #d79921;
      }

      /* Entry text */
      #text {
        color:   #ebdbb2;
        margin:  0 8px;
      }
      #entry:selected #text {
        color:   #fabd2f;
      }

      /* App icons */
      #entry image {
        min-width:  36px;
        min-height: 36px;
      }
    '';
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

  # Audio device picker: wofi menu to switch PipeWire sink or source.
  home.file.".local/bin/audio-sink-picker".text = ''
    #!/usr/bin/env bash
    chosen=$(wpctl status | awk '
      /Sinks:/        { in_sinks=1; in_sources=0 }
      /Sources:/      { in_sources=1; in_sinks=0 }
      /[A-Z][a-z]*s:/ { if ($0 !~ /Sinks:|Sources:/) { in_sinks=0; in_sources=0 } }
      in_sinks && /^\s+[├└│ ]*[*]?\s+[0-9]+\./ {
        match($0, /[0-9]+\. (.+)/, a)
        id = a[0]+0; gsub(/[^0-9].*/, "", id)
        name = a[1]; gsub(/\[vol.*/, "", name); gsub(/^ +| +$/, "", name)
        print id ": " name
      }
    ' | wofi --dmenu --prompt "Output device" --location=3 --yoffset=32 --width=400)
    [[ -z "$chosen" ]] && exit
    id=$(echo "$chosen" | cut -d: -f1)
    wpctl set-default "$id"
  '';
  home.file.".local/bin/audio-sink-picker".executable = true;

  home.file.".local/bin/audio-source-picker".text = ''
    #!/usr/bin/env bash
    chosen=$(wpctl status | awk '
      /Sources:/      { in_sources=1 }
      /[A-Z][a-z]*s:/ { if ($0 !~ /Sources:/) in_sources=0 }
      in_sources && /^\s+[├└│ ]*[*]?\s+[0-9]+\./ {
        match($0, /[0-9]+\. (.+)/, a)
        id = a[0]+0; gsub(/[^0-9].*/, "", id)
        name = a[1]; gsub(/\[vol.*/, "", name); gsub(/^ +| +$/, "", name)
        print id ": " name
      }
    ' | wofi --dmenu --prompt "Input device" --location=3 --yoffset=40 --width=400)
    [[ -z "$chosen" ]] && exit
    id=$(echo "$chosen" | cut -d: -f1)
    wpctl set-default "$id"
  '';
  home.file.".local/bin/audio-source-picker".executable = true;

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    settings.theme = {
      manager.syntect_theme = "gruvbox-dark";
    };
  };

  # Waybar — status bar.
  programs.waybar = {
    enable = true;
    settings = [{
      layer    = "top";
      position = "top";
      height   = 32;
      spacing  = 4;

      modules-left   = [ "hyprland/workspaces" ];
      modules-center = [ "clock" ];
      modules-right  = [ "pulseaudio#microphone" "pulseaudio" "network" ];

      "hyprland/workspaces" = {
        format   = "{id}";
        on-click = "activate";
      };

      clock = {
        format         = "{:%H:%M}";
        format-alt     = "{:%d. %b %Y  %H:%M}";
        tooltip-format = "<big>{:%B %Y}</big>\n<tt>{calendar}</tt>";
      };

      # Speaker / output volume — icon only; hover tooltip shows percentage.
      pulseaudio = {
        format         = "{icon}";
        format-muted   = "󰝟";
        format-icons   = { default = [ "󰕿" "󰖀" "󰕾" ]; };
        tooltip-format = "{volume}% — {desc}";
        on-click       = "$HOME/.local/bin/audio-sink-picker";
        on-scroll-up   = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
        on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
      };

      # Microphone / input volume — icon only; hover tooltip shows percentage.
      "pulseaudio#microphone" = {
        format              = "{format_source}";
        format-source       = "󰍬";
        format-source-muted = "󰍭";
        tooltip-format      = "{source_volume}% — {source_desc}";
        on-click            = "$HOME/.local/bin/audio-source-picker";
        on-scroll-up        = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+";
        on-scroll-down      = "wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-";
      };

      network = {
        format-wifi        = "󰤨  {essid} ({signalStrength}%)";
        format-ethernet    = "󰈀  {ipaddr}";
        format-disconnected = "󰤭  disconnected";
        tooltip-format     = "{ifname}: {ipaddr}/{cidr}";
        on-click           = "nm-connection-editor";
      };
    }];

    style = ''
      /* Gruvbox dark palette                                                    */
      /* bg:  #1d2021  #282828  #3c3836  #504945  #665c54  #7c6f64              */
      /* fg:  #ebdbb2  #d5c4a1  #bdae93  #a89984                                */
      /* acc: yellow #d79921/#fabd2f  orange #d65d0e/#fe8019                    */
      /*      blue #458588/#83a598    green #98971a/#b8bb26                     */
      /*      red #cc241d/#fb4934     aqua #689d6a/#8ec07c                      */

      * {
        font-family:    "MesloLGS Nerd Font", monospace;
        font-size:      13px;
        border:         none;
        border-radius:  0;
        min-height:     0;
      }

      window#waybar {
        background-color: rgba(29, 32, 33, 0.85);
        color:            #ebdbb2;
        border-bottom:    2px solid rgba(60, 56, 54, 0.6);
      }

      /* pill shared by all modules */
      #workspaces,
      #clock,
      #pulseaudio,
      #microphone,
      #network {
        background-color: rgba(40, 40, 40, 0.7);
        color:            #ebdbb2;
        padding:          0 12px;
        margin:           4px 3px;
        border-radius:    6px;
      }

      /* ── Workspaces ── */
      #workspaces {
        padding: 0 4px;
      }
      #workspaces button {
        color:      #a89984;
        padding:    0 6px;
        background: transparent;
      }
      #workspaces button:hover {
        background:    #3c3836;
        color:         #ebdbb2;
        border-radius: 4px;
      }
      #workspaces button.active {
        color:       #fabd2f;
        font-weight: bold;
      }
      #workspaces button.urgent {
        color: #fb4934;
      }

      /* ── Clock ── */
      #clock {
        color:       #83a598;
        font-weight: bold;
      }

      /* ── Audio ── */
      #pulseaudio        { color: #b8bb26; }
      #pulseaudio.muted  { color: #665c54; }
      #microphone        { color: #8ec07c; }
      #microphone.muted  { color: #665c54; }

      /* ── Network ── */
      #network               { color: #83a598; }
      #network.disconnected  { color: #fb4934; }
    '';
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
  };
}
