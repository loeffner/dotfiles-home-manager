{ lib, pkgs, ... }:
{
  home.username = lib.mkDefault "loeffner";
  home.homeDirectory = lib.mkDefault "/home/loeffner";
  home.stateVersion = lib.mkDefault "25.11";

  home.packages = with pkgs; [
    signal-desktop
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
