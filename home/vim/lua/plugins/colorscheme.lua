-- VS Code Dark Modern syntax colors on a Gruvbox dark background.
--
-- Strategy: use Mofiqul/vscode.nvim (which gives us the Dark Modern token
-- palette out of the box) and remap only the *background-family* palette
-- entries to gruvbox tones via `color_overrides`. Syntax token colors
-- (vscYellow, vscBlue, vscOrange, vscBlueGreen, …) are left untouched, so
-- functions still glow `#DCDCAA`, types `#4EC9B0`, strings `#CE9178`, etc.
--
-- See https://github.com/Mofiqul/vscode.nvim
local vscode = require("vscode")

-- Gruvbox dark background tones.
local g = {
  bg0_h = "#1d2021", -- hard background (sidebar, inactive tabs, popups)
  bg0   = "#282828", -- normal background (editor)
  bg0_s = "#32302f", -- soft background (alt panes)
  bg1   = "#3c3836", -- one step lighter (statusline bg, cursorline)
  bg2   = "#504945",
  bg3   = "#665c54",
  bg4   = "#7c6f64",
  fg    = "#ebdbb2", -- gruvbox fg1
  fg2   = "#d5c4a1",
  gray  = "#928374",
}

vscode.setup({
  style = "dark",
  transparent = false,
  italic_comments = true,
  underline_links = true,
  disable_nvimtree_bg = true,
  terminal_colors = true,

  -- Override only the background-family palette entries with gruvbox shades.
  -- Syntax token colors (vscYellow/Blue/Orange/BlueGreen/Pink/LightBlue/...)
  -- are intentionally NOT overridden, so VS Code's Dark Modern token coloring
  -- stays intact on top of gruvbox surfaces.
  color_overrides = {
    -- Editor surfaces
    vscBack         = g.bg0,
    vscFront        = g.fg,

    -- Tabs
    vscTabCurrent   = g.bg0,
    vscTabOther     = g.bg0_h,
    vscTabOutside   = g.bg0_h,

    -- Sidebar / explorer
    vscLeftDark     = g.bg0_h,
    vscLeftMid      = g.bg1,
    vscLeftLight    = g.bg2,

    -- Popup menus (cmp / hover)
    vscPopupBack    = g.bg0_h,
    vscPopupFront   = g.fg,

    -- Splits
    vscSplitDark    = g.bg1,
    vscSplitLight   = g.bg2,
    vscSplitThumb   = g.bg2,

    -- Cursor line / context guides
    vscCursorDarkDark = g.bg0_h,
    vscContext        = g.bg1,
    vscContextCurrent = g.bg3,

    -- Line numbers
    vscLineNumber   = g.bg4,

    -- Folds (slightly tinted)
    vscFoldBackground = g.bg0_s,
  },

  group_overrides = {
    -- Reinforce a few groups that don't pick up the palette swap directly.
    Normal       = { fg = g.fg, bg = g.bg0 },
    NormalNC     = { fg = g.fg, bg = g.bg0 },
    NormalFloat  = { fg = g.fg, bg = g.bg0_h },
    FloatBorder  = { fg = g.gray, bg = g.bg0_h },
    SignColumn   = { bg = g.bg0 },
    LineNr       = { fg = g.bg4, bg = g.bg0 },
    CursorLine   = { bg = g.bg1 },
    CursorLineNr = { fg = g.fg, bg = g.bg1, bold = true },
    ColorColumn  = { bg = g.bg0_h },
    VertSplit    = { fg = g.bg1, bg = g.bg0 },
    WinSeparator = { fg = g.bg1, bg = g.bg0 },

    -- Statusline / tabline backgrounds.
    StatusLine   = { fg = g.fg, bg = g.bg1 },
    StatusLineNC = { fg = g.gray, bg = g.bg0_h },
    TabLine      = { fg = g.gray, bg = g.bg0_h },
    TabLineFill  = { bg = g.bg0_h },
    TabLineSel   = { fg = g.fg, bg = g.bg0 },

    -- Pmenu (completion popup)
    Pmenu        = { fg = g.fg, bg = g.bg0_h },
    PmenuSel     = { fg = g.fg, bg = g.bg2 },
    PmenuSbar    = { bg = g.bg0_h },
    PmenuThumb   = { bg = g.bg2 },

    -- Telescope panels — use bg0_h for borders/prompts so they read as
    -- "panels" against the editor bg0. Title accents use gruvbox tones.
    TelescopeNormal       = { bg = g.bg0_h },
    TelescopeBorder       = { fg = g.bg2, bg = g.bg0_h },
    TelescopePromptNormal = { bg = g.bg1 },
    TelescopePromptBorder = { fg = g.bg1, bg = g.bg1 },
    TelescopePromptTitle  = { fg = g.bg0, bg = "#fabd2f", bold = true }, -- gruvbox yellow
    TelescopeResultsTitle = { fg = g.bg0_h, bg = g.bg0_h },
    TelescopePreviewTitle = { fg = g.bg0, bg = "#8ec07c", bold = true }, -- gruvbox aqua
    TelescopeSelection    = { bg = g.bg2 },

    -- Neo-tree — gruvbox accent palette for the file tree.
    NeoTreeNormal         = { fg = g.fg, bg = g.bg0_h },
    NeoTreeNormalNC       = { fg = g.fg, bg = g.bg0_h },
    NeoTreeEndOfBuffer    = { fg = g.bg0_h, bg = g.bg0_h },
    NeoTreeWinSeparator   = { fg = g.bg0_h, bg = g.bg0_h },
    NeoTreeRootName       = { fg = "#fabd2f", bold = true },          -- yellow
    NeoTreeDirectoryName  = { fg = "#83a598" },                       -- blue
    NeoTreeDirectoryIcon  = { fg = "#83a598" },                       -- blue
    NeoTreeFileName       = { fg = g.fg },
    NeoTreeFileIcon       = { fg = g.fg2 },
    NeoTreeFileNameOpened = { fg = "#fabd2f", italic = true },        -- yellow
    NeoTreeSymbolicLinkTarget = { fg = "#d3869b", italic = true },    -- purple
    NeoTreeIndentMarker   = { fg = g.bg2 },
    NeoTreeExpander       = { fg = g.gray },
    NeoTreeFloatBorder    = { fg = g.bg2, bg = g.bg0_h },
    NeoTreeFloatTitle     = { fg = g.bg0, bg = "#fabd2f", bold = true },
    NeoTreeTitleBar       = { fg = g.bg0, bg = "#fabd2f", bold = true },
    NeoTreeCursorLine     = { bg = g.bg2 },

    -- Neo-tree git status — gruvbox accents.
    NeoTreeGitAdded       = { fg = "#b8bb26" }, -- green
    NeoTreeGitModified    = { fg = "#fabd2f" }, -- yellow
    NeoTreeGitDeleted     = { fg = "#fb4934" }, -- red
    NeoTreeGitRenamed     = { fg = "#8ec07c" }, -- aqua
    NeoTreeGitUntracked   = { fg = "#fe8019" }, -- orange
    NeoTreeGitIgnored     = { fg = g.gray },
    NeoTreeGitConflict    = { fg = "#fb4934", bold = true },
    NeoTreeGitStaged      = { fg = "#b8bb26", bold = true },
    NeoTreeGitUnstaged    = { fg = "#fe8019" },

    -- Indent guides
    IblIndent     = { fg = g.bg1 },
    IblScope      = { fg = g.bg3 },

    -- Comments — light grey (overrides VS Code's green comment tone).
    ["@comment"] = { fg = "#a8a8a8", italic = true },
    Comment      = { fg = "#a8a8a8", italic = true },
  },
})

vim.o.background = "dark"
vscode.load()
