-- Inline markdown rendering (render-markdown.nvim)
require("render-markdown").setup({
  enabled = false, -- start disabled, toggle with keymap
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(ev)
    vim.keymap.set("n", "<leader>mp", "<cmd>RenderMarkdown toggle<cr>", {
      buffer = ev.buf,
      desc = "Toggle markdown rendering",
    })
  end,
})
