# Copilot Instructions

## Overview

This is a **Nix flake** managing personal dotfiles via **Home Manager**. It targets `x86_64-linux` (all hosts) and `aarch64-linux` (work only) and defines per-host home configurations: `beehive`, `ocean` (personal NixOS hosts), and `work` (MVTec, several Ubuntu machines).

The flake is consumed in two modes:
1. **Standalone** Home Manager (e.g. on Ubuntu) via `homeConfigurations.<host>`.
2. **As an input to a NixOS flake** (used by the separate `beehive` NixOS repo) via `homeManagerModules.<host>` — see *NixOS integration* below.

## Build & Apply

```sh
# Apply a configuration (from repo root):
home-manager switch --flake "git+file://$HOME/dotfiles#work"

# Shortcut defined in shell aliases:
hms work   # or: hms beehive / hms ocean

# Format Nix files:
nixfmt **/*.nix

# Evaluate without building (quick syntax/type check):
nix eval .#homeConfigurations.beehive.activationPackage.drvPath
# (work is exposed as work-x86_64-linux / work-aarch64-linux)

# Verify the NixOS-facing module bundles still resolve:
nix eval .#homeManagerModules --apply 'm: builtins.attrNames m'
```

There are no tests or CI pipelines; validation is done by building/switching.

**Important**: New files must be `git add`-ed before `nix eval`/`nix build` — flakes only see tracked files.

## Architecture

```
flake.nix                         # Entry point: inputs, mkConfig, homeModules, homeManagerModules, homeConfigurations
home/
  base.nix                        # Shared: minimal package set (nixfmt, fd, bat, rg, tealdeer, zellij, fonts) + SHELL
  common.nix                      # Shared: zsh, oh-my-posh, fzf, atuin, zoxide, eza, zellij, gpg/ssh; imports ./git and ./vim
  .zsh-aliases                    # Shell aliases and helper functions (shared)
  eselbox.omp.json                # oh-my-posh theme
  hosts/
    beehive.nix                   # Personal NixOS host (defaults: username, git identity, stateVersion)
    ocean.nix                     # Personal NixOS host (currently identical to beehive.nix)
    work/
      default.nix                 # Work host (username, email, git signing, aichat, stateVersion)
      .zsh-work-aliases           # Work-specific shell aliases (Halcon build tools, etc.)
      .zsh-work-env               # Work-specific env vars (sourced at shell init)
  git/default.nix                 # Git settings, aliases, diff/merge tool config
  vim/default.nix                 # Neovim: plugins from nixpkgs, treesitter parsers, LSP
  vim/lua/                        # Neovim Lua config tree (loaded eagerly, no plugin manager)
```

**Module composition**: `flake.nix` exposes two attribute sets of modules:

- `homeModules.{base, common, beehive, ocean, work}` — raw building blocks (paths). Use these if you want to compose your own bundle.
- `homeManagerModules.{beehive, ocean, work, default}` — composite bundles that already `imports = [ base common <host> ]`. These are the NixOS-facing entry points and what `mkConfig` itself consumes for the standalone `homeConfigurations`. `default` aliases `beehive` (the personal hosts share identity).

**Host configs** set identity (`home.username`, `home.homeDirectory`, `home.stateVersion`, `programs.git.settings.user.*`) with `lib.mkDefault` so an outer consumer (e.g. a NixOS flake) can override them. The work host additionally sources its own zsh env/aliases and configures `aichat`.

### NixOS integration

The personal `beehive` NixOS repo (separate flake) imports this flake as `dotfiles` and wires it in like:

```nix
home-manager.users.loeffner = {
  imports = [ dotfiles.homeManagerModules.beehive ];  # or .ocean / .default
  home.username = "loeffner";
  home.homeDirectory = "/home/loeffner";
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;
};
```

Because each `homeManagerModules.<host>` is a single composite module, the consumer never needs to know that `base.nix` and `common.nix` exist — adding a new shared module here automatically reaches the NixOS hosts. **When adjusting the module layout, keep these bundles complete**: anything that should land on a NixOS host must be reachable from `homeManagerModules.<host>`.

## Key Conventions

### Nix

- All packages and plugins come from nixpkgs — no external plugin managers (no lazy.nvim, no Mason).
- Unfree packages are explicitly allowed via `allowUnfreePredicate` in `flake.nix` (currently only `github-copilot-cli`). Add new unfree package names to that predicate when needed.
- Format Nix with `nixfmt` (included in the flake's package set).
- Host configs override shared settings using `lib.mkForce` where needed.
- `home.stateVersion` is set per-host for independent upgrade control.
- Use the modern `programs.git.settings.user.name` / `programs.git.settings.user.email` options (not the deprecated `userName`/`userEmail`).

### Neovim

- **No plugin manager.** Plugins are declared in `vim/default.nix` under `programs.neovim.plugins` and loaded eagerly.
- Each plugin is configured in its own file under `vim/lua/plugins/`. Load order is explicit in `plugins/init.lua`.
- **LSP uses `vim.lsp.config` / `vim.lsp.enable`** (Neovim 0.11+ API). Do NOT use `require("lspconfig").server.setup{}`.
- **Treesitter parsers** are sourced from `nvim-treesitter.passthru.builtGrammars` (not `pkgs.tree-sitter-grammars`) to avoid query/parser version drift. Parsers are symlinked into `~/.config/nvim/parser/`.
- **Treesitter highlighting** is started per-buffer via `vim.treesitter.start()` in an autocmd — `require("nvim-treesitter.configs").setup{}` does not exist on the main branch rewrite.
- Formatting: `conform.nvim` with formatters per-filetype (stylua, nixfmt, clang-format, ruff/black, prettierd).
- Leader key is `<Space>`, local leader is `\`.
- Indentation: 2 spaces (expandtab), enforced in Neovim options.

### Shell

- Default shell is zsh, auto-launched inside zellij (the terminal multiplexer).
- `zoxide` replaces `cd` (aliased via `--cmd cd`).
- `eza` replaces `ls` with git integration.
- Theme: oh-my-posh with a custom config (`eselbox.omp.json`).

### Git

- Default branch is `master` (`init.defaultBranch` in `home/git/default.nix`).
- `push.autoSetupRemote = true` — no need for `-u` on first push.
- `rerere` is enabled for conflict resolution memory.
- Uses histogram diff algorithm.

