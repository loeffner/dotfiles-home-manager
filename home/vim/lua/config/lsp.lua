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
  -- Opt into clangd's `textDocument/inactiveRegions` extension. clangd uses
  -- this to publish #ifdef-disabled ranges separately from semantic tokens,
  -- so we can dim them without losing Treesitter syntax colors. The handler
  -- is registered below.
  capabilities = vim.tbl_deep_extend("force", capabilities, {
    textDocument = {
      inactiveRegionsCapabilities = { inactiveRegions = true },
    },
  }),
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

-- ---------------------------------------------------------------------------
-- clangd inactive-region decoration.
--
-- clangd >= 17 emits `textDocument/inactiveRegions` notifications listing
-- the ranges of code disabled by #ifdef. We paint those ranges with extmarks
-- so they get a faint background tint while keeping their Treesitter
-- foreground colors. This avoids clangd's older behaviour of re-typing the
-- whole region as a `comment` semantic token (which clobbers all syntax
-- coloring).
-- ---------------------------------------------------------------------------
local inactive_ns = vim.api.nvim_create_namespace("clangd_inactive_regions")

-- Highlight group: bg-only so Treesitter fg shines through. Defined here
-- (not in colorscheme.lua) so it's also reapplied after :colorscheme reloads
-- via the autocmd below.
local function set_inactive_hl()
  vim.api.nvim_set_hl(0, "ClangdInactiveRegion", {
    bg = "#32302f", -- gruvbox bg0_h; subtle dim
    italic = true,
    default = true,
  })
end
set_inactive_hl()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("clangd_inactive_hl", { clear = true }),
  callback = set_inactive_hl,
})

vim.lsp.handlers["textDocument/inactiveRegions"] = function(_, result, ctx)
  if not result or not result.regions then return end
  local uri = result.textDocument and result.textDocument.uri
  if not uri then return end

  local bufnr = vim.uri_to_bufnr(uri)
  if not vim.api.nvim_buf_is_loaded(bufnr) then return end

  vim.api.nvim_buf_clear_namespace(bufnr, inactive_ns, 0, -1)

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for _, region in ipairs(result.regions) do
    local s_line = region.start.line
    local s_char = region.start.character
    local e_line = region["end"].line
    local e_char = region["end"].character
    if s_line < line_count then
      if e_line >= line_count then e_line = line_count - 1 end
      pcall(vim.api.nvim_buf_set_extmark, bufnr, inactive_ns, s_line, s_char, {
        end_row     = e_line,
        end_col     = e_char,
        hl_group    = "ClangdInactiveRegion",
        hl_eol      = true,
        priority    = 100, -- below Treesitter (which uses ~110+)
        strict      = false,
      })
    end
  end
end

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
