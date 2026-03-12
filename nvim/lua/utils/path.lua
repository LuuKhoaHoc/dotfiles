local M = {}

--- Check if current directory is a git repo
---@return boolean
function M.is_git_repo()
  vim.fn.system "git rev-parse --is-inside-work-tree"
  return vim.v.shell_error == 0
end

--- Get root directory of git project
---@return string|nil
function M.get_git_root()
  return vim.fn.systemlist("git rev-parse --show-toplevel")[1]
end

--- Get root directory of git project or fallback to current directory
---@return string|nil
function M.get_root_directory()
  if M.is_git_repo() then
    return M.get_git_root()
  end

  return vim.fn.getcwd()
end

--- Detect current package in monorepo (for MFE projects)
---@return string|nil package name or nil if not in monorepo
function M.get_monorepo_package()
  local current_dir = vim.fn.getcwd()
  local git_root = M.get_git_root()

  if not git_root then
    return nil
  end

  -- Check if we're in apps/ or packages/ directory
  local rel_path = vim.fn.fnamemodify(current_dir, ":~")

  -- Extract package name from package.json
  local package_json = current_dir .. "/package.json"
  if vim.fn.filereadable(package_json) == 1 then
    local content = vim.fn.readfile(package_json)
    local json_str = table.concat(content, "\n")
    local name = string.match(json_str, '"name"%s*:%s*"([^"]+)"')
    if name then
      -- Return short name (without scope if present)
      return string.match(name, "^@?([^/]+)$") or name
    end
  end

  return nil
end

--- Get monorepo package type (app or package)
---@return string|nil "app" or "package" or nil
function M.get_monorepo_package_type()
  local current_dir = vim.fn.getcwd()
  local git_root = M.get_git_root()

  if not git_root then
    return nil
  end

  local rel_path = vim.fn.fnamemodify(current_dir, ":s?" .. git_root .. "/??")

  if string.match(rel_path, "^apps/") then
    return "app"
  elseif string.match(rel_path, "^packages/") then
    return "package"
  end

  return nil
end

--- Get current MFE app info for display
---@return string|nil
function M.get_mfe_context()
  local package_name = M.get_monorepo_package()
  local package_type = M.get_monorepo_package_type()

  if package_name and package_type then
    return string.format("%s:%s", package_type, package_name)
  end

  return nil
end

return M
