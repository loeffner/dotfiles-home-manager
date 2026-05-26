{ ... }:
{
  home.username = "loeffner";
  home.homeDirectory = "/home/loeffner";
  home.stateVersion = "25.11";

  programs.git.settings.user = {
    name = "Andreas Lösel";
    email = "andreas.loesel@outlook.com";
  };
}
