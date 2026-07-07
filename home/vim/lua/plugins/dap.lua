-- nvim-dap: Debug Adapter Protocol client.
-- Backend is GDB itself (>= 14), which speaks DAP natively when launched as
-- `gdb --interpreter=dap`. That gives editor breakpoints, a signed "current
-- line" marker, stepping, and (via nvim-dap-ui) scopes/watches/stack panes.
local dap = require("dap")
local dapui = require("dapui")

-- ── Adapter ───────────────────────────────────────────────────────────────
-- One adapter, reused by every native (C/C++/Rust/Zig/…) configuration.
dap.adapters.gdb = {
  type = "executable",
  command = "gdb",
  args = { "--interpreter=dap", "--eval-command", "set print pretty on" },
}

-- ── Configurations ──────────────────────────────────────────────────────────
-- Prompt for the executable to debug (defaulting to the cwd), relative to the
-- current file's directory. Extend `program`/`args` per project as needed.
local function pick_executable()
  return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
end

local native = {
  {
    name = "Launch (prompt for executable)",
    type = "gdb",
    request = "launch",
    program = pick_executable,
    cwd = "${workspaceFolder}",
    stopAtBeginningOfMainSubprogram = false,
  },
  {
    name = "Launch with arguments",
    type = "gdb",
    request = "launch",
    program = pick_executable,
    args = function()
      local raw = vim.fn.input("Arguments: ")
      return vim.split(raw, " ", { trimempty = true })
    end,
    cwd = "${workspaceFolder}",
  },
  {
    name = "Attach to running process",
    type = "gdb",
    request = "attach",
    processId = require("dap.utils").pick_process,
    cwd = "${workspaceFolder}",
  },
}

dap.configurations.c = native
dap.configurations.cpp = native
dap.configurations.rust = native

-- ── Project launch.json ─────────────────────────────────────────────────────
-- Alias the common VS Code C/C++ adapter types onto our single gdb adapter, so
-- a launch.json authored for VS Code (type "cppdbg"/"lldb"/"codelldb") is still
-- launchable here. Only the shared fields (program/args/cwd/stopAtEntry-ish)
-- carry over; adapter-specific keys (MIMode, miDebuggerPath, setupCommands, …)
-- are simply ignored by GDB's DAP interpreter.
local gdb_backed = { gdb = true, cppdbg = true, lldb = true, codelldb = true }
for t in pairs(gdb_backed) do
  dap.adapters[t] = dap.adapters.gdb
end

-- Prefer a project-local `.nvim/launch.json` over `.vscode/launch.json`. This
-- lets a project ship an nvim-dap-compatible debug config (e.g. type "gdb")
-- without touching its VS Code setup, which is often incompatible with this
-- native-gdb adapter. When `.nvim/launch.json` is absent we fall back to
-- nvim-dap's default `.vscode/launch.json` handling.
--
-- On top of nvim-dap's own variable expansion (`${workspaceFolder}`,
-- `${env:VAR}`, `${file}`, …) this provider also resolves:
--   • `${workspaceRoot}`   — the deprecated VS Code alias for workspaceFolder.
--   • `${config:a.b.c}`     — VS Code "settings" references, looked up in a
--                             central `.nvim/settings.json` (falling back to
--                             `.vscode/settings.json`). This is the single
--                             place to fill in machine-specific paths.
-- Resolution happens here, before nvim-dap sees the config, so its own
-- expansion still runs afterwards (a resolved value may itself contain
-- `${workspaceFolder}`/`${env:…}`). Edits take effect on the next run.

-- Read a JSONC file (comments allowed) into a table, or nil if missing/invalid.
local function read_jsonc(path)
  if not vim.uv.fs_stat(path) then return nil end
  local fp = io.open(path, "r")
  if not fp then return nil end
  local contents = fp:read("*a")
  fp:close()
  local ok, data = pcall(vim.json.decode, contents, { skip_comments = true })
  if not ok or type(data) ~= "table" then
    vim.notify("DAP: failed to parse " .. path .. "\n" .. tostring(data), vim.log.levels.WARN)
    return nil
  end
  return data
end

-- Merge the settings that back `${config:...}`. `.nvim/settings.json` wins over
-- `.vscode/settings.json`, so nvim-specific paths can override the VS Code ones.
local function project_settings(cwd)
  local vs = read_jsonc(cwd .. "/.vscode/settings.json") or {}
  local nv = read_jsonc(cwd .. "/.nvim/settings.json") or {}
  return vim.tbl_deep_extend("force", vs, nv)
end

-- Look up a dotted key, supporting both flat ("a.b.c") and nested table forms.
local function setting_get(settings, dotted)
  if settings[dotted] ~= nil then return settings[dotted] end
  local cur = settings
  for part in dotted:gmatch("[^.]+") do
    if type(cur) ~= "table" then return nil end
    cur = cur[part]
  end
  return cur
end

-- Resolve ${workspaceRoot} and ${config:...} inside one string. Several passes
-- so a resolved value that itself contains ${config:...} is fully expanded.
-- Unknown keys are left intact and collected for a one-shot warning.
local function resolve_str(str, settings, missing)
  str = str:gsub("%${workspaceRoot}", "${workspaceFolder}")
  for _ = 1, 5 do
    if not str:find("%${config:") then break end
    str = str:gsub("%${config:([%w_%.%-]+)}", function(key)
      local val = setting_get(settings, key)
      if val == nil then
        missing[key] = true
        return "${config:" .. key .. "}"
      end
      return tostring(val)
    end)
  end
  return str
end

-- Recursively resolve references throughout a config, preserving any metatable.
local function resolve_config(value, settings, missing)
  if type(value) == "string" then
    return resolve_str(value, settings, missing)
  elseif type(value) == "table" then
    local out = {}
    for k, v in pairs(value) do
      out[k] = resolve_config(v, settings, missing)
    end
    return setmetatable(out, getmetatable(value))
  end
  return value
end

dap.providers.configs["dap.launch.json"] = function()
  local vscode = require("dap.ext.vscode")
  local cwd = vim.fn.getcwd()
  local nvim_json = cwd .. "/.nvim/launch.json"
  local path = vim.uv.fs_stat(nvim_json) and nvim_json or nil
  local ok, configs = pcall(vscode.getconfigs, path)
  if not ok then
    vim.notify("DAP: can't read launch.json:\n" .. tostring(configs), vim.log.levels.WARN)
    return {}
  end
  local settings = project_settings(cwd)
  local missing = {}
  configs = vim.tbl_map(function(c) return resolve_config(c, settings, missing) end, configs)

  if next(missing) then
    local keys = vim.tbl_keys(missing)
    table.sort(keys)
    vim.notify(
      "DAP: unresolved ${config:...} — add to .nvim/settings.json:\n  " .. table.concat(keys, "\n  "),
      vim.log.levels.WARN
    )
  end
  return configs
end

-- ── Keep file buffers out of the DAP UI windows ─────────────────────────────
-- Each dapui element (scopes, watches, breakpoints, stacks, repl, console, …)
-- lives in its own window with a fixed filetype. When a real file is opened
-- while one of those is focused — e.g. `gd`, a Telescope pick, a quickfix jump
-- — Neovim tries to display the file there. dapui's own autocmd then snaps the
-- element buffer back and simply *drops* the file (it never reaches a window),
-- which is the "it fails / nothing opens" the user sees.
--
-- We register BEFORE dapui.setup() so our BufWinEnter runs first, while the file
-- is still shown in the DAP window: we grab the file and the cursor line the
-- opener jumped to, then (on the next tick, after dapui has restored its
-- element) re-show the file in a real editor window with that cursor. Deferring
-- means dapui does the element-restoring for us; we only relocate the file.
--
-- DAP windows are detected statelessly by their window options: dapui pins every
-- element window with winfixwidth+winfixheight (a plain editor window has
-- neither). These are window-local, so they still identify the window even while
-- the stray file buffer is momentarily displayed in it.
local dap_fts = {
  ["dapui_scopes"] = true,
  ["dapui_breakpoints"] = true,
  ["dapui_stacks"] = true,
  ["dapui_watches"] = true,
  ["dapui_console"] = true,
  ["dapui_hover"] = true,
  ["dap-repl"] = true,
}

local function is_dap_win(w)
  return vim.api.nvim_win_get_config(w).relative == ""
    and vim.wo[w].winfixwidth and vim.wo[w].winfixheight
end

-- A normal, editable, non-floating file window that is not a DAP element or
-- neo-tree — a valid home for a file the user just opened.
local function find_editor_win()
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not is_dap_win(w) and vim.api.nvim_win_get_config(w).relative == "" then
      local b = vim.api.nvim_win_get_buf(w)
      if vim.bo[b].buftype == "" and not dap_fts[vim.bo[b].filetype]
        and vim.bo[b].filetype ~= "neo-tree" then
        return w
      end
    end
  end
  return nil
end

vim.api.nvim_create_autocmd("BufWinEnter", {
  callback = function(args)
    local buf = args.buf
    -- Only relocate real, on-disk file buffers.
    if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then
      return
    end
    local win = vim.api.nvim_get_current_win()
    -- Only act when the file just landed in a DAP element window.
    if not is_dap_win(win) then return end

    -- The opener already positioned the cursor for the jump; capture it now,
    -- while the file is still the one shown in this window.
    local ok, cursor = pcall(vim.api.nvim_win_get_cursor, win)
    if not ok then cursor = nil end

    -- Defer: let dapui restore its element in `win` first, then place the file
    -- in a proper editor window.
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then return end
      local target = find_editor_win()
      if not target then
        -- Layout is nothing but DAP UI: carve out an editor split next to it.
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_set_current_win(win)
        end
        vim.cmd("aboveleft vsplit")
        target = vim.api.nvim_get_current_win()
        vim.wo[target].winfixwidth = false
        vim.wo[target].winfixheight = false
      end
      pcall(vim.api.nvim_win_set_buf, target, buf)
      pcall(vim.api.nvim_set_current_win, target)
      if cursor then pcall(vim.api.nvim_win_set_cursor, target, cursor) end
    end)
  end,
})

-- ── UI ───────────────────────────────────────────────────────────────────
require("nvim-dap-virtual-text").setup({})
dapui.setup()

-- UI lifecycle. Open when a session starts. Crucially, do NOT close on
-- terminate/exit: short-lived programs (CLI tools like hrun, a failing launch,
-- a program that just runs to completion) would otherwise rip the layout —
-- and the console output/exit reason — away before it can be read. Instead we
-- keep the UI up and surface the exit code, and only tear the layout down when
-- a *new* session starts or on the manual toggle (<leader>du).
dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
dap.listeners.before.event_terminated["dapui_config"] = function()
  vim.schedule(function() vim.notify("DAP: program terminated", vim.log.levels.INFO) end)
end
dap.listeners.before.event_exited["dapui_config"] = function(_, body)
  vim.schedule(function()
    vim.notify("DAP: program exited (code " .. tostring(body and body.exitCode) .. ")",
      vim.log.levels.INFO)
  end)
end

-- ── Signs ─────────────────────────────────────────────────────────────────
vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError", numhl = "" })
vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn", numhl = "" })
vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DiagnosticInfo", numhl = "" })
vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticOk", linehl = "Visual", numhl = "" })
vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DiagnosticError", numhl = "" })

-- ── Keymaps (<leader>d = debug; F-keys for stepping) ────────────────────────
local map = vim.keymap.set
map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
map("n", "<leader>dB", function()
  dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, { desc = "Conditional breakpoint" })
map("n", "<leader>dc", dap.continue, { desc = "Continue / start" })
map("n", "<leader>dC", dap.run_to_cursor, { desc = "Run to cursor" })
map("n", "<leader>di", dap.step_into, { desc = "Step into" })
map("n", "<leader>do", dap.step_over, { desc = "Step over (next)" })
map("n", "<leader>dO", dap.step_out, { desc = "Step out" })
map("n", "<leader>dk", dap.up, { desc = "Stack: up (caller)" })
map("n", "<leader>dj", dap.down, { desc = "Stack: down (callee)" })
map("n", "<leader>dr", dap.repl.toggle, { desc = "Toggle REPL" })
map("n", "<leader>dl", dap.run_last, { desc = "Run last" })
map("n", "<leader>dt", dap.terminate, { desc = "Terminate session" })
map("n", "<leader>du", dapui.toggle, { desc = "Toggle DAP UI" })
map("n", "<leader>de", function() dapui.eval(nil, { enter = true }) end, { desc = "Evaluate expression" })
map("v", "<leader>de", function() dapui.eval(nil, { enter = true }) end, { desc = "Evaluate selection" })

-- Function-key stepping.
map("n", "<F5>", dap.continue, { desc = "Debug: continue" })
map("n", "<F6>", dap.step_over, { desc = "Debug: step over" })
map("n", "<F7>", dap.step_into, { desc = "Debug: step into" })
map("n", "<F8>", dap.step_out, { desc = "Debug: step out" })
map("n", "<F9>", dap.toggle_breakpoint, { desc = "Debug: toggle breakpoint" })
map("n", "<F2>", dap.restart, { desc = "Debug: restart program" })
