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
- **Theme** is Catppuccin Macchiato with token overrides in
  [lua/plugins/colorscheme.lua](lua/plugins/colorscheme.lua).

## Activation

```sh
git add -A home/vim          # flakes ignore untracked files!
home-manager switch --flake "git+file://$PWD?submodules=1#work"
```

`programs.neovim` is single-instance per user under home-manager; switching
between this config and the LazyVim-based `home/vim/` is done by changing
the import in `home/common.nix`.
