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

        # Work environment
        umask 0027

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

        # Keybindings for delete
        bindkey "^[[3~" delete-char     # Delete
      ''
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
      theme = "gruvbox-dark-hard";
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
    git = false;
    theme = "gruvbox-dark";
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
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
  ];
}
