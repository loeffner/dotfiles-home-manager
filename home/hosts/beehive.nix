{ config, pkgs, ... }:
{
  # Host-specific settings for beehive
  home.username = "loeffner";
  home.homeDirectory = "/home/loeffner";

  programs.git = {
    userName  = "Andreas Lösel";
    userEmail = "andreas.loesel@outlook.com";
  };
}
