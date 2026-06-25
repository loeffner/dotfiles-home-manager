{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Zen Notes — keyboard-first Markdown notes app (terra only, trying it out).
    # Left on its own pinned nixpkgs intentionally; don't `follows` while trialing.
    zennotes.url = "github:ZenNotes/zennotes";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      zennotes,
    }:
    let
      lib = nixpkgs.lib;

      # Single source of truth for allowed unfree packages. See home/unfree.nix.
      unfreePackages = import ./home/unfree.nix;

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) unfreePackages;
        };

      # Every host gets base + common, plus its own host module (identity,
      # git user, host-specific extras).
      mkConfig =
        system: hostModule:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          extraSpecialArgs = { inherit zennotes; };
          modules = [
            ./home/common.nix
            hostModule
          ];
        };

      # Systems on which the `work` setup must build. Selected at activation
      # time via `home-manager switch --flake .#work-<system>` (see the `hms`
      # zsh alias, which auto-picks based on `uname -m`).
      workSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      homeConfigurations = {
        beehive = mkConfig "x86_64-linux" ./home/hosts/beehive.nix;
        ocean = mkConfig "x86_64-linux" ./home/hosts/ocean.nix;
        terra = mkConfig "x86_64-linux" ./home/hosts/terra.nix;
        island = mkConfig "aarch64-darwin" ./home/hosts/island.nix;
      }
      // lib.genAttrs (map (s: "work-${s}") workSystems) (
        name: mkConfig (lib.removePrefix "work-" name) ./home/hosts/work
      );
    };
}
