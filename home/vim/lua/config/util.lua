local M = {}

-- The repo's default branch from origin/HEAD; "main" when unset or not in a repo.
function M.default_branch()
  local ref = vim.fn.systemlist({ "git", "symbolic-ref", "--short", "refs/remotes/origin/HEAD" })[1]
  if vim.v.shell_error ~= 0 or not ref then return "main" end
  return (ref:gsub("^origin/", ""))
end

return M
