{ lib, ... }:
{
  # Personal MacBook (Apple Silicon / aarch64-darwin). Runs standalone
  # home-manager on macOS, not nix-darwin.
  home.username = lib.mkDefault "loeffner";
  home.homeDirectory = lib.mkDefault "/Users/loeffner";
  home.stateVersion = lib.mkDefault "25.11";

  programs.git.settings.user = {
    name = "Andreas Lösel";
    email = "andreas.loesel@outlook.com";
  };

  programs.claude-code.enable = true;
}
