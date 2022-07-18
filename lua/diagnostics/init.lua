--This file should have all functions that are in the public api and either set
--or read the state of this source.

local vim = vim
local utils = require("neo-tree.utils")
local renderer = require("neo-tree.ui.renderer")
local manager = require("neo-tree.sources.manager")
local events = require("neo-tree.events")
local items = require("diagnostics.lib.items")

local M = { name = "diagnostics" }

local wrap = function(func)
  return utils.wrap(func, M.name)
end

local get_state = function()
  return manager.get_state(M.name)
end

local diagnostics_changed_internal = function()
  for _, tabnr in ipairs(vim.api.nvim_list_tabpages()) do
    local state = manager.get_state(M.name, tabnr)
    if state.path and renderer.window_exists(state) then
      items.get_diagnostics(state)
    end
  end
end

M.diagnostics_changed = function()
  utils.debounce(
    "diagonostics_changed",
    diagnostics_changed_internal,
    100,
    utils.debounce_strategy.CALL_LAST_ONLY
  )
end

---Navigate to the given path.
---@param path string Path to navigate to. If empty, will navigate to the cwd.
M.navigate = function(state, path)
  state.dirty = false
  local path_changed = false
  if path == nil then
    path = vim.fn.getcwd()
  end
  if path ~= state.path then
    state.path = path
    path_changed = true
  end

  items.get_diagnostics(state)

  if path_changed and state.bind_to_cwd then
    vim.api.nvim_command("tcd " .. path)
  end
end

---Configures the plugin, should be called before the plugin is used.
---@param config table Configuration table containing any keys that the user
--wants to change from the defaults. May be empty to accept default values.
M.setup = function(config, global_config)
  if config.before_render then
    manager.subscribe(M.name, {
      event = events.BEFORE_RENDER,
      handler = function(state)
        local this_state = get_state()
        if state == this_state then
          config.before_render(this_state)
        end
      end,
    })
  end

  manager.subscribe(M.name, {
    event = events.VIM_DIAGNOSTIC_CHANGED,
    handler = M.diagnostics_changed,
  })

  if config.bind_to_cwd then
    manager.subscribe(M.name, {
      event = events.VIM_DIR_CHANGED,
      handler = wrap(manager.dir_changed),
    })
  end
end

M.default_config = {
  bind_to_cwd = true,
  diag_sort_function = "severity", -- "severity" means diagnostic items are sorted by severity in addition to their positions.
                                   -- "position" means diagnostic items are sorted strictly by their positions.
  group_dirs_and_files = true, -- when true, empty folders and files will be grouped together
  group_empty_dirs = true, -- when true, empty directories will be grouped together
  show_unloaded = true, -- show diagnostics from unloaded buffers
  renderers = {
    file = {
      { "indent" },
      { "icon" },
      { "grouped_path" },
      { "name" },
      { "diagnostic_count", show_when_none = true },
      { "diagnostic_count", severity = "Error", right_padding = 0 },
      { "diagnostic_count", severity = "Warn", right_padding = 0 },
      { "diagnostic_count", severity = "Info", right_padding = 0 },
      { "diagnostic_count", severity = "Hint", right_padding = 0 },
      { "clipboard" },
    },
    diagnostic = {
      { "indent" },
      { "icon" },
      { "name" },
      { "source" },
      { "code" },
      { "position" },
    },
  },
  window = {
    mappings = {},
  },
}

return M
