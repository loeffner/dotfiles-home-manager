# Copilot Instructions

## Overview

This is a **Nix flake** managing personal dotfiles via **Home Manager**. It targets `x86_64-linux` and defines per-host home configurations: `beehive`, `ocean` (personal), and `work` (MVTec).

## Build & Apply

```sh
# Apply a configuration (from repo root):
home-manager switch --flake "git+file://$HOME/dotfiles#work"

# Shortcut defined in shell aliases:
hms work   # or: hms beehive / hms ocean

# Format Nix files:
nixfmt **/*.nix

# Evaluate without building (quick syntax/type check):
nix eval .#homeConfigurations.work.activationPackage
```

There are no tests or CI pipelines; validation is done by building/switching.

**Important**: New files must be `git add`-ed before `nix eval`/`nix build` — flakes only see tracked files.

## Architecture

```
flake.nix                         # Entry point: inputs, mkConfig helper, homeConfigurations
home/
  common.nix                      # Shared: zsh, oh-my-posh, fzf, atuin, zoxide, eza, zellij, gpg/ssh
  .zsh-aliases                    # Shell aliases and helper functions (shared)
  hosts/
    beehive.nix                   # Personal host (username, git identity, stateVersion)
    ocean.nix                     # Personal host (username, git identity, stateVersion)
    work/
      default.nix                 # Work host (username, email, git signing, aichat, stateVersion)
      .zsh-work-aliases           # Work-specific shell aliases (Halcon build tools, etc.)
      .zsh-work-env               # Work-specific env vars (sourced at shell init)
  git/default.nix                 # Git settings, aliases, diff/merge tool config
  vim/default.nix                 # Neovim: plugins from nixpkgs, treesitter parsers, LSP
  vim/lua/                        # Neovim Lua config tree (loaded eagerly, no plugin manager)
```

**Module composition**: `flake.nix` defines `mkConfig` which merges a base inline module (packages, shell), `home/common.nix`, and one host-specific module. `common.nix` imports `./git` and `./vim`.

**Host configs** set identity (`home.username`, `home.homeDirectory`, `home.stateVersion`, `programs.git.settings.user.*`) and host-specific programs/overrides. The work host additionally sources its own zsh env/aliases and configures `aichat`.

## Key Conventions

### Nix

- All packages and plugins come from nixpkgs — no external plugin managers (no lazy.nvim, no Mason).
- Unfree packages are explicitly allowed via `allowUnfreePredicate` in `flake.nix`.
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

- Default branch is `master`.
- `push.autoSetupRemote = true` — no need for `-u` on first push.
- `rerere` is enabled for conflict resolution memory.
- Uses histogram diff algorithm.

