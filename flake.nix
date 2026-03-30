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
      pkgs = nixpkgs.legacyPackages.${system};
      # Work config (git submodule: ssh://git@stash.mvtec.com:7999/~loesela/home-manager.git)
      # Included when the submodule is checked out, silently skipped otherwise.
      hasWork = builtins.pathExists (self + "/home/work/default.nix");
    in
    {
      homeConfigurations = {
        loesela = home-manager.lib.homeManagerConfiguration {
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
          ] ++ pkgs.lib.optionals hasWork [
            ./home/work
          ];
        };
      };
    };
}
