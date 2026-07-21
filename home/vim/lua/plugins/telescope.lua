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

local last_grep_query = ""
local function live_grep_with_memory()
  builtin.live_grep({
    default_text = last_grep_query,
    attach_mappings = function(prompt_bufnr, _)
      local action_state = require("telescope.actions.state")
      vim.api.nvim_create_autocmd("BufLeave", {
        buffer = prompt_bufnr,
        once = true,
        callback = function()
          last_grep_query = action_state.get_current_line()
        end,
      })
      return true
    end,
  })
end

map("n", "<leader>ff", builtin.find_files,      { desc = "Find files" })
map("n", "<leader>fg", live_grep_with_memory,   { desc = "Live grep" })
map("n", "<leader>fb", builtin.buffers,     { desc = "Buffers" })
map("n", "<leader>fh", builtin.help_tags,   { desc = "Help tags" })
map("n", "<leader>fr", builtin.oldfiles,    { desc = "Recent files" })
map("n", "<leader>fs", builtin.lsp_document_symbols, { desc = "Document symbols" })
map("n", "<leader>fS", builtin.lsp_dynamic_workspace_symbols, { desc = "Workspace symbols" })
map("n", "<leader>fd", builtin.diagnostics, { desc = "Diagnostics" })
-- ctags-based lookups (reads the `.tags`/`tags` file set in options.lua).
-- Useful as a fallback/cross-check when clangd resolves gd to the wrong
-- candidate (e.g. in files outside compile_commands.json), since this shows
-- every tag match instead of silently picking one.
map("n", "<leader>ft", builtin.tags,        { desc = "Tags (project)" })
map("n", "<leader>/",  builtin.current_buffer_fuzzy_find, { desc = "Buffer search" })
