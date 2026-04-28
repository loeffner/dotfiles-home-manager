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

        # Keybindings for word navigation
        bindkey "^[[1;5C" forward-word   # Ctrl+Right
        bindkey "^[[1;5D" backward-word  # Ctrl+Left

        # Keybindings for line navigation
        bindkey "^[[H" beginning-of-line # Pos1
        bindkey "^[[F" end-of-line # End
        bindkey "^[[1~" beginning-of-line # Pos1 (alternate)
        bindkey "^[[4~" end-of-line # End (alternate)

        # Keybindings for delete
        bindkey "^[[3;5~" kill-word  # Ctrl+Delete
        bindkey "^[[3~" delete-char     # Delete

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
      theme = "catppuccin-macchiato";
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
    theme = "catppuccin-macchiato";
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
    settings.theme = "catppuccin-macchiato";
    settings.show_startup_tips = false;
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
    ./tmux
    ./vim
  ];
}
