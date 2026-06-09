# Single source of truth for the unfree packages allowed across all hosts.
# Consumed by `pkgsFor` in flake.nix (standalone path) and by the
# `allowUnfreePredicate` set in home/base.nix (NixOS path). A name listed
# here is allowed everywhere; per-host distinctions are intentionally not
# supported.
[
  "openweb-ui"
  "claude-code"
  "github-copilot-cli"
]
