{ ... }:
{
  # Personal MacBook (Apple Silicon / aarch64-darwin). Runs standalone
  # home-manager on macOS, not nix-darwin.
  imports = [ ../personal.nix ];

  home.homeDirectory = "/Users/loeffner";
}
