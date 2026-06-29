{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.custom.copilot.enable = lib.mkEnableOption "GitHub Copilot inline completion in Neovim";

  config = {
  # A from-scratch Neovim configuration.
  # No LazyVim, no lazy.nvim, no plugin manager.
  # Plugins come from nixpkgs and are loaded eagerly; each is configured
  # in its own lua file under ./lua/plugins/.
  #

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    withRuby = false;
    withPython3 = false;

    extraPackages = with pkgs; [
      # Build / parser tools
      tree-sitter
      gcc

      # Copilot inline completion runtime
      nodejs

      # Telescope deps
      ripgrep
      fd

      # LSP servers
      lua-language-server
      nil # Nix LSP
      clang-tools # clangd + clang-format
      pyright

      # Formatters
      stylua
      nixfmt
      black
      ruff
      prettierd
    ];

    plugins = with pkgs.vimPlugins; [
      # Colorscheme — VS Code Dark Modern syntax on a gruvbox background
      vscode-nvim

      # UI
      bufferline-nvim
      colorful-winsep-nvim
      lualine-nvim
      nvim-web-devicons
      nvim-scrollbar
      nvim-hlslens
      noice-nvim
      nvim-notify

      # Color codes
      nvim-colorizer-lua

      # Editor
      mini-nvim
      flash-nvim
      which-key-nvim
      rainbow-delimiters-nvim
      todo-comments-nvim
      indent-blankline-nvim
      grug-far-nvim

      # Treesitter
      nvim-treesitter
      nvim-treesitter-textobjects

      # Telescope
      plenary-nvim
      telescope-nvim
      telescope-fzf-native-nvim

      # Git
      gitsigns-nvim
      diffview-nvim

      # LSP + completion
      nvim-lspconfig
      nvim-cmp
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp_luasnip
      luasnip
      friendly-snippets

      # LLM autocompletion (inline ghost text; gated per host via copilot_enabled)
      copilot-lua

      # Format
      conform-nvim

      # Markdown
      render-markdown-nvim

      # File explorer (sidebar)
      neo-tree-nvim
      nui-nvim
    ];

    initLua = ''
      vim.g.copilot_enabled = ${if config.custom.copilot.enable then "true" else "false"}
      vim.g.copilot_node_command = "${pkgs.nodejs}/bin/node"
      require("config.options")
      require("config.keymaps")
      require("config.autocmds")
      require("plugins")
    '';
  };

  # Treesitter parsers — symlinked into runtimepath as ~/.config/nvim/parser/.
  #
  # Main-branch nvim-treesitter (the rewrite shipped in current nixpkgs) does
  # NOT compile parsers; its `withPlugins` output contains only queries under
  # `runtime/queries/`. So we source the compiled `<lang>.so` files from
  # `pkgs.tree-sitter.withPlugins` instead. Queries come from the
  # `nvim-treesitter` plugin already on runtimepath.
  # Treesitter parsers — sourced from nvim-treesitter's *own* pinned grammars
  # (`passthru.builtGrammars`). Using these (instead of `pkgs.tree-sitter`'s
  # independently-versioned grammars) guarantees the parsers match the
  # queries the plugin ships with — no `Invalid field name "operator"` style
  # crashes from version drift.
  #
  # Each `builtGrammars.<lang>` derivation has the layout:
  #   $out/parser           ← the compiled ELF (single file, not a dir)
  #   $out/queries/<lang>/  ← upstream queries (we ignore these; the plugin
  #                           ships a curated set under runtime/queries/)
  #
  # Neovim looks up `parser/<lang>.so` on the runtimepath, so we rename each
  # `parser` ELF to `<lang>.so` in a small derivation.
  xdg.configFile."nvim/parser".source =
    let
      tsParsers = with pkgs.vimPlugins.nvim-treesitter.passthru.builtGrammars; [
        {
          name = "bash";
          drv = bash;
        }
        {
          name = "c";
          drv = c;
        }
        {
          name = "cpp";
          drv = cpp;
        }
        {
          name = "lua";
          drv = lua;
        }
        {
          name = "nix";
          drv = nix;
        }
        {
          name = "python";
          drv = python;
        }
        {
          name = "markdown";
          drv = markdown;
        }
        {
          name = "markdown_inline";
          drv = markdown_inline;
        }
        {
          name = "vim";
          drv = vim;
        }
        {
          name = "vimdoc";
          drv = vimdoc;
        }
        {
          name = "yaml";
          drv = yaml;
        }
        {
          name = "json";
          drv = json;
        }
        {
          name = "toml";
          drv = toml;
        }
        {
          name = "cmake";
          drv = cmake;
        }
      ];
    in
    pkgs.runCommand "nvim-ts-parsers" { } ''
      mkdir -p $out
      ${lib.concatMapStringsSep "\n" (p: "ln -s ${p.drv}/parser $out/${p.name}.so") tsParsers}
    '';

  # Treesitter queries — main-branch nvim-treesitter ships them under
  # `<plugin>/runtime/queries/`, but Neovim only searches `<plugin>/queries/`.
  # Bridge that gap with a direct symlink.
  xdg.configFile."nvim/queries".source = "${pkgs.vimPlugins.nvim-treesitter}/runtime/queries";

  # Lua config tree.
  xdg.configFile."nvim/lua".source = ./lua;
  };
}
