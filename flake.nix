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
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "github-copilot-cli" ];
      };

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

      mkConfig =
        hostModule:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            homeModules.base
            homeModules.common
            hostModule
          ];
        };
    in
    {
      inherit homeModules;

      homeConfigurations = {
        beehive = mkConfig homeModules.beehive;
        ocean = mkConfig homeModules.ocean;
        work = mkConfig homeModules.work;
      };
    };
}
