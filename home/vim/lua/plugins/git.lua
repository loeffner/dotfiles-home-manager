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

    -- Label the hunk sub-group only in buffers where these maps exist.
    require("which-key").add({ "<leader>gh", group = "hunk", buffer = buf })

    map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
    map("n", "[h", function() gs.nav_hunk("prev") end, "Previous hunk")
    map("n", "<leader>ghs", gs.stage_hunk,        "Stage/unstage hunk (toggle)")
    map("v", "<leader>ghs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Stage/unstage selection")
    map("n", "<leader>ghr", gs.reset_hunk,        "Reset hunk (discard)")
    map("v", "<leader>ghr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "Reset selection (discard)")
    map("n", "<leader>ghp", gs.preview_hunk,      "Preview hunk")
    map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Blame line")
    map("n", "<leader>ghB", gs.toggle_current_line_blame, "Toggle inline blame")

    map("n", "<leader>ghd", function()
      gs.toggle_linehl()
      gs.toggle_deleted()
      gs.toggle_word_diff()
    end, "Toggle full inline diff")

    map("n", "<leader>gB", function()
      vim.ui.input({ prompt = "Gitsigns base ref: ", default = "main" }, function(ref)
        if ref and ref ~= "" then gs.change_base(ref, true) end
      end)
    end, "Set gitsigns base ref")
  end,
})

-- Diffview: side-aware diff with red/green per pane.
-- `<leader>gd` opens the working tree vs the index, giving VS Code-style
-- "Changes" (unstaged) and "Staged changes" sections in the file panel.
-- In the file panel: `s`/`-` toggle stage on a file, `S` stage all,
-- `U` unstage all, `X` discard. Hunk-level staging via `<leader>ghs` in a
-- diff window (same keys as everywhere else), or by editing the index buffer.
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
    -- Hunk staging inside the diff windows themselves. The right pane is the
    -- working-tree buffer (gitsigns attached), so `<leader>gh*` already work
    -- there via gitsigns' on_attach. Mirror the same keys onto the whole
    -- Diffview so staging works from either pane, using the identical
    -- `<leader>gh*` scheme as normal buffers — no separate `<leader>h*` set.
    view = {
      { "n", "<leader>ghs", function() gs().stage_hunk()                      end, { desc = "Stage/unstage hunk (toggle)" } },
      { "n", "<leader>ghr", function() gs().reset_hunk()                      end, { desc = "Reset hunk (discard)" } },
      { "n", "<leader>ghp", function() gs().preview_hunk()                    end, { desc = "Preview hunk" } },
      { "v", "<leader>ghs", function() gs().stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Stage/unstage selection" } },
      { "v", "<leader>ghr", function() gs().reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, { desc = "Reset selection (discard)" } },
    },
  },
})

vim.keymap.set("n", "<leader>gr", function()
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
end, { desc = "Diff: buffer vs ref (prompt)" })

vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>", { desc = "Source control (working tree vs index)" })
vim.keymap.set("n", "<leader>gx", "<cmd>DiffviewClose<cr>",      { desc = "Diffview: close" })
vim.keymap.set("n", "<leader>gf", "<cmd>DiffviewFileHistory %<cr>", { desc = "File history (current file)" })

-- Toggle ignoring *all* whitespace in diffs (on top of the always-on
-- `iwhiteeol`). Handy for reverts/merges where reindentation would otherwise
-- drown out the real changes. Recomputes open diffs via :diffupdate.
vim.keymap.set("n", "<leader>gw", function()
  if vim.tbl_contains(vim.opt.diffopt:get(), "iwhiteall") then
    vim.opt.diffopt:remove("iwhiteall")
    vim.notify("Diff: showing whitespace changes", vim.log.levels.INFO)
  else
    vim.opt.diffopt:append("iwhiteall")
    vim.notify("Diff: ignoring whitespace changes", vim.log.levels.INFO)
  end
  vim.cmd("diffupdate")
end, { desc = "Toggle ignore whitespace in diffs" })

-- git-conflict: highlight ONLY the conflict regions (ours/theirs/ancestor) in
-- the plain buffer and leave the rest untouched — the VS Code "merge editor"
-- feel, without a full diff view.
--
-- The plugin's `default_mappings` bind the *unprefixed* `co`/`ct`/`cb`/`c0`,
-- which shadow the `c` (change) operator and make every `c…` motion hang.
-- So disable them and define our own buffer-local maps under a labelled
-- `<leader>gc` (conflict) sub-group that only exists in files with real
-- conflicts:
--   ]x / [x        next / previous conflict
--   <leader>gco    choose ours (HEAD / current)
--   <leader>gct    choose theirs (incoming)
--   <leader>gcb    choose both
--   <leader>gcn    choose none
require("git-conflict").setup({
  default_mappings = false,
  default_commands = true,
  -- No `highlights` override: the plugin's defaults already tint ours green
  -- and theirs blue (the VS Code merge-editor look).
})

vim.api.nvim_create_autocmd("User", {
  pattern = "GitConflictDetected",
  callback = function(ev)
    require("which-key").add({ "<leader>gc", group = "conflict", buffer = ev.buf })
    local function map(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc })
    end
    map("]x", "<cmd>GitConflictNextConflict<cr>", "Next conflict")
    map("[x", "<cmd>GitConflictPrevConflict<cr>", "Previous conflict")
    map("<leader>gco", "<cmd>GitConflictChooseOurs<cr>",   "Choose ours (current)")
    map("<leader>gct", "<cmd>GitConflictChooseTheirs<cr>", "Choose theirs (incoming)")
    map("<leader>gcb", "<cmd>GitConflictChooseBoth<cr>",   "Choose both")
    map("<leader>gcn", "<cmd>GitConflictChooseNone<cr>",   "Choose none")
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "GitConflictResolved",
  callback = function(ev)
    for _, lhs in ipairs({ "]x", "[x", "<leader>gco", "<leader>gct", "<leader>gcb", "<leader>gcn" }) do
      pcall(vim.keymap.del, "n", lhs, { buffer = ev.buf })
    end
  end,
})
