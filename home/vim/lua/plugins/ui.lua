-- Colored frame around the focused split. Draws colored borders on the
-- separators between the active window and its neighbors.
require("colorful-winsep").setup({
  border    = "rounded",
  highlight = "#fabd2f", -- gruvbox bright yellow
  excluded_ft = {
    "TelescopePrompt",
    "lazy",
    "mason",
  },
})

-- Statusline — explicit gruvbox theme so the bar uses warm tones regardless
-- of the (VS Code Dark Modern) syntax colors loaded above.
require("lualine").setup({
  options = {
    theme = "gruvbox",
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
    lualine_y = { "lsp_status" },
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
    color = "#3c3836", -- gruvbox bg1
    blend = 100,
    hide_if_all_visible = true,
  },
  marks = {
    Search    = { color = "#CCA700" }, -- editorWarning / find match
    Error     = { color = "#F14C4C" }, -- editorError
    Warn      = { color = "#CCA700" }, -- editorWarning
    Info      = { color = "#3794FF" }, -- editorInfo
    Hint      = { color = "#B5CEA8" }, -- numbers / hint green
    Misc      = { color = "#C586C0" }, -- keyword violet
    GitAdd    = { color = "#81B88B" }, -- gitDecoration.addedResource
    GitChange = { color = "#E2C08D" }, -- gitDecoration.modifiedResource
    GitDelete = { color = "#F48771" }, -- gitDecoration.deletedResource
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
