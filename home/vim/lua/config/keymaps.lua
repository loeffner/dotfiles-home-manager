-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Toggle scroll-/cursor-binding across all windows in the current tab
vim.keymap.set("n", "<leader>wb", function()
  local on = vim.wo.scrollbind
  vim.cmd("windo set " .. (on and "noscrollbind nocursorbind" or "scrollbind cursorbind"))
end, { desc = "Toggle scroll/cursor bind across windows" })

vim.keymap.set("n", "<leader>gD", function()
  vim.ui.input({ prompt = "Gitsigns base ref: ", default = "main" }, function(ref)
    if ref and ref ~= "" then
      require("gitsigns").change_base(ref, true)
    end
  end)
end, { desc = "Gitsigns: change base ref" })

-- Toggle a persistent in-buffer view of all hunks (line highlight + deleted lines + word diff)
vim.keymap.set("n", "<leader>ghv", function()
  local gs = require("gitsigns")
  gs.toggle_linehl()
  gs.toggle_deleted()
  gs.toggle_word_diff()
end, { desc = "Toggle full inline diff view" })

-- Open a real diff split (vim's :diffthis) of buffer vs base
vim.keymap.set("n", "<leader>ghV", "<cmd>Gitsigns diffthis<cr>", { desc = "Diff split: buffer vs base" })
