-- nvim-treesitter is on the "main" (rewrite) branch in current nixpkgs.
-- We do NOT call configs.setup{}; instead we register language aliases and
-- start the parser per-buffer (see config/autocmds.lua).
vim.treesitter.language.register("cpp", { "cpp", "hpp", "hxx", "hh", "ipp" })

-- Folding via treesitter when available.
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldenable = true

-- Treesitter textobjects (separate plugin, also on its main-branch API).
require("nvim-treesitter-textobjects").setup({ select = { lookahead = true } })

local select = require("nvim-treesitter-textobjects.select")
for lhs, query in pairs({
  af = "@function.outer",
  ["if"] = "@function.inner",
  ac = "@class.outer",
  ic = "@class.inner",
  aa = "@parameter.outer",
  ia = "@parameter.inner",
}) do
  vim.keymap.set({ "x", "o" }, lhs, function()
    select.select_textobject(query, "textobjects")
  end, { desc = "Select " .. query })
end
