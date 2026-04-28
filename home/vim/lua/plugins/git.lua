-- Gitsigns: gutter signs, hunk navigation, blame, partial staging.
require("gitsigns").setup({
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
require("diffview").setup({
  enhanced_diff_hl = true,
  view = {
    default = { layout = "diff2_horizontal" },
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

    vim.schedule(function()
      local wins = vim.tbl_filter(function(w) return vim.wo[w].diff end,
        vim.api.nvim_tabpage_list_wins(0))
      table.sort(wins, function(a, b)
        return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
      end)
      if wins[1] then
        vim.wo[wins[1]].winhighlight = table.concat({
          "DiffAdd:DiffviewDiffAddAsDelete",
          "DiffDelete:DiffviewDiffDeleteDim",
          "DiffChange:DiffviewDiffAddAsDelete",
          "DiffText:DiffviewDiffTextDelete",
        }, ",")
      end
      if wins[2] then
        vim.wo[wins[2]].winhighlight = table.concat({
          "DiffDelete:DiffviewDiffDeleteDim",
          "DiffAdd:DiffviewDiffAdd",
          "DiffChange:DiffviewDiffAdd",
          "DiffText:DiffviewDiffText",
        }, ",")
      end
    end)
  end)
end, { desc = "Diff split: buffer vs ref" })

vim.keymap.set("n", "<leader>gd", "<cmd>DiffviewOpen<cr>",       { desc = "Diffview: open" })
vim.keymap.set("n", "<leader>gx", "<cmd>DiffviewClose<cr>",      { desc = "Diffview: close" })
vim.keymap.set("n", "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", { desc = "File history" })
