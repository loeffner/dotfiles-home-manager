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
    paths = [ zennotes.packages.${pkgs.stdenv.hostPlatform.system}.zennotes-desktop ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/zennotes-desktop \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ pkgs.libglvnd ]}:/run/opengl-driver/lib"
    '';
  };

  # Background-blur / virtual-background fix.
  #
  # Discord's background blur runs Google MediaPipe's selfie-segmentation model.
  # MediaPipe opens the bundled `.tflite` model file with O_RDWR (read-write).
  # nixpkgs symlinks Discord's `discord_voice` module into the read-only
  # /nix/store, so that open fails with EACCES; the segmentation graph then
  # errors on every frame and the camera preview goes fully black. (The camera
  # and capture are fine — every other app shows an image; only blur is broken.)
  # Verified by strace:
  #   openat(".../discord_voice/selfie_segmentation_landscape.tflite", O_RDWR)
  #     = -1 EACCES (Permission denied)
  #
  # Fix: after nixpkgs' own stageModules runs, replace the staged discord_voice
  # symlink with one pointing at a writable copy (cached per Discord version in
  # ~/.local/share), so the model can be opened read-write. The large .node/.so
  # files are copied too because MediaPipe resolves the model relative to
  # libmediapipe.so's own location.
  discord-blurfix =
    let
      voiceFixup = pkgs.writeShellScript "discord-voice-writable" ''
        store_modules="$1"
        ver="${pkgs.discord.version}"
        vdst="$HOME/.local/share/discord-voice-writable"
        staged="''${XDG_CONFIG_HOME:-$HOME/.config}/discord/$ver/modules/discord_voice"
        # Build the writable copy once per Discord version (it is ~130 MB).
        if [ ! -e "$vdst/.stamp-$ver" ]; then
          rm -rf "$vdst"
          mkdir -p "$vdst"
          cp -rL "$store_modules/discord_voice/." "$vdst/"
          chmod -R u+rw "$vdst"
          : > "$vdst/.stamp-$ver"
        fi
        # Repoint the symlink stageModules just created (store -> writable copy).
        [ -e "$staged" ] && ln -sfn "$vdst" "$staged"
      '';
    in
    pkgs.discord.overrideAttrs (old: {
      # Run voiceFixup immediately after the `discord-stage-modules` line in the
      # generated launcher (sed: print the matched line, then emit a copy of it
      # with the stage-modules path swapped for voiceFixup — same argument).
      postFixup = (old.postFixup or "") + ''
        sed -i "/-discord-stage-modules /{p; s|/nix/store/[a-z0-9]*-discord-stage-modules |${voiceFixup} |}" \
          "$out/opt/Discord/Discord"
      '';
    });
in
{
  home.username = lib.mkDefault "loeffner";
  home.homeDirectory = lib.mkDefault "/home/loeffner";
  home.stateVersion = lib.mkDefault "25.11";

  home.packages = [
    pkgs.signal-desktop
    # Zen Notes desktop app — trialing it on terra (GL-wrapped, see above).
    zennotes-desktop
    pkgs.darktable
    # geeqie (the culler) lives in ../desktop/geeqie.nix alongside its one-key
    # reject flow.
  ];

  programs.git.settings.user = {
    name = "Andreas Lösel";
    email = "andreas.loesel@outlook.com";
  };

  programs.claude-code.enable = true;
  programs.discord = {
    enable = true;
    package = discord-blurfix;
  };

  # terra is a desktop: pull in the minimal portable Hyprland environment.
  # ../ssh.nix is the personal SSH client config (terra + ocean only).
  imports = [
    ../desktop
    ../ssh.nix
  ];
}
