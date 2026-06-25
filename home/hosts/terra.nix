{ lib, pkgs, zennotes, ... }:
let
  # The upstream zennotes flake ships an Electron binary that isn't wrapped with
  # libglvnd, so on NixOS it can't dlopen the GLVND loader libEGL.so.1: the GPU
  # process dies and it falls back to software rendering (the wall of EGL errors).
  # Wrap it so libglvnd (the loader) plus /run/opengl-driver/lib (mesa/nvidia
  # vendor ICDs) are on LD_LIBRARY_PATH. The .desktop Exec is a bare
  # `zennotes-desktop`, so this single PATH entry fixes both terminal and wofi.
  zennotes-desktop = pkgs.symlinkJoin {
    name = "zennotes-desktop-glwrapped";
    paths = [ zennotes.packages.${pkgs.system}.zennotes-desktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/zennotes-desktop \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.libglvnd ]}:/run/opengl-driver/lib"
    '';
  };
in
{
  home.username = lib.mkDefault "loeffner";
  home.homeDirectory = lib.mkDefault "/home/loeffner";
  home.stateVersion = lib.mkDefault "25.11";

  home.packages = [
    pkgs.signal-desktop
    # Zen Notes desktop app — trialing it on terra (GL-wrapped, see above).
    zennotes-desktop
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
