-- grug-far: interactive search & replace (buffer-wide and project-wide).
local grug = require("grug-far")

grug.setup({
  headerMaxWidth = 80,
})

local map = vim.keymap.set

map("n", "<leader>rr", function()
  grug.open()
end, { desc = "Replace project-wide" })

map("n", "<leader>rb", function()
  grug.open({ prefills = { paths = vim.fn.expand("%") } })
end, { desc = "Replace in buffer" })

map("n", "<leader>rw", function()
  grug.open({ prefills = { search = vim.fn.expand("<cword>") } })
end, { desc = "Replace word under cursor" })

map("v", "<leader>r", function()
  grug.with_visual_selection()
end, { desc = "Replace selection" })
