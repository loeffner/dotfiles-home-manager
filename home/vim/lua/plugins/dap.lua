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

-- ── UI ───────────────────────────────────────────────────────────────────
require("nvim-dap-virtual-text").setup({})
dapui.setup()

-- Auto-open the UI when a session starts, close it when it ends.
dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end

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
