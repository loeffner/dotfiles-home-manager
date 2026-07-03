{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Headless zellij plugin that auto-switches between Normal and Locked modes
  # based on the process in the focused pane. While nvim (etc.) is focused
  # zellij locks, so Alt+h/j/k/l pass through to nvim's zellij-nav.nvim for
  # seamless split/pane navigation. https://github.com/fresh2dev/zellij-autolock
  zellijAutolock = pkgs.fetchurl {
    url = "https://github.com/fresh2dev/zellij-autolock/releases/download/0.2.2/zellij-autolock.wasm";
    hash = "sha256-aclWB7/ZfgddZ2KkT9vHA6gqPEkJ27vkOVLwIEh7jqQ=";
  };
in
{
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    nixfmt
    fd
    bat
    ripgrep
    tealdeer
    zellij
    nerd-fonts.meslo-lg
  ];

  home.sessionVariables.SHELL = "${pkgs.zsh}/bin/zsh";

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

        # Line navigation. Bind every Home/End encoding terminals emit: the
        # normal-mode CSI forms, the vt220 alternates, and the application-mode
        # SS3 forms — kitty's terminfo declares the SS3 variants (khome=\EOH,
        # kend=\EOF), so without these Home/End do nothing under kitty.
        bindkey "^[[H" beginning-of-line  # Pos1
        bindkey "^[[F" end-of-line        # End
        bindkey "^[[1~" beginning-of-line # Pos1 (alternate)
        bindkey "^[[4~" end-of-line       # End (alternate)
        bindkey "^[OH" beginning-of-line  # Pos1 (application/kitty)
        bindkey "^[OF" end-of-line        # End  (application/kitty)

        # Deletion
        bindkey "^[[3~"   delete-char                 # Delete: char under cursor
        bindkey "^[[3;5~" zle-kill-word-sep           # Ctrl+Delete: kill word right
        bindkey "^H"      zle-backward-kill-word-sep  # Ctrl+Backspace (sends ^H)
        bindkey "^[[127;5u" zle-backward-kill-word-sep # Ctrl+Backspace (CSI-u variant)

      ''
      (lib.mkAfter ''
        if [[ -z "$ZELLIJ" ]]; then
          # Autostart zellij. Use `zellij` (not `exec`) so that if it crashes
          # the shell — and therefore the terminal window — stays open. On a
          # clean exit, close the shell so the window closes along with it.
          zellij && exit
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
    enableZshIntegration = true;
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

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    shellWrapperName = "y";
    flavors = {
      gruvbox-dark = pkgs.fetchFromGitHub {
        owner = "bennyyip";
        repo = "gruvbox-dark.yazi";
        rev = "619fdc5844db0c04f6115a62cf218e707de2821e";
        hash = "sha256-Y/i+eS04T2+Sg/Z7/CGbuQHo5jxewXIgORTQm25uQb4=";
      };
    };
    theme.flavor = {
      dark = "gruvbox-dark";
    };
  };

  programs.zellij = {
    enable = true;
    # Autostart is handled by hand in the zsh initContent above (mkAfter), so
    # that crashes keep the window open while a clean exit closes the shell.
    # The module's own integration can't express that, so leave it off.
    enableZshIntegration = false;
    settings.theme = "gruvbox-dark";
    settings.show_startup_tips = false;
    # Minimalistic UI: compact bottom bar (no top status bar / help panes)
    # and no pane borders.
    settings.default_layout = "compact";
    settings.pane_frames = true;

    extraConfig = ''
      support_kitty_keyboard_protocol true

      plugins {
          autolock location="file:${zellijAutolock}" {
              is_enabled true
              // Lock zellij (passing keys through) while one of these runs in
              // the focused pane. Pairs with zellij-nav.nvim for Alt+hjkl nav.
              triggers "nvim|vim|fzf|atuin"
              reaction_seconds "0.3"
          }
      }

      load_plugins {
          autolock
      }

      keybinds {
          shared_except "move" "locked" {
              unbind "Ctrl h"
              bind "Alt m" {
                  SwitchToMode "Move";
              }
          }
          // Reassess lock state immediately on Enter (e.g. right after
          // launching nvim) instead of waiting for reaction_seconds.
          normal {
              bind "Enter" {
                  WriteChars "\u{000D}";
                  MessagePlugin "autolock";
              }
          }
          // Keep Alt+f (toggle floating panes) usable while locked, i.e. even
          // when nvim is focused. Other keys still pass through to nvim.
          locked {
              bind "Alt f" {
                  ToggleFloatingPanes;
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
