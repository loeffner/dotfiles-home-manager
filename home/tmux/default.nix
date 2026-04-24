{ pkgs, ... }:
{
  home.file.".tmux.conf".text = ''
    source-file ~/.config/tmux/tmux.conf
  '';

  programs.tmux = {
    enable = true;
    baseIndex = 1;
    mouse = true;
    clock24 = true;
    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      {
        plugin = dracula;
        extraConfig = ''
          set -g @dracula-plugins "cpu-usage ram-usage weather"
          set -g @dracula-show-powerline true
          set -g @dracula-show-fahrenheit false
          set -g @dracula-show-battery false
          set -g @dracula-show-left-icon "♘"
          set -g @dracula-refresh-rate 10
          set -g @dracula-cpu-usage-colors "green dark_gray"
          set -g @dracula-ram-usage-colors "dark_purple white"
        '';
      }
    ];
    keyMode = "vi";
    prefix = "C-Space";
    extraConfig = ''
      set -g default-shell ${pkgs.zsh}/bin/zsh
      set -g default-command "${pkgs.zsh}/bin/zsh -l"

      set -g pane-base-index 1
      set-option -g renumber-windows on
      set -g xterm-keys on
      set -as terminal-features ',xterm*:extkeys'

      # Terminal key compatibility (outside and inside tmux)
      bind -n Home send-keys Home
      bind -n End send-keys End
      bind -n Delete send-keys Delete
      bind -n C-Home send-keys C-Home
      bind -n C-End send-keys C-End

      # Copy-mode navigation helpers
      bind -T copy-mode-vi Home send-keys -X start-of-line
      bind -T copy-mode-vi End send-keys -X end-of-line
      bind -T copy-mode-vi C-Home send-keys -X history-top
      bind -T copy-mode-vi C-End send-keys -X history-bottom

      bind r source-file ~/.config/tmux/tmux.conf
      bind "-" split-window -v -c "#{pane_current_path}"
      bind "\\" split-window -h -c "#{pane_current_path}"
    '';
  };
}
