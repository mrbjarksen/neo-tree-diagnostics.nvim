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

local follow_internal = function()
  if vim.bo.filetype == "neo-tree-popup" then
    return
  end
  local path_to_reveal
  if vim.bo.filetype == "neo-tree" then
    local last_file = vim.fn.bufname("#")
    path_to_reveal = vim.fn.fnamemodify(last_file, ":p")
  else
    path_to_reveal = manager.get_path_to_reveal()
  end

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

  if config.follow_current_file then
    manager.subscribe(M.name, {
      event = events.VIM_BUFFER_ENTER,
      handler = M.follow,
    })
  end
end

M.default_config = {
  bind_to_cwd = true,
  diag_sort_function = "severity", -- "severity" means diagnostic items are sorted by severity in addition to their positions.
                                   -- "position" means diagnostic items are sorted strictly by their positions.
  follow_behavior = { -- Behavior when `follow_current_file` is true
    always_focus_file = false, -- Focus the followed file, even when focus is currently on a diagnostic item belonging to that file.
    expand_followed = true, -- Ensure the node of the followed file is expanded
    collapse_others = true, -- Ensure other nodes are collapsed
  },
  follow_current_file = true,
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
