-- noice.nvim — replaces the cmdline, messages and popupmenu with floating
-- windows. Depends on nui.nvim (already in plugins) and nvim-notify (used
-- as the message router).

require("notify").setup({
  background_colour = "#000000",
  render = "compact",
  stages = "fade",
  timeout = 2500,
})
vim.notify = require("notify")

require("noice").setup({
  cmdline = {
    enabled = true,
    view = "cmdline_popup",
    format = {
      cmdline     = { icon = ">" },
      search_down = { icon = "/" },
      search_up   = { icon = "?" },
      filter      = { icon = "$" },
      lua         = { icon = "" },
      help        = { icon = "?" },
    },
  },
  messages = {
    enabled = true,
    view              = "notify",
    view_error        = "notify",
    view_warn         = "notify",
    view_history      = "messages",
    view_search       = "virtualtext",
  },
  popupmenu = {
    enabled = true,
    backend = "nui",
  },
  lsp = {
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"]                = true,
      ["cmp.entry.get_documentation"]                  = true,
    },
    hover     = { enabled = true },
    signature = { enabled = true, auto_open = { enabled = true } },
    progress  = { enabled = true },
  },
  presets = {
    bottom_search        = false, -- search in floating cmdline too
    command_palette      = true,  -- cmdline + popupmenu stacked together
    long_message_to_split = true,
    inc_rename           = false,
    lsp_doc_border       = true,
  },
  routes = {
    -- Suppress "written" / "no lines in buffer" / search-count noise.
    {
      filter = {
        event = "msg_show",
        any = {
          { find = "%d+L, %d+B" },
          { find = "; after #%d+" },
          { find = "; before #%d+" },
        },
      },
      view = "mini",
    },
  },
})

local map = vim.keymap.set
map("n", "<leader>sn", function() require("noice").cmd("history") end, { desc = "Noice: message history" })
map("n", "<leader>sl", function() require("noice").cmd("last")    end, { desc = "Noice: last message" })
map("n", "<leader>sd", function() require("noice").cmd("dismiss") end, { desc = "Noice: dismiss" })
