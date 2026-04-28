require("conform").setup({
  formatters_by_ft = {
    lua      = { "stylua" },
    nix      = { "nixfmt" },
    c        = { "clang_format" },
    cpp      = { "clang_format" },
    python   = { "ruff_format", "black", stop_after_first = true },
    json     = { "prettierd" },
    yaml     = { "prettierd" },
    markdown = { "prettierd" },
  },
})

vim.keymap.set({ "n", "v" }, "<leader>cf", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format" })
