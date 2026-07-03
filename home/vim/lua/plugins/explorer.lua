-- neo-tree.nvim: sidebar file explorer.
-- Toggle with <leader>e (reveal current file) or <leader>E (cwd root).

-- Disable netrw so neo-tree owns directory buffers.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Custom command: open the node under cursor and show its working-tree changes
-- as a fugitive vertical diff against the index (VS Code "click a file in SCM"
-- style).
local function diff_node(state)
  local node = state.tree:get_node()
  if not node or node.type ~= "file" then return end
  vim.cmd("edit " .. vim.fn.fnameescape(node.path))
  vim.cmd("Gvdiffsplit")
end

require("neo-tree").setup({
  close_if_last_window = true,
  popup_border_style = "rounded",
  enable_git_status = true,
  enable_diagnostics = true,
  commands = {
    diff_node = diff_node,
  },
  default_component_configs = {
    indent = {
      with_markers   = true,
      with_expanders = true,
    },
    git_status = {
      symbols = {
        added     = "✚",
        modified  = "",
        deleted   = "✖",
        renamed   = "",
        untracked = "",
        ignored   = "",
        unstaged  = "",
        staged    = "",
        conflict  = "",
      },
    },
  },
  window = {
    position = "left",
    width = 32,
    mappings = {
    },
  },
  filesystem = {
    follow_current_file    = { enabled = true },
    use_libuv_file_watcher = true,
    filtered_items = {
      visible         = false,
      hide_dotfiles   = false,
      hide_gitignored = true,
      hide_by_name    = { ".git", ".direnv" },
    },
  },
  buffers = {
    follow_current_file = { enabled = true },
  },
  git_status = {
    window = {
      position = "left",
      mappings = {
        ["<cr>"] = "diff_node", -- VS Code SCM-style: enter on a file → open diff
        ["o"]    = "open",      -- still allow opening the plain file
        ["d"]    = "diff_node",
      },
    },
  },
})

local map = vim.keymap.set

map("n", "<leader>e", function()
  require("neo-tree.command").execute({
    toggle = true,
    dir    = vim.fn.expand("%:p:h"),
    reveal = true,
  })
end, { desc = "Explorer (file dir)" })

map("n", "<leader>E", function()
  require("neo-tree.command").execute({
    toggle = true,
    dir    = vim.uv.cwd(),
  })
end, { desc = "Explorer (cwd)" })

map("n", "<leader>fe", function()
  require("neo-tree.command").execute({ source = "filesystem", toggle = true })
end, { desc = "Explorer: files" })
map("n", "<leader>gE", function()
  require("neo-tree.command").execute({ source = "git_status", toggle = true })
end, { desc = "Explorer: git status" })

-- Diff the whole tree against a specific ref (loads changed files into the
-- quickfix via fugitive's difftool).
map("n", "<leader>gS", function()
  vim.ui.input({ prompt = "Diff against ref: ", default = "master" }, function(ref)
    if ref and ref ~= "" then vim.cmd("Git difftool " .. vim.fn.fnameescape(ref)) end
  end)
end, { desc = "Diff vs branch (prompt)" })
