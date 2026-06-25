{ lib, pkgs, zennotes, ... }:
{
  home.username = lib.mkDefault "loeffner";
  home.homeDirectory = lib.mkDefault "/home/loeffner";
  home.stateVersion = lib.mkDefault "25.11";

  home.packages = [
    pkgs.signal-desktop
    # Zen Notes desktop app — trialing it on terra.
    zennotes.packages.${pkgs.system}.zennotes-desktop
  ];

  programs.git.settings.user = {
    name = "Andreas Lösel";
    email = "andreas.loesel@outlook.com";
  };

  programs.claude-code.enable = true;
  programs.discord.enable = true;

  # terra is a desktop: pull in the minimal portable Hyprland environment.
  # ../ssh.nix is the personal SSH client config (terra + ocean only).
  imports = [
    ../desktop
    ../ssh.nix
  ];
}
