{
  config,
  pkgs,
  lib,
  ...
}:
let
  hostSssdModule =
    if pkgs.stdenv.hostPlatform.isAarch64 then
      "/lib/aarch64-linux-gnu/libnss_sss.so.2"
    else
      "/lib/x86_64-linux-gnu/libnss_sss.so.2";

  withHostSssd =
    package: executable:
    pkgs.runCommand "${executable}-host-sssd"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta.mainProgram = executable;
      }
      ''
        mkdir -p "$out/bin"
        makeWrapper ${lib.getExe' package executable} "$out/bin/${executable}" \
          --prefix LD_PRELOAD : ${lib.escapeShellArg hostSssdModule}
      '';
in
{
  home.username = lib.mkDefault "loesela";
  home.homeDirectory = lib.mkDefault "/home/loesela";
  home.stateVersion = lib.mkDefault "25.11";

  home.packages = with pkgs; [
    gdb
    devcontainer
    github-copilot-cli
  ];

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

  programs.eza.package = withHostSssd pkgs.eza "eza";
  services.ssh-agent.package = withHostSssd pkgs.openssh "ssh-agent";

}
