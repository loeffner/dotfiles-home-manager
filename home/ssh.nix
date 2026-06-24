# Personal SSH client config, shared by the terra and ocean hosts only (it is
# imported from their host modules, not from common.nix, so the work hosts keep
# their own ssh setup). Replaces the previously hand-maintained ~/.ssh/config.
#
# `enableDefaultConfig = false` opts out of home-manager's implicit `Host *`
# defaults (now deprecated); the OpenSSH built-in defaults they mirrored apply
# instead. We re-add only the one we care about: AddKeysToAgent, so a key is
# handed to the running ssh-agent the first time it's used.
{ ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
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
    };
  };
}
