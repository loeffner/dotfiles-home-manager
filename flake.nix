{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # Zen Notes — keyboard-first Markdown notes app (terra only).
    # Pinned to our nixpkgs to share the closure and avoid drift.
    zennotes.url = "github:ZenNotes/zennotes";
    zennotes.inputs.nixpkgs.follows = "nixpkgs";
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

      allSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
    in
    {
      homeConfigurations = {
        ocean = mkConfig "x86_64-linux" ./home/hosts/ocean.nix;
        terra = mkConfig "x86_64-linux" ./home/hosts/terra.nix;
        island = mkConfig "aarch64-darwin" ./home/hosts/island.nix;
      };

      # `nix flake check` builds nothing without this: one check per host,
      # under the system that host runs on.
      checks = lib.genAttrs allSystems (
        system:
        lib.mapAttrs (_: config: config.activationPackage) (
          lib.filterAttrs (
            _: config: config.pkgs.stdenv.hostPlatform.system == system
          ) self.homeConfigurations
        )
      );

      formatter = lib.genAttrs allSystems (system: (pkgsFor system).nixfmt-tree);

      # For private flakes that build on this one: the shared environment, and
      # nixpkgs with this repo's unfree allowlist.
      homeManagerModules.common = ./home/common.nix;
      lib = { inherit pkgsFor; };
    };
}
