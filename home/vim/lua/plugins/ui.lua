-- Statusline
require("lualine").setup({
  options = {
    theme = "catppuccin",
    icons_enabled = true,
    globalstatus = true,
    section_separators = "",
    component_separators = "",
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff", "diagnostics" },
    lualine_c = { { "filename", path = 1 } },
    lualine_x = { "filetype" },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})

-- Indent guides
require("ibl").setup({
  indent = { char = "│" },
  scope = { enabled = false },
})

-- TODO comments highlighting + search
require("todo-comments").setup({
  signs = false,
})

-- Scrollbar — gitsigns marks + search-result marks. Default behavior, no
-- custom line-number overlay.
local scrollbar = require("scrollbar")
scrollbar.setup({
  show = true,
  set_highlights = true,
  handle = {
    text = " ",
    color = "#494d64", -- surface1
    hide_if_all_visible = true,
  },
  marks = {
    Search    = { color = "#eed49f" }, -- yellow
    Error     = { color = "#ed8796" }, -- red
    Warn      = { color = "#f5a97f" }, -- peach
    Info      = { color = "#8aadf4" }, -- blue
    Hint      = { color = "#8bd5ca" }, -- teal
    Misc      = { color = "#c6a0f6" }, -- mauve
    GitAdd    = { color = "#a6da95" }, -- green
    GitChange = { color = "#eed49f" }, -- yellow
    GitDelete = { color = "#ed8796" }, -- red
  },
  excluded_buftypes = { "terminal" },
  excluded_filetypes = {
    "prompt", "TelescopePrompt", "neo-tree", "dashboard", "lazy", "noice", "notify",
  },
  handlers = {
    cursor     = true,
    diagnostic = true,
    gitsigns   = true,
    handle     = true,
    search     = true,
  },
})

-- Search-result marks require this companion plugin to feed scrollbar the
-- match positions; it ships as part of `nvim-scrollbar` itself.
pcall(function()
  require("scrollbar.handlers.search").setup({})
end)

-- hlslens: shows "[1/12]" virtual text next to the current search match
-- and integrates with nvim-scrollbar's search handler above so every match
-- gets a tick in the scrollbar gutter.
require("hlslens").setup({
  build_position_cb = function(plist, _, _, _)
    require("scrollbar.handlers.search").handler.show(plist.start_pos)
  end,
})

local function lens_map(lhs, cmd)
  vim.keymap.set("n", lhs, cmd, { silent = true, noremap = true })
end
lens_map("n",  [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]])
lens_map("N",  [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]])
lens_map("*",  [[*<Cmd>lua require('hlslens').start()<CR>]])
lens_map("#",  [[#<Cmd>lua require('hlslens').start()<CR>]])
lens_map("g*", [[g*<Cmd>lua require('hlslens').start()<CR>]])
lens_map("g#", [[g#<Cmd>lua require('hlslens').start()<CR>]])

-- Clear hlslens overlay when clearing search highlight.
vim.keymap.set("n", "<Esc>", function()
  vim.cmd("noh")
  pcall(function() require("hlslens").stop() end)
end, { silent = true, desc = "Clear search highlight" })
