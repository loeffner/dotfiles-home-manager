-- Gitsigns: gutter signs, hunk navigation, blame, partial staging.
require("gitsigns").setup({
  current_line_blame = true,
  current_line_blame_opts = { delay = 200 },
  signs = {
    add          = { text = "▎" },
    change       = { text = "▎" },
    delete       = { text = "" },
    topdelete    = { text = "" },
    changedelete = { text = "▎" },
    untracked    = { text = "▎" },
  },
  on_attach = function(buf)
    local gs = require("gitsigns")
    local function map(mode, l, r, desc)
      vim.keymap.set(mode, l, r, { buffer = buf, desc = desc })
    end

    map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
    map("n", "[h", function() gs.nav_hunk("prev") end, "Previous hunk")
    map("n", "<leader>ghs", gs.stage_hunk,        "Stage hunk")
    map("n", "<leader>ghr", gs.reset_hunk,        "Reset hunk")
    map("n", "<leader>ghp", gs.preview_hunk,      "Preview hunk")
    map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame line")
    map("n", "<leader>ghB", gs.toggle_current_line_blame, "Toggle inline blame")

    map("n", "<leader>ghv", function()
      gs.toggle_linehl()
      gs.toggle_deleted()
      gs.toggle_word_diff()
    end, "Toggle full inline diff view")

    map("n", "<leader>gD", function()
      vim.ui.input({ prompt = "Gitsigns base ref: ", default = "main" }, function(ref)
        if ref and ref ~= "" then gs.change_base(ref, true) end
      end)
    end, "Change base ref")
  end,
})

-- Diffview: side-aware diff with red/green per pane.
-- `<leader>gd` opens the working tree vs the index, giving VS Code-style
-- "Changes" (unstaged) and "Staged changes" sections in the file panel.
-- In the file panel: `s`/`-` toggle stage on a file, `S` stage all,
-- `U` unstage all, `X` discard. Hunk-level staging via `<leader>hs` in a
-- diff window, or by editing the index buffer directly.
local function gs() return require("gitsigns") end

require("diffview").setup({
  enhanced_diff_hl = true,
  view = {
    default = { layout = "diff2_horizontal" },
  },
  hooks = {
    -- Per-window diff tweaks. ctx.symbol is 'a' (left/old) or 'b' (right/new).
    -- Disable the automatic foldmethod=diff collapsing of unchanged regions,
    -- and remap the left pane so changes render as red removals (mirroring
    -- VS Code) instead of Diffview's symmetric green-on-both-sides default.
    diff_buf_win_enter = function(_, winid, ctx)
      vim.wo[winid].foldenable = false
      vim.wo[winid].foldlevel  = 99

      if ctx and ctx.symbol == "a" then
        vim.wo[winid].winhighlight = table.concat({
          "DiffAdd:DiffviewDiffAddAsDelete",
          "DiffDelete:DiffviewDiffDeleteDim",
          "DiffChange:DiffviewDiffAddAsDelete",
          "DiffText:DiffviewDiffTextDelete",
        }, ",")
      elseif ctx and ctx.symbol == "b" then
        vim.wo[winid].winhighlight = table.concat({
          "DiffDelete:DiffviewDiffDeleteDim",
          "DiffAdd:DiffviewDiffAdd",
          "DiffChange:DiffviewDiffAdd",
          "DiffText:DiffviewDiffText",
        }, ",")
      end
    end,
  },
  keymaps = {
    -- Hunk staging inside the diff windows themselves (the right pane is
    -- the actual working-tree buffer, so gitsigns is already attached).
    -- These shadow Diffview's defaults for those keys, but only inside
    -- Diffview windows — normal buffers are unaffected.
    view = {
      { "n", "<leader>hs", function() gs().stage_hunk()                      end, { desc = "Stage hunk"   } },
      { "n", "<leader>hu", function() gs().stage_hunk()                      end, { desc = "Unstage hunk (toggle)" } },
      { "n", "<leader>hr", function() gs().reset_hunk()                      end, { desc = "Restore hunk (discard)" } },
      { "v", "<leader>hs", function() gs().stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Stage selection" } },
      { "v", "<leader>hr", function() gs().reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Restore selection" } },
    },
  },
})

vim.keymap.set("n", "<leader>ghV", function()
  local current_file = vim.api.nvim_buf_get_name(0)
  if current_file == "" then
    vim.notify("Current buffer has no file name", vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = "Diff against ref: ", default = "main" }, function(ref)
    if not ref or ref == "" then return end

    local git_root = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
    if vim.v.shell_error ~= 0 or not git_root or git_root == "" then
      vim.notify("Not inside a git repository", vim.log.levels.ERROR)
      return
    end

    local rel = vim.fs.relpath(git_root, current_file)
    if not rel then
      vim.notify("File outside repo", vim.log.levels.ERROR)
      return
    end

    vim.cmd("update")
    vim.cmd("DiffviewOpen " .. vim.fn.fnameescape(ref) .. " -- " .. vim.fn.fnameescape(rel))
  end)
end, { desc = "Diff split: buffer vs ref" })

vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Source control (working tree vs index)" })
vim.keymap.set("n", "<leader>gx", "<cmd>DiffviewClose<cr>",      { desc = "Diffview: close" })
vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "File history" })
