{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
    }:
    let
      lib = nixpkgs.lib;

      # Reusable home-manager modules. These are consumed both by the
      # standalone homeConfigurations below and by external flakes that wire
      # home-manager into NixOS via home-manager.nixosModules.home-manager.
      homeModules = {
        base = ./home/base.nix;
        common = ./home/common.nix;
        beehive = ./home/hosts/beehive.nix;
        ocean = ./home/hosts/ocean.nix;
        work = ./home/hosts/work;
      };

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "github-copilot-cli" "claude-code"];
        };

      # NixOS-friendly entry points. External flakes wire these into a system
      # via `home-manager.nixosModules.home-manager` and add
      # `dotfiles.homeManagerModules.<host>` (or `.default`) to the user's
      # `imports`. Each bundle is a single composite module that already pulls
      # in `base` + `common` + the host module, so consumers only need to set
      # per-machine identity (username, homeDirectory, stateVersion).
      homeManagerModules = {
        beehive.imports = [
          homeModules.base
          homeModules.common
          homeModules.beehive
        ];
        ocean.imports = [
          homeModules.base
          homeModules.common
          homeModules.ocean
        ];
        work.imports = [
          homeModules.base
          homeModules.common
          homeModules.work
        ];
        # `default` targets the personal NixOS hosts (beehive, ocean). They
        # share the same identity, so a single bundle is enough for both.
        default.imports = [
          homeModules.base
          homeModules.common
          homeModules.beehive
        ];
      };

      mkConfig =
        system: hostBundle:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules = [ hostBundle ];
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
      inherit homeModules homeManagerModules;

      homeConfigurations = {
        beehive = mkConfig "x86_64-linux" homeManagerModules.beehive;
        ocean = mkConfig "x86_64-linux" homeManagerModules.ocean;
      }
      // lib.genAttrs (map (s: "work-${s}") workSystems) (
        name:
        let
          system = lib.removePrefix "work-" name;
        in
        mkConfig system homeManagerModules.work
      );
    };
}
