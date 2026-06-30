local map = vim.keymap.set

-- Quality of life
map("i", "jk", "<Esc>", { desc = "Exit insert mode" })
map("n", "<Esc>", "<cmd>noh<cr>", { desc = "Clear search highlight" })
map({ "n", "v" }, "<leader>s", "<cmd>w<cr>", { desc = "Save" })
map("n", "<leader>q", function()
  local bufs = vim.tbl_filter(function(b)
    return vim.bo[b].buflisted
  end, vim.api.nvim_list_bufs())
  if #bufs > 1 then
    require("mini.bufremove").delete(0, false)
  else
    vim.cmd("confirm q")
  end
end, { desc = "Close buffer or quit" })
map("n", "<leader>Q", "<cmd>qa!<cr>", { desc = "Force quit all" })

-- Window/pane navigation lives in plugins/zellij-nav.lua: <A-h/j/k/l> move
-- between nvim splits and hand off to adjacent zellij panes at the edges.

-- Window splits (current buffer stays, opens alongside)
map("n", "<leader>|", "<cmd>vsplit<cr>", { desc = "Split window right" })
map("n", "<leader>-", "<cmd>split<cr>", { desc = "Split window below" })
map("n", "<leader>wd", "<C-w>c", { desc = "Close window" })

-- Buffers (navigation handled by bufferline plugin)
map("n", "<leader>bd", function()
  require("mini.bufremove").delete(0, false)
end, { desc = "Delete buffer" })

-- Move lines (Alt+Shift+j/k; plain Alt+j/k is split/pane navigation)
map("n", "<A-J>", "<cmd>m .+1<cr>==", { desc = "Move line down" })
map("n", "<A-K>", "<cmd>m .-2<cr>==", { desc = "Move line up" })
map("v", "<A-J>", ":m '>+1<cr>gv=gv", { desc = "Move selection down" })
map("v", "<A-K>", ":m '<-2<cr>gv=gv", { desc = "Move selection up" })

-- Stay in visual mode after indenting
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Center on half-page jumps
map("n", "<C-d>", "<C-d>zz")
map("n", "<C-u>", "<C-u>zz")
map("n", "n", "nzzzv")
map("n", "N", "Nzzzv")

-- Better paste over selection (don't yank replaced text)
map("v", "p", '"_dP')

-- Diagnostics
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Previous diagnostic" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Diagnostic float" })

-- Quickfix
map("n", "]q", "<cmd>cnext<cr>", { desc = "Next quickfix" })
map("n", "[q", "<cmd>cprev<cr>", { desc = "Previous quickfix" })

-- Clipboard
map("n", "<leader>yf", function()
  vim.fn.setreg("+", vim.fn.expand("%:p"))
end, { desc = "Yank file path" })

-- Toggles
map("n", "<leader>tw", function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = "Toggle line wrap" })

-- Toggle scroll/cursor bind across windows
map("n", "<leader>wb", function()
  local on = vim.wo.scrollbind
  vim.cmd("windo set " .. (on and "noscrollbind nocursorbind" or "scrollbind cursorbind"))
end, { desc = "Toggle scroll/cursor bind" })
