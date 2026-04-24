{
  inputs = {
    self.submodules = true;
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
      pkgs = nixpkgs.legacyPackages.${system};

      mkConfig =
        modules:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            {
              home.username = "loesela";
              home.homeDirectory = "/home/loesela";
              home.stateVersion = "25.11";

              programs.home-manager.enable = true;

              home.packages = with pkgs; [
                nixfmt
                fd
                bat
                ripgrep
                tealdeer
                tmux
                vim
                nerd-fonts.meslo-lg
              ];
            }
            ./home/common.nix
          ]
          ++ modules;
        };
    in
    {
      homeManagerModules.default = ./home/common.nix;

      homeConfigurations = {
        # Personal setup (no work stuff)
        personal = mkConfig [ ];

        # Work setup (includes MVTec/HALCON submodule)
        # Activate with: home-manager switch --flake "git+file://$PWD?submodules=1#work"
        work = mkConfig [
          ./home/home-manager
        ];
      };
    };
}
