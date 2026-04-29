{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      flake-utils,
    }:
    let
      lib = nixpkgs.lib;

      mkConfig =
        system: modules:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            {
              home.username = "loesela";
              home.homeDirectory = "/home/loesela";
              home.stateVersion = "25.11";

              programs.home-manager.enable = true;

              home.packages = with nixpkgs.legacyPackages.${system}; [
                nixfmt
                fd
                bat
                ripgrep
                tealdeer
            		zellij
                nerd-fonts.meslo-lg
              ];

              home.sessionVariables.SHELL = "${pkgs.zsh}/bin/zsh";
           }
            ./home/common.nix
          ]
          ++ modules;
        };

      # name -> extra modules
      configs = {
        # Personal setup (no work stuff)
        personal = [ ];

        # Work setup (includes MVTec/HALCON submodule)
        work = [ ./home/home-manager ];
      };
    in
    {
      homeManagerModules.default = ./home/common.nix;
    }
    # Expose homeConfigurations under legacyPackages.<system> so that
    # `home-manager switch --flake .#work` auto-detects the current system.
    # The home-manager CLI looks up
    #   packages.<system>.homeConfigurations.<name>.activationPackage
    #   legacyPackages.<system>.homeConfigurations.<name>.activationPackage
    #   homeConfigurations.<name>.activationPackage
    # in that order.
    // flake-utils.lib.eachDefaultSystem (system: {
      legacyPackages.homeConfigurations = lib.mapAttrs (_: modules: mkConfig system modules) configs;
    });
}
