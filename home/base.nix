{ pkgs, ... }:
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
}
