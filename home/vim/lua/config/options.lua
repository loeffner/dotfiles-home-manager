local opt = vim.opt

-- Leader keys (must be set before plugins).
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Display
opt.number = true
opt.relativenumber = false
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.wrap = false
opt.termguicolors = true
opt.showmode = false
opt.laststatus = 3
opt.cmdheight = 1

-- Editing
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true
opt.breakindent = true
opt.undofile = true
opt.swapfile = false

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.inccommand = "split"

-- Splits
opt.splitright = true
opt.splitbelow = true

-- Mouse
opt.mouse = "a"

-- Filetype mappings
vim.filetype.add({
	extension = {
		hpp = "cpp",
		hxx = "cpp",
		hh = "cpp",
		ipp = "cpp",
	},
})

-- Clipboard: use system clipboard, with OSC 52 for SSH sessions.
opt.clipboard = "unnamedplus"

local osc52 = require("vim.ui.clipboard.osc52")
vim.g.clipboard = {
	name = "OSC 52",
	copy = {
		["+"] = osc52.copy("+"),
		["*"] = osc52.copy("*"),
	},
	paste = {
		["+"] = function() end,
		["*"] = function() end,
	},
}

-- Sensible diagnostic display.
vim.diagnostic.config({
	virtual_text = { prefix = "●" },
	severity_sort = true,
	float = { border = "rounded", source = true },
})
