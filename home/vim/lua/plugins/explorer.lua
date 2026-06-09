-- neo-tree.nvim: sidebar file explorer.
-- Toggle with <leader>e (reveal current file) or <leader>E (cwd root).

-- Disable netrw so neo-tree owns directory buffers.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Custom command: open the node under cursor in Diffview against the index
-- (i.e. show working-tree changes), VS Code "click a file in SCM" style.
local function diff_node(state)
  local node = state.tree:get_node()
  if not node or node.type ~= "file" then return end
  local git_root = vim.fn.systemlist({ "git", "-C", vim.fn.fnamemodify(node.path, ":h"),
                                       "rev-parse", "--show-toplevel" })[1]
  if vim.v.shell_error ~= 0 or not git_root or git_root == "" then
    vim.notify("Not inside a git repository", vim.log.levels.WARN)
    return
  end
  local rel = vim.fs.relpath(git_root, node.path) or node.path
  vim.cmd("DiffviewOpen -- " .. vim.fn.fnameescape(rel))
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

-- Diff against a specific ref (prompt).
map("n", "<leader>gS", function()
  vim.ui.input({ prompt = "Diff against ref: ", default = "master" }, function(ref)
    if ref and ref ~= "" then vim.cmd("DiffviewOpen " .. vim.fn.fnameescape(ref)) end
  end)
end, { desc = "Diff vs branch (prompt)" })
