{
  lib,
  pkgs,
  zennotes,
  ...
}:
let
  # The upstream zennotes flake ships an Electron binary that isn't wrapped with
  # libglvnd, so on NixOS it can't dlopen the GLVND loader libEGL.so.1: the GPU
  # process dies and it falls back to software rendering (the wall of EGL errors).
  # Wrap it so libglvnd (the loader) plus /run/opengl-driver/lib (mesa/nvidia
  # vendor ICDs) are on LD_LIBRARY_PATH. The .desktop Exec is a bare
  # `zennotes-desktop`, so this single PATH entry fixes both terminal and wofi.
  zennotes-desktop = pkgs.symlinkJoin {
    name = "zennotes-desktop-glwrapped";
    paths = [ zennotes.packages.${pkgs.stdenv.hostPlatform.system}.zennotes-desktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/zennotes-desktop \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.libglvnd ]}:/run/opengl-driver/lib"
    '';
  };
in
{
  home.packages = [
    pkgs.signal-desktop
    # Zen Notes desktop app — trialing it on terra (GL-wrapped, see above).
    zennotes-desktop
    pkgs.darktable
    # geeqie (the culler) lives in ../desktop/geeqie.nix alongside its one-key
    # reject flow.
  ];

  programs.discord.enable = true;

  # terra is a desktop: pull in the niri desktop environment.
  # ../ssh.nix is the personal SSH client config (terra + ocean only).
  imports = [
    ../personal.nix
    ../desktop
    ../ssh.nix
  ];
}
