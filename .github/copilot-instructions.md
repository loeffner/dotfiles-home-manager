# Copilot Instructions

## Overview

This is a **Nix flake** managing personal dotfiles via **Home Manager**. It spans `x86_64-linux` (personal + work), `aarch64-linux` (work) and `aarch64-darwin` (the personal MacBook). It defines per-host home configurations: `beehive`, `ocean` (personal NixOS hosts), `island` (personal MacBook, standalone home-manager on macOS — not nix-darwin), and `work` (MVTec, several Ubuntu machines).

The flake provides **standalone** Home Manager configurations only, applied via `homeConfigurations.<host>` with `home-manager switch --flake`. The personal NixOS hosts (`beehive`, `ocean`) just install the `home-manager` CLI and apply these configs out-of-band — the flake is **not** wired into NixOS as a module.

## Build & Apply

```sh
# Apply a configuration (from repo root):
home-manager switch --flake "git+file://$HOME/dotfiles#work"

# Shortcut defined in shell aliases:
hms work   # or: hms beehive / hms ocean / hms island

# Format Nix files:
nixfmt **/*.nix

# Evaluate without building (quick syntax/type check):
nix eval .#homeConfigurations.beehive.activationPackage.drvPath
# (island is exposed as `island`; work as work-x86_64-linux / work-aarch64-linux)

# Check the whole flake:
nix flake check
```

There are no tests or CI pipelines; validation is done by building/switching.

**Important**: New files must be `git add`-ed before `nix eval`/`nix build` — flakes only see tracked files.

## Architecture

```
flake.nix                         # Entry point: inputs, mkConfig, homeConfigurations
home/
  base.nix                        # Shared: minimal package set (nixfmt, fd, bat, rg, tealdeer, zellij, fonts) + SHELL
  common.nix                      # Shared: zsh, oh-my-posh, fzf, atuin, zoxide, eza, zellij, gpg/ssh; imports ./git and ./vim
  unfree.nix                      # Single source of truth: allowed unfree package names (consumed by flake.nix)
  .zsh-aliases                    # Shell aliases and helper functions (shared)
  eselbox.omp.json                # oh-my-posh theme
  hosts/
    beehive.nix                   # Personal NixOS host (defaults: username, git identity, stateVersion)
    ocean.nix                     # Personal NixOS host (currently identical to beehive.nix)
    island.nix                    # Personal MacBook (aarch64-darwin, standalone home-manager); enables claude-code
    work/
      default.nix                 # Work host (username, email, git signing, aichat, stateVersion)
      .zsh-work-aliases           # Work-specific shell aliases (Halcon build tools, etc.)
      .zsh-work-env               # Work-specific env vars (sourced at shell init)
  git/default.nix                 # Git settings, aliases, diff/merge tool config
  vim/default.nix                 # Neovim: plugins from nixpkgs, treesitter parsers, LSP
  vim/lua/config/                 # Core editor config: options, keymaps, autocmds, lsp
  vim/lua/plugins/                # Per-plugin config; load order set in plugins/init.lua
  vim/README.md                   # Neovim notes incl. treesitter wiring gotchas on current nixpkgs
```

**Module composition**: `flake.nix` defines a single helper, `mkConfig system hostModule`, which builds a `homeManagerConfiguration` from `[ base common <host> ]`. Each entry in `homeConfigurations` is one `mkConfig` call; `work` is fanned out over `workSystems` (x86_64-linux, aarch64-linux).

**Host configs** set identity (`home.username`, `home.homeDirectory`, `home.stateVersion`, `programs.git.settings.user.*`) with `lib.mkDefault` so a host module can override the shared defaults. The work host additionally sources its own zsh env/aliases and configures `aichat`.

## Key Conventions

### Nix

- All packages and plugins come from nixpkgs — no external plugin managers (no lazy.nvim, no Mason).
- Unfree packages are allowed via a single allowlist in `home/unfree.nix` (currently `openweb-ui`, `claude-code`, `github-copilot-cli`), read by the `allowUnfreePredicate` in `pkgsFor` (`flake.nix`). Add new unfree package names there when needed.
- Format Nix with `nixfmt` (included in the flake's package set).
- Host configs override shared settings using `lib.mkForce` where needed.
- `home.stateVersion` is set per-host for independent upgrade control.
- Use the modern `programs.git.settings.user.name` / `programs.git.settings.user.email` options (not the deprecated `userName`/`userEmail`).

### Neovim

- **No plugin manager.** Plugins are declared in `vim/default.nix` under `programs.neovim.plugins` and loaded eagerly.
- Each plugin is configured in its own file under `vim/lua/plugins/`. Load order is explicit in `plugins/init.lua`.
- **LSP uses `vim.lsp.config` / `vim.lsp.enable`** (Neovim 0.11+ API). Do NOT use `require("lspconfig").server.setup{}`.
- **Treesitter parsers** are sourced from `nvim-treesitter.passthru.builtGrammars` (not `pkgs.tree-sitter-grammars`) to avoid query/parser version drift. Parsers are symlinked into `~/.config/nvim/parser/`.
- **Treesitter highlighting** is started per-buffer via `vim.treesitter.start()` in an autocmd — `require("nvim-treesitter.configs").setup{}` does not exist on the main branch rewrite. See `home/vim/README.md` for the full treesitter parser/query wiring gotchas on current nixpkgs.
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

