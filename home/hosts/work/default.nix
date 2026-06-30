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
    github-copilot-cli
  ];

  custom.copilot.enable = true;

  programs.git = {
    settings.user.name = "Andreas Lösel";
    settings.user.email = "andreas.loesel@mvtec.com";

    signing = {
      key = "9617B4071A0782ABF39642FC7A5328AA1A546BFB";
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
