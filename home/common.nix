{
  config,
  pkgs,
  lib,
  ...
}:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = lib.mkMerge [
      (lib.mkBefore ''

        # Tell zoxide to sit down and be quiet
        export _ZO_DOCTOR=0
      '')
      ''

        source ${./.zsh-aliases}

        # Force the emacs keymap. `programs.neovim.defaultEditor` sets
        # EDITOR=nvim, and zsh selects vi mode whenever $EDITOR/$VISUAL
        # contains the substring "vi" ("nvim" matches). Without this, the
        # main keymap is viins, unbound escape sequences drop into vi command
        # mode, and keys like Ctrl+Backspace toggle case instead of editing.
        bindkey -e

        # Word-wise widgets that stop at punctuation and path separators.
        # The default *-word widgets honour $WORDCHARS (which includes
        # /._-~= etc.), so they skip over whole paths. Locally clearing
        # WORDCHARS makes only alphanumerics count as word constituents.
        zle-forward-word-sep()       { local WORDCHARS=""; zle forward-word; }
        zle-backward-word-sep()      { local WORDCHARS=""; zle backward-word; }
        zle-kill-word-sep()          { local WORDCHARS=""; zle kill-word; }
        zle-backward-kill-word-sep() { local WORDCHARS=""; zle backward-kill-word; }
        zle -N zle-forward-word-sep
        zle -N zle-backward-word-sep
        zle -N zle-kill-word-sep
        zle -N zle-backward-kill-word-sep

        # Word navigation (stops at punctuation / path separators)
        bindkey "^[[1;5C" zle-forward-word-sep   # Ctrl+Right
        bindkey "^[[1;5D" zle-backward-word-sep  # Ctrl+Left

        # Line navigation
        bindkey "^[[H" beginning-of-line  # Pos1
        bindkey "^[[F" end-of-line        # End
        bindkey "^[[1~" beginning-of-line # Pos1 (alternate)
        bindkey "^[[4~" end-of-line       # End (alternate)

        # Deletion
        bindkey "^[[3~"   delete-char                 # Delete: char under cursor
        bindkey "^[[3;5~" zle-kill-word-sep           # Ctrl+Delete: kill word right
        bindkey "^H"      zle-backward-kill-word-sep  # Ctrl+Backspace (sends ^H)
        bindkey "^[[127;5u" zle-backward-kill-word-sep # Ctrl+Backspace (CSI-u variant)

      ''
      (lib.mkAfter ''
        if [[ -z "$ZELLIJ" ]]; then
          exec zellij
        fi
      '')
    ];
  };

  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    package = pkgs.oh-my-posh;
    configFile = ./eselbox.omp.json;
  };

  programs.fzf = {
    enable = true;
  };
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      inline_height = 20;
    };
  };

  programs.bat = {
    config = {
      theme = "gruvbox-dark";
    };
  };
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [
      "--cmd cd"
    ];
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto";
    git = true;
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
  };

  programs.zellij = {
    enable = true;
    enableZshIntegration = true;
    attachExistingSession = false;
    exitShellOnExit = true;
    settings.theme = "gruvbox-dark";
    settings.show_startup_tips = false;
    settings.ui.pane_frames.rounded_corners = true;
    extraConfig = ''
      keybinds {
          shared_except "move" "locked" {
              unbind "Ctrl h"
              bind "Alt m" {
                  SwitchToMode "Move";
                }
              // Enter the "execute" launcher mode (repurposed tmux mode).
              bind "Alt x" {
                  SwitchToMode "Tmux";
                }
            }
          // Execute mode: prefix-style launcher. Each key starts a program /
          // zsh function, then drops back to normal mode. The status bar at
          // the bottom reflects these keys while the mode is active.
          tmux clear-defaults=true {
              // h -> floating pane in the upper-right corner running `mdx`.
              // `-i` makes the shell interactive so aliases load; `exec zsh`
              // keeps the pane open after the alias finishes.
              bind "h" {
                  Run "zsh" "-ic" "mdx; exec zsh" {
                      floating true
                      name "mdx"
                      x "56%"
                      y "7%"
                      width "42%"
                      height "45%"
                    }
                  SwitchToMode "Normal";
                }
              bind "Esc" "Enter" "q" {
                  SwitchToMode "Normal";
                }
            }
        }
    '';
  };

  services.ssh-agent.enable = true;

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 3600;
    defaultCacheTtlSsh = 3600;
    pinentry.package = pkgs.pinentry-curses;
  };

  imports = [
    ./git
    ./vim
  ];
}
