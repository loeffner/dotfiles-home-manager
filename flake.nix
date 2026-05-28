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
          config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "github-copilot-cli" ];
        };

      mkConfig =
        system: hostModule:
        home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor system;
          modules = [
            homeModules.base
            homeModules.common
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
      inherit homeModules;

      homeConfigurations = {
        beehive = mkConfig "x86_64-linux" homeModules.beehive;
        ocean = mkConfig "x86_64-linux" homeModules.ocean;
      }
      // lib.genAttrs (map (s: "work-${s}") workSystems) (
        name:
        let
          system = lib.removePrefix "work-" name;
        in
        mkConfig system homeModules.work
      );
    };
}
