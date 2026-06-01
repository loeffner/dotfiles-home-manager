-- mini.* modules: surround, pairs, comment, bufremove.
require("mini.surround").setup({
  mappings = {
    add = "gsa", delete = "gsd", find = "gsf", find_left = "gsF",
    highlight = "gsh", replace = "gsr", update_n_lines = "gsn",
  },
})
require("mini.pairs").setup()
require("mini.comment").setup()
require("mini.bufremove").setup()

-- Flash motion
require("flash").setup({
  modes = {
    search = { enabled = false },
    char = { enabled = false },
  },
})
vim.keymap.set({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash jump" })
vim.keymap.set({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash treesitter" })

-- which-key (key hint popup)
require("which-key").setup({ preset = "modern" })
require("which-key").add({
  { "<leader>b", group = "buffer" },
  { "<leader>c", group = "code" },
  { "<leader>f", group = "find" },
  { "<leader>g", group = "git" },
  { "<leader>w", group = "window" },
})
