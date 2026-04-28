-- Modern vim.lsp.config / vim.lsp.enable API (Neovim 0.11+).
-- nvim-lspconfig stays on runtimepath only to provide default server
-- definitions under lsp/<name>.lua; we no longer call require("lspconfig").

local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Global defaults merged into every server config.
vim.lsp.config("*", {
  capabilities = capabilities,
})

-- Per-server overrides.
vim.lsp.config("clangd", {
  cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=iwyu" },
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      workspace = { checkThirdParty = false },
      diagnostics = { globals = { "vim" } },
      telemetry = { enable = false },
    },
  },
})

-- Enable (auto-start when a matching filetype opens).
vim.lsp.enable({ "clangd", "lua_ls", "nil_ls", "pyright" })

-- Buffer-local keymaps on attach.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true }),
  callback = function(args)
    local bufnr = args.buf
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    map("n", "gd", vim.lsp.buf.definition,      "Go to definition")
    map("n", "gD", vim.lsp.buf.declaration,     "Go to declaration")
    map("n", "gr", vim.lsp.buf.references,      "References")
    map("n", "gi", vim.lsp.buf.implementation,  "Implementation")
    map("n", "gy", vim.lsp.buf.type_definition, "Type definition")
    map("n", "K",  vim.lsp.buf.hover,           "Hover")
    map("n", "<leader>cr", vim.lsp.buf.rename,        "Rename symbol")
    map("n", "<leader>ca", vim.lsp.buf.code_action,   "Code action")
    map("v", "<leader>ca", vim.lsp.buf.code_action,   "Code action")
    map("n", "<leader>cs", vim.lsp.buf.signature_help,"Signature help")
  end,
})
