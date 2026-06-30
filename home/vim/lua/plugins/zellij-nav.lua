-- Seamless navigation between Neovim splits and Zellij panes.
--
-- Pairs with the zellij-autolock plugin configured in home/common.nix: while
-- Neovim is the focused pane, Zellij switches to Locked mode so <A-h/j/k/l>
-- reach Neovim. These commands move between Neovim splits, and once at a split
-- edge they hand focus off to the adjacent Zellij pane (matching Zellij's own
-- default Alt+h/j/k/l focus movement when a non-editor pane is active).
require("zellij-nav").setup()

local map = vim.keymap.set
map("n", "<A-h>", "<cmd>ZellijNavigateLeftTab<cr>", { silent = true, desc = "Navigate left (split/pane)" })
map("n", "<A-j>", "<cmd>ZellijNavigateDown<cr>", { silent = true, desc = "Navigate down (split/pane)" })
map("n", "<A-k>", "<cmd>ZellijNavigateUp<cr>", { silent = true, desc = "Navigate up (split/pane)" })
map("n", "<A-l>", "<cmd>ZellijNavigateRightTab<cr>", { silent = true, desc = "Navigate right (split/pane)" })

-- Return Zellij to Normal mode when leaving Neovim, so the shell pane is
-- immediately navigable (snappier than waiting for autolock to react).
vim.api.nvim_create_autocmd("VimLeave", {
  pattern = "*",
  command = "silent !zellij action switch-mode normal",
})
