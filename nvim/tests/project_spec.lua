local function assert_truthy(value, message)
  if not value then
    error(message or "expected truthy value")
  end
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error((message or "assert_equal failed") .. string.format("\nexpected: %s\nactual: %s", vim.inspect(expected), vim.inspect(actual)))
  end
end

local registered_commands = {}
local original_stdpath = vim.fn.stdpath
local original_create_user_command = vim.api.nvim_create_user_command
local original_Snacks = _G.Snacks
local original_fs_dir = vim.fs.dir
local config_path = "/tmp/nvim-config"
local scanned_directories = {}

vim.fn.stdpath = function(kind)
  assert_equal(kind, "config", "stdpath should request config path")
  return config_path
end

vim.api.nvim_create_user_command = function(name, callback, opts)
  registered_commands[name] = { callback = callback, opts = opts }
end

_G.Snacks = { win = function() end }

vim.fs.dir = function(path)
  table.insert(scanned_directories, path)

  if path == config_path .. "/lua/plugins/extras" then
    local entries = {
      { "copillot-chat.lua", "file" },
      { "README.md", "file" },
      { "nested", "directory" },
    }
    local index = 0
    return function()
      index = index + 1
      local entry = entries[index]
      if entry then
        return entry[1], entry[2]
      end
    end
  end

  if path == config_path .. "/lsp" then
    local entries = {
      { "eslint.lua", "file" },
      { "vtsls.lua", "file" },
      { "notes.txt", "file" },
    }
    local index = 0
    return function()
      index = index + 1
      local entry = entries[index]
      if entry then
        return entry[1], entry[2]
      end
    end
  end

  return function() end
end

package.loaded["utils.project"] = nil
local ok, project = pcall(require, "utils.project")
assert_truthy(ok, project)
project.setup()

assert_truthy(registered_commands.ProjectSettings, "ProjectSettings command should be registered")
assert_truthy(registered_commands.ProjectSettingsHelp, "ProjectSettingsHelp command should be registered")
assert_truthy(#scanned_directories >= 2, "expected scan calls during module load")
assert_equal(scanned_directories[1], config_path .. "/lua/plugins/extras", "plugin scan should target lua/plugins/extras")
assert_truthy(not tostring(scanned_directories[1]):find("/lua/plugins/extra$"), "plugin scan should not target legacy path")
assert_equal(scanned_directories[2], config_path .. "/lsp", "lsp scan should target lsp directory")

vim.fn.stdpath = original_stdpath
vim.api.nvim_create_user_command = original_create_user_command
_G.Snacks = original_Snacks
vim.fs.dir = original_fs_dir

print("project_spec: ok")
