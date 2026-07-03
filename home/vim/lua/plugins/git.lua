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

-- Fugitive: the git porcelain. Replaces Diffview + git-conflict.
--
-- Source-control panel:   :Git   (stage with `s`, unstage `u`, `=` toggles the
--                         inline diff, `cc` commits, `dv` opens a diff split).
--
-- Conflict resolution is fugitive's strength — no separate conflict plugin
-- needed. On a file with conflict markers, `<leader>gm` opens a 3-way diff:
--   left  = //2 (OURS / current, HEAD)      right = //3 (THEIRS / incoming)
--   center = the working copy you edit
-- Pull a side into the center with `<leader>g2` (ours) / `<leader>g3` (theirs),
-- or use vim's built-in `do`/`dp` per hunk. Save the center, done.

vim.keymap.set("n", "<leader>gd", "<cmd>Git<cr>", { desc = "Source control (fugitive status)" })
vim.keymap.set("n", "<leader>gb", "<cmd>Git blame<cr>", { desc = "Blame (fugitive)" })
vim.keymap.set("n", "<leader>gh", "<cmd>0Gclog<cr>", { desc = "File history (fugitive)" })

-- Close diff splits and return to the single working-copy window.
vim.keymap.set("n", "<leader>gx", function()
  vim.cmd("diffoff!")
  vim.cmd("only")
end, { desc = "Close diff splits" })

-- Diff current buffer against an arbitrary ref (vertical split).
vim.keymap.set("n", "<leader>ghV", function()
  vim.ui.input({ prompt = "Diff against ref: ", default = "main" }, function(ref)
    if not ref or ref == "" then return end
    vim.cmd("update")
    vim.cmd("Gvdiffsplit " .. vim.fn.fnameescape(ref))
  end)
end, { desc = "Diff split: buffer vs ref" })

-- Merge-conflict resolution: 3-way vertical diff of the current file.
vim.keymap.set("n", "<leader>gm", "<cmd>Gvdiffsplit!<cr>", { desc = "Conflict: 3-way diff" })
vim.keymap.set("n", "<leader>g2", "<cmd>diffget //2<cr>", { desc = "Conflict: take ours (//2)" })
vim.keymap.set("n", "<leader>g3", "<cmd>diffget //3<cr>", { desc = "Conflict: take theirs (//3)" })

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
