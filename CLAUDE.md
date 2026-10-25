# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is a Nix flakes + home-manager dotfiles repository. It manages user
environments (shell, git, neovim, CLI tools) — not full NixOS systems.

## Commands

```sh
# Apply a configuration (standalone home-manager)
home-manager switch --flake .#beehive          # personal host (NixOS)
home-manager switch --flake .#ocean            # personal host (NixOS)
home-manager switch --flake .#terra            # personal host, niri desktop (NixOS)
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
2. `home/hosts/<host>` — host-specific extras. The personal hosts (beehive,
   ocean, terra, island) share `home/personal.nix` for identity (username,
   homeDirectory, stateVersion — `lib.mkDefault`, so a host can override),
   git user/email and `claude-code` (unfree).

`island` is the only macOS host (`aarch64-darwin`, standalone home-manager —
not nix-darwin) and overrides `homeDirectory` to `/Users/loeffner`. The shared
`common.nix` services (`ssh-agent`, `gpg-agent`) work on Darwin too —
home-manager wires them via `launchd.agents` there instead of systemd. `work`
(a directory at `home/hosts/work/default.nix`) has its own identity and adds
copilot CLI, git signing + a `~/.gitconfig.work` include, `umask 0027`,
sources `.zsh-work-env` / `.zsh-work-aliases`, points atuin at a network home.
`terra` imports `home/desktop` for a niri desktop environment, and
`home/mail.nix` for mail.

### Mail (`home/mail.nix`, terra)

The Outlook.com account over IMAP with OAuth2 (Microsoft disabled password
logins): **oama** does the Microsoft login (Thunderbird's public client ID,
browser `authorize` endpoint) and keeps the refresh token in gnome-keyring;
**mbsync** (isync built with the cyrus-sasl XOAUTH2 plugin) syncs two-way into
`~/Maildir/outlook/` every 3 minutes via a systemd timer, then runs
`notmuch new`; **notmuch** is the index the Quickshell mail panel reads
(`shell/services/Mail.qml` + `shell/scripts/mail.sh`), and its post-new hook
sends a notification for new mail and calls `qs ipc call mail refresh`.
Sending and anything else the panel can't do goes to Outlook on the web (the
panel's open-in-browser button). One-time login after a fresh setup:
`oama authorize microsoft <address>`.

The keyring must be unlocked for oama, but greetd autologins (no password, so
PAM can't unlock it at login). Instead the startup swaylock does it: terra's
NixOS config needs `security.pam.services.swaylock.enableGnomeKeyring = true;`,
and the `login` keyring password must equal the user password.

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
Contains: niri config (hand-written KDL, split by concern across `niri/` —
`default.nix` assembles `settings.nix` + `binds.nix` into `config.kdl`, plus
`clipboard.nix` and the packaged helper scripts: shell-restart, run-or-raise,
clipboard-picker, the filtered cliphist store, swaylock-themed — the lock
wrapper that injects the bar's current accent), a Quickshell desktop shell
(hand-written QML, `shell/`), Wofi (app launcher, `wofi.nix`), Kitty
(terminal), swaylock (screen lock — Mod+Escape / control-center button / idle
timeout / before-sleep; carries `swaylock-auto-submit.patch` for unlocking
without pressing Enter; needs `security.pam.services.swaylock = { };` plus
`.nodelay = true` on the NixOS side, see `default.nix` — and
`.enableGnomeKeyring = true` so the startup lock unlocks the keyring for mail),
cursor theme, and the
swaybg wallpaper + swayidle autostarts. All styled with Gruvbox dark.

The **Quickshell shell** (`home/desktop/shell/`) is a from-scratch QML config
deployed verbatim via `xdg.configFile."quickshell"` (recursive, minus `dev/`) and
autostarted from niri (`spawn-at-startup "qs"`). **Read `shell/README.md` before
changing it** — layout (`config/ services/ components/ island/ panels/ bar/
overlays/ scripts/`, `qs.*` imports), house rules, external contracts, and the
`dev/` test harness (`dev/run <scene>` renders scenes against the real modules
with a throwaway HOME; `--old` runs them against the previous tree for
side-by-side checks). `config/palette.json` is the single colour source (Nix reads
it for swaylock-themed); popouts are panels hosted by one morphing "island"
window per screen; state persists under `~/.local/state/quickshell/`. The
previous tree `home/desktop/quickshell/` is no longer deployed and only kept for
`dev/run --old` comparisons until it's deleted. Quickshell live-reloads on QML
edits.

The **hold-Super cheatsheet** (`shell/overlays/KeybindSheet.qml`, state +
IPC in `shell/services/Cheatsheet.qml`) is a pictographic keybind overlay
shown while Super is held. niri can't bind on modifier-hold or key-release, so a
small read-only evdev watcher (`super-cheatsheet-watch.py`, python-evdev,
autostarted from niri, defined in `niri/settings.nix`) drives it over Quickshell IPC
(`qs ipc call cheatsheet open/close`). The watcher only *observes* Super, never
remaps it, so Super+X binds keep working, and it only opens devices it already has
access to (skipping the rest).

**Device access (NixOS-side, not this repo): a scoped `uaccess` udev rule — NOT the
`input` group.** The `input` group grants rw to *every* input device (including the
YubiKey's keystrokes and event injection) and is too broad. Instead, give only the
real keyboard a per-session ACL for the active local user via `uaccess`. On `terra`
that keyboard is the AKKO (USB `0c45:7638`); the YubiKey (`1050:0407`) is
deliberately left out. Add to terra's NixOS config a rule ordered before
`73-seat-late.rules`:

    services.udev.packages = [
      (pkgs.writeTextDir "etc/udev/rules.d/70-uaccess-akko-kbd.rules" ''
        ACTION=="remove", GOTO="akko_uaccess_end"
        SUBSYSTEM=="input", KERNEL=="event*", ATTRS{idVendor}=="0c45", ATTRS{idProduct}=="7638", TAG+="uaccess"
        LABEL="akko_uaccess_end"
      '')
    ];

Until that lands, the watcher backs off harmlessly and only the `Mod+/` tap toggle
works. (The gold-standard alternative is logind `TakeDevice` — a revocable fd, no
system change at all — but it needs real session/D-Bus handling in the watcher;
the scoped `uaccess` rule is the pragmatic secure choice.)

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
