--This file should have all functions that are in the public api and either set
--or read the state of this source.

local vim = vim
local utils = require("neo-tree.utils")
local renderer = require("neo-tree.ui.renderer")
local manager = require("neo-tree.sources.manager")
local events = require("neo-tree.events")
local items = require("neo-tree.sources.diagnostics.lib.items")
local diag_highlights = require("neo-tree.sources.diagnostics.highlights")
local defaults = require("neo-tree.sources.diagnostics.defaults")

local M = { name = "diagnostics" }

local wrap = function(func)
  return utils.wrap(func, M.name)
end

local get_state = function()
  return manager.get_state(M.name)
end

local follow_internal = function()
  if vim.bo.filetype == "neo-tree" or vim.bo.filetype == "neo-tree-popup" then
    return
  end
  local path_to_reveal = manager.get_path_to_reveal()

  local state = get_state()
  if state.current_position == "float" then
    return false
  end
  if not state.path then
    return false
  end
  local window_exists = renderer.window_exists(state)
  if window_exists then
    local tree = state.tree
    if tree == nil then
      return false
    end
    local cur_node = tree:get_node()
    local follow_node = tree:get_node(path_to_reveal)
    if follow_node == nil then
      return false
    end
    local was_expanded = follow_node:is_expanded()
    local follow_behavior = state.follow_behavior or {}
    if follow_behavior.collapse_others then
      renderer.collapse_all_nodes(tree)
      renderer.expand_to_node(tree, follow_node)
      if was_expanded then
        follow_node:expand()
      end
    end
    if follow_behavior.expand_followed then
      if not follow_node:is_expanded() then
        follow_node:expand()
      end
    end
    if follow_behavior.always_focus_file or cur_node.path ~= path_to_reveal then
      renderer.focus_node(state, path_to_reveal, true)
    else
      renderer.focus_node(state, cur_node.id, true)
    end
    renderer.redraw(state)
  end
end

M.follow = function()
  utils.debounce("neo-tree-diagnostics-follow", function()
    return follow_internal()
  end, 100, utils.debounce_strategy.CALL_LAST_ONLY)
end

local diagnostics_changed_internal = function()
  for _, tabnr in ipairs(vim.api.nvim_list_tabpages()) do
    local state = manager.get_state(M.name, tabnr)
    if state.path and renderer.window_exists(state) then
      items.get_diagnostics(state)
      if state.follow_current_file then
        follow_internal()
      end
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
M.navigate = function(state, path, path_to_reveal)
  state.dirty = false
  local path_changed = false
  if path == nil then
    path = vim.fn.getcwd()
  end
  if path ~= state.path then
    state.path = path
    path_changed = true
  end
  if path_to_reveal then
    renderer.position.set(state, path_to_reveal)
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
  diag_highlights.setup()
  events.subscribe({
    event = events.VIM_COLORSCHEME,
    handler = diag_highlights.setup,
    id = "neo-tree-diagnostics-highlights",
  })

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

  if config.follow_current_file then
    manager.subscribe(M.name, {
      event = events.VIM_BUFFER_ENTER,
      handler = M.follow,
    })
  end
end

M.default_config = defaults

return M
