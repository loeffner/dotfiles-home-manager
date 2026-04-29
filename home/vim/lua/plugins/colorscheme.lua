-- Catppuccin Macchiato — softer than Mocha, warmer than Frappe.
-- See https://catppuccin.com for the full palette.
require("catppuccin").setup({
	flavour = "macchiato",
	background = { dark = "macchiato" },
	transparent_background = false,
	term_colors = true,
	styles = {
		comments = { "italic" },
		conditionals = { "italic" },
		keywords = { "bold" },
		functions = { "bold" },
		types = {},
		operators = {},
	},
	integrations = {
		cmp = true,
		gitsigns = true,
		telescope = { enabled = true },
		treesitter = true,
		native_lsp = {
			enabled = true,
			underlines = {
				errors = { "undercurl" },
				hints = { "undercurl" },
				warnings = { "undercurl" },
				information = { "undercurl" },
			},
		},
		mini = { enabled = true },
		flash = true,
		indent_blankline = { enabled = true },
		which_key = true,
		diffview = true,
		illuminate = { enabled = false },
		notify = false,
		mason = false,
		neotree = false,
	},
	custom_highlights = function(C)
    return {
  -- variables
  ["@variable"]              = { fg = C.text },
  ["@variable.member"]       = { fg = C.blue },
  ["@variable.parameter"]    = { fg = C.maroon },

  -- properties / fields
  ["@property"]              = { fg = C.sky },
  ["@field"]                 = { fg = C.sky },

  -- functions
  ["@function"]              = { fg = C.yellow },
  ["@function.call"]         = { fg = C.yellow },
  ["@function.method"]       = { fg = C.yellow },
  ["@function.method.call"]  = { fg = C.yellow },
  ["@function.builtin"]      = { fg = C.peach },

  -- constructors
  ["@constructor"]           = { fg = C.flamingo },

  -- types
  ["@type"]                  = { fg = C.teal },
  ["@type.builtin"]          = { fg = C.green },
  ["@type.qualifier"]        = { fg = C.blue },

  -- constants / literals
  ["@constant"]              = { fg = C.peach },
  ["@constant.builtin"]      = { fg = C.peach },
  ["@string"]                = { fg = C.green },
  ["@string.escape"]         = { fg = C.pink },
  ["@number"]                = { fg = C.peach },
  ["@boolean"]               = { fg = C.peach },

  -- keywords
  ["@keyword"]               = { fg = C.mauve },
  ["@keyword.return"]        = { fg = C.mauve },
  ["@keyword.operator"]      = { fg = C.mauve },
  ["@keyword.import"]        = { fg = C.mauve },

  -- operators
  ["@operator"]              = { fg = C.sky },

  -- punctuation
  ["@punctuation.bracket"]   = { fg = C.overlay2 },
  ["@punctuation.delimiter"] = { fg = C.overlay2 },

  -- namespaces/modules
  ["@namespace"]             = { fg = C.blue },
  ["@module"]                = { fg = C.blue },

  -- comments
  ["@comment"]               = { fg = C.overlay1 },
}
	end,
})

vim.o.background = "dark"
vim.cmd.colorscheme("catppuccin")
