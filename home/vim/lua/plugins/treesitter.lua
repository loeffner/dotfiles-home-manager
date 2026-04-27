return {
  {
    "nvim-treesitter/nvim-treesitter",
    -- LazyVim lists mason.nvim here to install the tree-sitter CLI.
    -- We provide it via Nix (programs.neovim.extraPackages), so drop the dep.
    dependencies = {},
    opts = {
      auto_install = false,
      ensure_installed = {},
    },
  },
}
