local telescope = require("telescope")

telescope.setup({
  defaults = {
    sorting_strategy = "ascending",
    layout_config = { prompt_position = "top" },
    mappings = {
      i = {
        ["<C-j>"] = "move_selection_next",
        ["<C-k>"] = "move_selection_previous",
      },
    },
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
    },
  },
})

pcall(telescope.load_extension, "fzf")

local builtin = require("telescope.builtin")
local map = vim.keymap.set
map("n", "<leader>ff", builtin.find_files,  { desc = "Find files" })
map("n", "<leader>fg", builtin.live_grep,   { desc = "Live grep" })
map("n", "<leader>fb", builtin.buffers,     { desc = "Buffers" })
map("n", "<leader>fh", builtin.help_tags,   { desc = "Help tags" })
map("n", "<leader>fr", builtin.oldfiles,    { desc = "Recent files" })
map("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Document symbols" })
map("n", "<leader>fS", builtin.lsp_dynamic_workspace_symbols, { desc = "Workspace symbols" })
map("n", "<leader>fd", builtin.diagnostics, { desc = "Diagnostics" })
map("n", "<leader>/",  builtin.current_buffer_fuzzy_find, { desc = "Buffer search" })
