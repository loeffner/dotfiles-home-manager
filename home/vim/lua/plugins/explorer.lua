-- neo-tree.nvim: sidebar file explorer.
-- Toggle with <leader>e (reveal current file) or <leader>E (cwd root).

-- Disable netrw so neo-tree owns directory buffers.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

require("neo-tree").setup({
  close_if_last_window = true,
  popup_border_style = "rounded",
  enable_git_status = true,
  enable_diagnostics = true,
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
      ["<space>"] = "none",
      ["<cr>"]    = "open",
      ["o"]       = "open",
      ["l"]       = "open",
      ["h"]       = "close_node",
      ["P"]       = { "toggle_preview", config = { use_float = true } },
      ["a"]       = { "add", config = { show_path = "relative" } },
      ["A"]       = "add_directory",
      ["d"]       = "delete",
      ["r"]       = "rename",
      ["y"]       = "copy_to_clipboard",
      ["x"]       = "cut_to_clipboard",
      ["p"]       = "paste_from_clipboard",
      ["q"]       = "close_window",
      ["?"]       = "show_help",
      ["<C-v>"]   = "open_vsplit",
      ["<C-x>"]   = "open_split",
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
    window = { position = "float" },
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
