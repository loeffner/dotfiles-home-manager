{ pkgs, lib, ... }:
{
  programs.home-manager.enable = true;

  # Unfree allowlist for the NixOS path (where home-manager builds its own
  # pkgs from `nixpkgs.config`). The standalone path is covered by `pkgsFor`
  # in flake.nix. Both read the same list — see home/unfree.nix.
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (lib.getName pkg) (import ./unfree.nix);

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
