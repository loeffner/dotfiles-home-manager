{
  config,
  pkgs,
  lib,
  ...
}:
{
  home.username = lib.mkDefault "loesela";
  home.homeDirectory = lib.mkDefault "/home/loesela";
  home.stateVersion = lib.mkDefault "25.11";

  home.packages = with pkgs; [
    gdb
    devcontainer
    github-copilot-cli
  ];

  custom.copilot.enable = false;

  programs.git = {
    settings.user.name = "Andreas Lösel";
    settings.user.email = "andreas.loesel@mvtec.com";

    signing = {
      key = "139D28D04F7B80DC514FC1135E46167EC018E93A";
    };

    includes = [
      { path = "~/.gitconfig.work"; }
    ];
  };

  programs.zsh.initContent = lib.mkAfter ''
    umask 0027
    source ${./.zsh-work-env}
    source ${./.zsh-work-aliases}
  '';

  programs.atuin.settings.dbPath = lib.mkForce "/mvtec/home/loesela/atuin/atuin.db";
}
