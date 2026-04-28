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

  -- Catppuccin Macchiato palette
  local gray_bg         = "#363a4f" -- surface0
  local gray_fg         = "#6e738d" -- overlay0
  local red_bg          = "#4a2030" -- dim red wash
  local red_bg_strong   = "#6e2a3a" -- stronger red wash
  local green_bg        = "#2c4a3a" -- dim green wash
  local green_bg_strong = "#3f6a4a" -- stronger green wash

  vim.api.nvim_set_hl(0, "DiffAdd",    { bg = green_bg })
  vim.api.nvim_set_hl(0, "DiffDelete", { bg = red_bg })
  vim.api.nvim_set_hl(0, "DiffChange", { bg = gray_bg })
  vim.api.nvim_set_hl(0, "DiffText",   { bg = red_bg_strong, bold = true })

  vim.api.nvim_set_hl(0, "DiffviewDiffAddAsDelete", { bg = red_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffAdd",         { bg = green_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffDelete",      { fg = gray_fg, bg = gray_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffDeleteDim",   { fg = gray_fg, bg = gray_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffChange",      { bg = gray_bg })
  vim.api.nvim_set_hl(0, "DiffviewDiffText",        { bg = green_bg_strong, bold = true })
  vim.api.nvim_set_hl(0, "DiffviewDiffTextDelete",  { bg = red_bg_strong, bold = true })
end

vim.api.nvim_create_autocmd({ "ColorScheme", "VimEnter" }, {
  group = diff_group,
  callback = set_diff_highlights,
})

set_diff_highlights()
