{ ... }:
{
  # ../ssh.nix is the personal SSH client config (terra + ocean only).
  imports = [
    ../personal.nix
    ../ssh.nix
  ];
}
