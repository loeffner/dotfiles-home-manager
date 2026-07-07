# vim — Notes

A from-scratch Neovim config managed via home-manager. No plugin manager;
plugins come from `pkgs.vimPlugins`. Activated by importing `./vim` from
`home/common.nix`.

## Treesitter wiring on current nixpkgs (gotcha)

The `nvim-treesitter` shipped in current nixpkgs is the **main-branch
rewrite**. It behaves very differently from the legacy version that LazyVim
and most online docs assume.

What the plugin derivation contains:

```
$out/
├── lua/                   ← runtime Lua modules
├── plugin/
└── runtime/
    └── queries/<lang>/   ← highlights.scm, indents.scm, etc.
```

Two things are missing or in unexpected places:

1. **No compiled parsers.** `pkgs.vimPlugins.nvim-treesitter.withPlugins`
   does **not** produce `<lang>.so` files. The `parser/` directory is empty.
2. **Queries are nested under `runtime/`.** Neovim only searches
   `<plugin>/queries/` on the runtimepath, not `<plugin>/runtime/queries/`.

Result on a fresh setup: `:lua vim.treesitter.start(0, "cpp")` succeeds
silently, the parser attaches, but `:Inspect` shows no captures because no
`highlights.scm` is found anywhere.

### Parser / query version mismatches

This *was* a problem when parsers came from `pkgs.tree-sitter-grammars`
(versioned independently of nvim-treesitter), but it's avoided in the
current setup by sourcing parsers from
`vimPlugins.nvim-treesitter.passthru.builtGrammars` — see the section
above. Documented here for posterity in case the strategy changes.

The symptom was a runtime error from the highlighter, e.g.:

```
Query error … Invalid field name "operator":
  operator: _ @operator)
```

…meaning a query referenced a grammar field the bundled parser didn't
expose. Surgical alternatives if it ever resurfaces:

- Override an individual query from Lua via
  `vim.treesitter.query.set("<lang>", "highlights", "...")`.
- Patch the queries directory at build time with `pkgs.runCommand` + `sed`.

### Fix (see [default.nix](default.nix))

```nix
# 1. Compiled parsers come from nvim-treesitter's OWN pinned grammars
#    (`passthru.builtGrammars`). Each is a derivation with a single
#    `$out/parser` ELF that we rename to `<lang>.so`.
xdg.configFile."nvim/parser".source =
  let
    tsParsers = with pkgs.vimPlugins.nvim-treesitter.passthru.builtGrammars; [
      { name = "cpp";    drv = cpp; }
      { name = "lua";    drv = lua; }
      # ...
    ];
  in
  pkgs.runCommand "nvim-ts-parsers" {} ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n"
      (p: "ln -s ${p.drv}/parser $out/${p.name}.so") tsParsers}
  '';

# 2. Bridge the queries path mismatch.
xdg.configFile."nvim/queries".source =
  "${pkgs.vimPlugins.nvim-treesitter}/runtime/queries";
```

Why `builtGrammars` and not `pkgs.tree-sitter.withPlugins`? Because
`pkgs.tree-sitter-grammars.*` are versioned independently of nvim-treesitter,
so the queries (newer) and grammars (older) can drift apart and crash the
highlighter with `Query error … Invalid field name "<field>"`. The
grammars under `nvim-treesitter.passthru.builtGrammars` are pinned to the
exact upstream revisions referenced by the queries, so the two are
guaranteed to be compatible.

Highlighting itself is started per-buffer in
[lua/config/autocmds.lua](lua/config/autocmds.lua) via a `FileType` autocmd
calling `vim.treesitter.start(buf, lang)` — `require("nvim-treesitter.configs").setup{}`
is **gone** on the main branch and must not be called.

Filetype aliases for C++ headers are registered in
[lua/plugins/treesitter.lua](lua/plugins/treesitter.lua):

```lua
vim.treesitter.language.register("cpp", { "cpp", "hpp", "hxx", "hh", "ipp" })
```

## Diagnostics cheat sheet

If syntax highlighting looks broken, check in this order:

```vim
:lua =vim.api.nvim_get_runtime_file('parser/cpp.so', false)
" → must return ".../nvim/parser/cpp.so"; if empty, parser symlink is broken.

:lua =vim.api.nvim_get_runtime_file('queries/cpp/highlights.scm', true)
" → must return at least one path; if empty, queries are not on runtimepath.

:lua =vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()]
" → must be a table; nil means treesitter never attached to this buffer.

:Inspect
" → must list @-prefixed captures (e.g. @function, @type) on tokens.
"   If only Semantic Tokens / Syntax show, the highlighter isn't active.
```

## Other notable design points

- **LSP** uses the modern `vim.lsp.config` / `vim.lsp.enable` API
  (Neovim 0.11+). `require("lspconfig")` is deprecated and not used; the
  `nvim-lspconfig` plugin is kept only to provide default `lsp/<server>.lua`
  configs (root markers, cmd, filetypes).
- **Clipboard** is OSC 52 so SSH from any terminal that supports it (e.g.
  Windows PowerShell with conhost or Windows Terminal) just works.
- **Diff highlights** override Diffview groups to be background-only so the
  Treesitter foreground colors stay intact in diff splits.
- **Sidebar explorer** is `neo-tree.nvim` — toggle with `<leader>e`
  (revealed at current file) or `<leader>E` (cwd).
- **Theme** is VS Code Dark Modern syntax on a Gruvbox dark background.
  See the [Theme](#theme) section below and
  [lua/plugins/colorscheme.lua](lua/plugins/colorscheme.lua).

## Theme

Hybrid scheme: **VS Code Dark Modern token colors** layered on **Gruvbox
dark surfaces**. The split is intentional — gruvbox tones for the
"chrome" (statusline, sidebar, panels) feel warm and easy on the eyes,
while VS Code's syntax palette gives strong, semantically-distinct hues
for code.

Implementation:

- Plugin: `vscode-nvim` (Mofiqul/vscode.nvim), loaded as `style = "dark"`.
- `color_overrides` swaps only the *background-family* palette entries
  (`vscBack`, `vscTabCurrent`, `vscLeftDark`, `vscPopupBack`, …) with
  gruvbox shades. Syntax token colors (`vscYellow`, `vscBlue`, `vscOrange`,
  `vscBlueGreen`, `vscPink`, `vscLightBlue`, …) are left untouched.
- `group_overrides` reinforces `Normal`/`NormalFloat`/`Pmenu`/`Telescope*`/
  `NeoTree*`/indent groups with explicit gruvbox `bg0`/`bg0_h`/`bg1`/`bg2`
  values so panels render as proper gruvbox surfaces.
- **Lualine** is pinned to `theme = "gruvbox"` regardless of which
  colorscheme is active ([lua/plugins/ui.lua](lua/plugins/ui.lua)).
- **Neo-tree** uses gruvbox accent colors: directories blue `#83a598`,
  root/opened files yellow `#fabd2f`, git added `#b8bb26`, modified
  `#fabd2f`, deleted `#fb4934`, untracked `#fe8019`, conflict bold red.
- **Telescope** prompt/preview title bars use gruvbox yellow / aqua.
- **Diff washes** ([lua/config/autocmds.lua](lua/config/autocmds.lua))
  use VS Code red `#4B1818`/`#6F1313` and green `#1B3D1B`/`#2C5A2C`
  backgrounds over gruvbox `bg1` for unchanged context.
- **nvim-notify** background → gruvbox `bg0` (`#282828`).
- **Scrollbar marks** ([lua/plugins/ui.lua](lua/plugins/ui.lua)) use VS
  Code accent colors (errors `#F14C4C`, warn `#CCA700`, info `#3794FF`,
  hint `#B5CEA8`, git add/change/delete `#81B88B`/`#E2C08D`/`#F48771`).

Gruvbox palette in use (background family):

| token   | hex       | usage                                    |
| ------- | --------- | ---------------------------------------- |
| `bg0_h` | `#1d2021` | sidebar / popups / inactive tabs         |
| `bg0`   | `#282828` | editor background                        |
| `bg0_s` | `#32302f` | folds / clangd inactive regions          |
| `bg1`   | `#3c3836` | statusline / cursorline                  |
| `bg2`   | `#504945` | pmenu selection / scrollbar thumb        |
| `bg3`   | `#665c54` | indent guide scope                       |
| `bg4`   | `#7c6f64` | line numbers                             |
| `fg`    | `#ebdbb2` | default foreground (gruvbox fg1)         |
| `gray`  | `#928374` | inactive statusline / gutter             |

VS Code Dark Modern syntax tokens that survive (key examples):

| group                    | hex       | role                          |
| ------------------------ | --------- | ----------------------------- |
| `vscYellow` `#DCDCAA`    | functions / methods           |          |
| `vscBlueGreen` `#4EC9B0` | types / constructors / namespaces |      |
| `vscBlue` `#569CD6`      | declarative keywords / type qualifiers |  |
| `vscPink` `#C586C0`      | control flow (return/import/cond.)     |  |
| `vscOrange` `#CE9178`    | strings                                 | |
| `vscLightGreen` `#B5CEA8`| numbers / hint diagnostics              | |
| `vscLightBlue` `#9CDCFE` | variables / properties / fields         | |
| (override) `#a8a8a8`     | comments (italic, light grey)           | |

## Source-control workflow (VS Code-style)

The closest analogue to VS Code's Source Control sidebar is **Diffview**,
not the file tree. `<leader>gd` opens it: the panel on the left splits
modified files into **Changes** (unstaged) and **Staged changes** sections
(working tree vs index), and the main area shows the diff for the currently
selected entry. Edit directly in the right pane — saving the working-tree
buffer updates the diff live.

Inside the Diffview file panel:

| key      | action                                        |
| -------- | --------------------------------------------- |
| `j` / `k`| move between changed files                    |
| `<cr>`   | open diff for the selected file               |
| `s`/`-`  | stage / unstage the selected file             |
| `S`      | stage all files                               |
| `U`      | unstage all files                             |
| `X`      | restore (discard) the file                    |
| `q`      | close Diffview (`<leader>gx` also works)      |

Inside a diff buffer: `]c` / `[c` jump between hunks, `do` / `dp` pull/push
the change across the split.

If you prefer the **neo-tree** flavour, `<leader>gE` toggles the `git_status`
source as a left-side sidebar. `<cr>` on a file there opens a Diffview for
that file (custom `diff_node` command in
[lua/plugins/explorer.lua](lua/plugins/explorer.lua)); `o` opens the plain
file instead.

Other related bindings (see [lua/plugins/git.lua](lua/plugins/git.lua)):

| binding          | action                                       |
| ---------------- | -------------------------------------------- |
| `<leader>gd`     | Diffview SCM panel (working tree vs index)   |
| `<leader>gx`     | close Diffview                               |
| `<leader>gf`     | file history of the current buffer           |
| `<leader>gr`     | diff current buffer against an arbitrary ref |
| `<leader>gS`     | diff whole tree against a branch (prompt)    |
| `<leader>gE`     | neo-tree `git_status` sidebar                |
| `<leader>gw`     | toggle ignoring whitespace changes in diffs  |
| `<leader>gB`     | set Gitsigns inline base ref                 |
| `]h` / `[h`      | next / previous hunk in current buffer       |
| `<leader>ghs`    | stage / unstage hunk (toggle; also visual)   |
| `<leader>ghr`    | reset (discard) hunk (also visual)           |
| `<leader>ghp`    | preview hunk                                 |
| `<leader>ghb`    | blame line                                   |
| `<leader>ghB`    | toggle inline blame                          |
| `<leader>ghd`    | toggle full inline diff                      |
| `]x` / `[x`      | next / previous conflict (git-conflict)      |
| `<leader>gco/gct`| conflict: choose ours / theirs               |
| `<leader>gcb/gcn`| conflict: choose both / none                 |

The `<leader>gh*` hunk keys are identical inside Diffview windows (they act on
the working-tree pane via Gitsigns), so staging works the same everywhere.

## Debugging (nvim-dap)

The backend is GDB itself (`gdb --interpreter=dap`), reused by every native
(C/C++/Rust) configuration. Keys live under `<leader>d` (see
[lua/plugins/dap.lua](lua/plugins/dap.lua)); F5–F9 do the usual step/continue.
Three built-in configs are always available (launch, launch-with-args, attach).

**Per-project launch configs.** On `<leader>dc` / F5, nvim-dap reads a project
`launch.json`. This config prefers **`.nvim/launch.json`** over
`.vscode/launch.json`, so a repo whose VS Code config uses an incompatible
adapter type (`cppdbg`, `lldb`, …) can ship an nvim-native one without touching
its `.vscode/` setup:

```jsonc
// .nvim/launch.json
{
  "version": "0.2.0",
  "configurations": [
    { "name": "Debug app", "type": "gdb", "request": "launch",
      "program": "${workspaceFolder}/build/app", "cwd": "${workspaceFolder}" }
  ]
}
```

If `.nvim/launch.json` is absent it falls back to `.vscode/launch.json`. As a
convenience the VS Code C/C++ adapter types (`cppdbg`/`lldb`/`codelldb`) are
aliased onto the `gdb` adapter, so an existing `.vscode/launch.json` is often
launchable directly — only the shared `program`/`args`/`cwd` fields carry over;
adapter-specific keys (`MIMode`, `miDebuggerPath`, `setupCommands`, …) are
ignored. Edits to either file take effect on the next run; no reload needed.

## Activation

```sh
git add -A home/vim          # flakes ignore untracked files!
home-manager switch --flake "git+file://$HOME/dotfiles#work"
```

`programs.neovim` is single-instance per user under home-manager; the vim
module is imported from `home/common.nix`.

## Copilot inline completion

GitHub Copilot ghost-text completion is gated per host by the
`custom.copilot.enable` option (default off; on for work). It powers
inline suggestions only — nvim-cmp keeps `<Tab>`, Copilot uses:

| Key     | action            |
| ------- | ----------------- |
| `<C-l>` | accept suggestion |
| `<C-j>` | next suggestion   |
| `<C-k>` | previous          |
| `<C-h>` | dismiss           |

Auth is out-of-band — run once per machine after switching:

```sh
nvim, then :Copilot auth   # log in with your Copilot subscription
```

Personal hosts have no inline LLM completion (claude.ai subscriptions can't
drive FIM); Claude Code remains the agent/chat tool there.
