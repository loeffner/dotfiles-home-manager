# Shared module for the personal (non-work) hosts: identity + personal tooling.
# Identity fields use lib.mkDefault so a host module can still override them
# (island overrides homeDirectory for macOS).
{ lib, ... }:
{
  home.username = lib.mkDefault "loeffner";
  home.homeDirectory = lib.mkDefault "/home/loeffner";
  home.stateVersion = lib.mkDefault "25.11";

  programs.git.settings.user = {
    name = "Andreas Lösel";
    email = "andreas.loesel@outlook.com";
  };

  programs.claude-code.enable = true;
}
