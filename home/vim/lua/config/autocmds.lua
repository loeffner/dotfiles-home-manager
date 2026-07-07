local augroup = function(name)
  return vim.api.nvim_create_augroup("custom_" .. name, { clear = true })
end

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup("yank_highlight"),
  callback = function()
    vim.hl.on_yank({ timeout = 200 })
  end,
})

-- Auto-resize splits when window is resized
vim.api.nvim_create_autocmd("VimResized", {
  group = augroup("resize_splits"),
  command = "tabdo wincmd =",
})

-- Restore cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup("restore_cursor"),
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Trim trailing whitespace on save (everywhere except markdown)
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup("trim_whitespace"),
  callback = function()
    if vim.bo.filetype == "markdown" then return end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Force-attach Treesitter highlighting per buffer.
vim.api.nvim_create_autocmd("FileType", {
  group = augroup("treesitter_start"),
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
    if not lang then return end
    pcall(vim.treesitter.start, args.buf, lang)
  end,
})

-- Diff highlight overrides (Diffview-aware).
local diff_group = augroup("diff_highlights")

local function set_diff_highlights()
  vim.opt.fillchars:append({ diff = " " })

  -- VS Code Dark Modern diff washes on gruvbox neutral bgs.
  local gray_bg         = "#3c3836" -- gruvbox bg1
  local gray_fg         = "#928374" -- gruvbox gray
  local red_bg          = "#4B1818" -- diffEditor.removedTextBackground (dim)
  local red_bg_strong   = "#6F1313" -- removed text wash (stronger)
  local green_bg        = "#1B3D1B" -- diffEditor.insertedTextBackground (dim)
  local green_bg_strong = "#2C5A2C" -- inserted text wash (stronger)

  vim.api.nvim_set_hl(0, "DiffAdd",    { bg = green_bg })
  vim.api.nvim_set_hl(0, "DiffDelete", { bg = red_bg })
  vim.api.nvim_set_hl(0, "DiffChange", { bg = gray_bg })
  vim.api.nvim_set_hl(0, "DiffText",   { bg = red_bg_strong })

  vim.api.nvim_set_hl(0, "DiffviewDiffAddAsDelete", { bg = red_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffAdd",         { bg = green_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffDelete",      { fg = gray_fg, bg = gray_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffDeleteDim",   { fg = gray_fg, bg = gray_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffChange",      { bg = gray_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffText",        { bg = green_bg_strong })
  vim.api.nvim_set_hl(0, "DiffviewDiffTextDelete",  { bg = red_bg_strong })
end

vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = diff_group,
  callback = set_diff_highlights,
})

set_diff_highlights()

-- Highlight trailing whitespace. The highlight group is (re)defined on every
-- ColorScheme so it survives theme changes, and a per-window `matchadd`
-- applies the `\s\+$` pattern. Skip special buffers (no filetype / non-normal
-- buftype) so prompts, terminals and the like stay clean.
local trailing_group = augroup("trailing_whitespace")

vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = trailing_group,
  callback = function()
    vim.api.nvim_set_hl(0, "TrailingWhitespace", { bg = "#cc241d" }) -- gruvbox red
  end,
})
vim.api.nvim_set_hl(0, "TrailingWhitespace", { bg = "#cc241d" })

vim.api.nvim_create_autocmd({ "BufWinEnter", "WinNew" }, {
  group = trailing_group,
  callback = function()
    if vim.bo.buftype ~= "" then return end
    for _, m in ipairs(vim.fn.getmatches()) do
      if m.group == "TrailingWhitespace" then return end
    end
    vim.fn.matchadd("TrailingWhitespace", [[\s\+$]])
  end,
})

-- Colored frame around the focused split. Helps spot which pane has the
-- cursor when several windows are open. See plugins/ui.lua for the setup.
