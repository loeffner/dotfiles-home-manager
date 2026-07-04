# Personal SSH client config, shared by the terra and ocean hosts only (it is
# imported from their host modules, not from common.nix, so the work hosts keep
# their own ssh setup). Replaces the previously hand-maintained ~/.ssh/config.
#
# `enableDefaultConfig = false` opts out of home-manager's implicit `Host *`
# defaults (now deprecated); the OpenSSH built-in defaults they mirrored apply
# instead. We re-add only the one we care about: AddKeysToAgent, so a key is
# handed to the running ssh-agent the first time it's used. The time interval
# (instead of plain "yes") caps how long the agent holds a key — without it,
# keys stay usable until logout.
{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        AddKeysToAgent = "12h";
      };

      terra = {
        HostName = "terra";
        Port = 22;
        User = "loeffner";
        IdentityFile = "~/.ssh/id_ed25519";
      };

      ocean = {
        HostName = "ocean";
        Port = 22;
        User = "loeffner";
        IdentityFile = "~/.ssh/id_ed25519";
      };

      ploetze = {
        HostName = "ploetze";
        IdentityFile = "~/.ssh/ploetze";
        Port = 2222;
        User = "root";
      };
    };
  };
}
