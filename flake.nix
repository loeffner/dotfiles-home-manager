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
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [ "github-copilot-cli" ];
      };

      mkConfig =
        modules:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            {
              home.stateVersion = "25.11";

              programs.home-manager.enable = true;

              home.packages = with pkgs; [
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
    in
    {
      homeManagerModules.default = ./home/common.nix;

      homeConfigurations = {
        beehive = mkConfig [
          ./home/hosts/beehive.nix
        ];

        ocean = mkConfig [
          ./home/hosts/ocean.nix
        ];
      };
    };
}
