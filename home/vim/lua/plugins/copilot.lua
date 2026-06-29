-- GitHub Copilot inline completion (ghost text). Gated per host via
-- vim.g.copilot_enabled (set from the nix `custom.copilot.enable` option).
-- Auth is out-of-band: run `:Copilot auth` once per machine to log in with
-- your subscription. nvim-cmp keeps `<Tab>`; Copilot accepts on `<C-l>`.
if not vim.g.copilot_enabled then
  return
end

require("copilot").setup({
  copilot_node_command = vim.g.copilot_node_command or "node",
  panel = { enabled = false },
  suggestion = {
    enabled = true,
    auto_trigger = true,
    keymap = {
      accept = "<C-l>",
      next = "<C-j>",
      prev = "<C-k>",
      dismiss = "<C-h>",
    },
  },
  filetypes = {
    markdown = true,
    gitcommit = true,
  },
})
