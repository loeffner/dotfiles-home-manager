# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is a Nix flakes + home-manager dotfiles repository. It manages user
environments (shell, git, neovim, CLI tools) — not full NixOS systems.

## Commands

```sh
# Apply a configuration (standalone home-manager)
home-manager switch --flake .#beehive          # personal host (NixOS)
home-manager switch --flake .#ocean            # personal host (NixOS)
home-manager switch --flake .#terra            # personal host, Hyprland desktop (NixOS)
home-manager switch --flake .#island           # personal MacBook (macOS, aarch64-darwin)
home-manager switch --flake .#work-x86_64-linux
home-manager switch --flake .#work-aarch64-linux

# The `hms` zsh alias wraps this for the work setup, auto-picking the system
# from `uname -m`:   hms            -> work-<arch>-linux
#                    hms beehive    -> explicit target

# Build/evaluate without activating
nix build .#homeConfigurations.beehive.activationPackage
nix flake check

# Format Nix files (formatter used throughout)
nixfmt **/*.nix
```

There is no test suite. Validation = the config evaluates and builds
(`nix build` / `nix flake check`).

**Flake gotcha**: Nix flakes ignore untracked files. Any new file added to the
repo must be staged (`git add <file>`) before `nix build` or
`home-manager switch` will see it.

## Architecture

`flake.nix` is the single entry point and exposes one output set:

- **`homeConfigurations`** — standalone `homeManagerConfiguration`s applied
  with `home-manager switch --flake`. Each is built by `mkConfig`, which
  layers `common` + the host module. `work` is generated for every
  system in `workSystems` (x86_64-linux, aarch64-linux).

These are standalone configs only — there is no NixOS-integrated path. NixOS
hosts just install the `home-manager` CLI and apply these configs out-of-band.

The layering that every config goes through:

1. `home/common.nix` — the bulk of the environment: zsh (with keybindings and
   auto-`exec zellij`), oh-my-posh, fzf, atuin, zoxide (aliased to `cd`), eza,
   zellij, ssh/gpg agents. It `imports` `./git` and `./vim`.
2. `home/hosts/<host>` — per-machine identity (username, homeDirectory,
   stateVersion), git user/email, and host-specific extras. Identity fields
   use `lib.mkDefault` so a host module can override the shared defaults.

Host modules differ mainly in identity + extras: `beehive` and `island`
enable `claude-code` (unfree); `island` is the only macOS host
(`aarch64-darwin`, standalone home-manager — not nix-darwin) and sets
`homeDirectory` to `/Users/loeffner`. The shared `common.nix` services
(`ssh-agent`, `gpg-agent`) work on Darwin too — home-manager wires them via
`launchd.agents` there instead of systemd. `work` (a directory at
`home/hosts/work/default.nix`) adds copilot CLI, git signing + a
`~/.gitconfig.work` include, `umask 0027`, sources `.zsh-work-env` /
`.zsh-work-aliases`, points atuin at a network home, and configures `aichat`
against an internal Ollama endpoint. `terra` imports `home/desktop` for a
Hyprland desktop environment.

Unfree packages are gated by an `allowUnfreePredicate` allowlist set in
`pkgsFor` (flake.nix), which reads `home/unfree.nix`. To allow a new unfree
package, add its name there.

### Shell config

`home/.zsh-aliases` is the shared, host-agnostic alias/function file, sourced
from `common.nix`. Work-only shell bits live in
`home/hosts/work/.zsh-work-*`. zsh `initContent` is assembled with
`lib.mkBefore`/`mkAfter` ordering — e.g. the `exec zellij` guard must run last
(`mkAfter`), and work additions append with `mkAfter`.

### Desktop (`home/desktop`)

Imported by hosts that run the **niri** desktop (currently `terra`).
Contains: niri config (hand-written KDL, `niri.nix`), a Quickshell status bar
(hand-written QML, `quickshell/`), Wofi (app launcher, `wofi.nix`), Kitty
(terminal), cursor theme, and helper scripts (wallpaper daemon, clipboard
picker). All styled with Gruvbox dark.

The **Quickshell bar** (`home/desktop/quickshell/`) is a from-scratch QML config
deployed verbatim via `xdg.configFile."quickshell"` (recursive) and autostarted
from niri (`spawn-at-startup "qs"`). Components are flat `.qml` files referenced
by filename; `Theme.qml` (`pragma Singleton`) is the palette/metrics single
source of truth. Services used: `Pipewire` (audio), `Notifications`,
`Networking` (NetworkManager), `Mpris`, `SystemTray`, `SystemClock`; workspaces
come from `niri msg --json event-stream` via `Quickshell.Io.Process` (no niri
QML plugin). Quickshell live-reloads on QML edits.

Convention: use the home-manager module for an app where the module works well
(type-checked options, themes). Fall back to `xdg.configFile` with a
hand-written config only where the module is broken or limiting. Current
exceptions deployed verbatim via `xdg.configFile`: the niri KDL
(`niri/config.kdl`) and the Quickshell QML tree.

### Neovim (`home/vim`)

A from-scratch Neovim config with **no plugin manager**: plugins come from
`pkgs.vimPlugins` and load eagerly. `default.nix` declares plugins, LSP
servers, and formatters; the Lua tree under `home/vim/lua/` is symlinked to
`~/.config/nvim/lua/` and split into `config/` (options, keymaps, autocmds,
lsp) and `plugins/` (one file per plugin).

Treesitter wiring is the tricky part and is documented in detail in
`home/vim/README.md` — read it before touching parser/query handling. Summary:
current nixpkgs ships the main-branch nvim-treesitter rewrite, which ships
**no compiled parsers** and nests queries under `runtime/queries/`. So
`default.nix` symlinks parsers from
`nvim-treesitter.passthru.builtGrammars` (renaming each `parser` ELF to
`<lang>.so`) and bridges queries from `runtime/queries` into `queries`.
Sourcing parsers from `builtGrammars` (not `pkgs.tree-sitter`) keeps them
version-matched to the bundled queries. To add a language, add an entry to the
`tsParsers` list.
