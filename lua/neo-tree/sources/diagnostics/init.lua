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
local log = require("neo-tree.log")

local M = { name = "diagnostics" }

local wrap = function(func)
  return utils.wrap(func, M.name)
end

local get_state = function()
  return manager.get_state(M.name)
end

-- Adapted from renderer.collapse_all_nodes
local collapse_nodes_with_cond = function(tree, cond, root_node_id)
  local expanded = renderer.get_expanded_nodes(tree, root_node_id)
  for _, id in ipairs(expanded) do
    local node = tree:get_node(id)
    if utils.is_expandable(node) and cond(node) then
      node:collapse(id)
    end
  end
  -- but make sure the root is expanded
  local root = tree:get_nodes()[1]
  if root then
    root:expand()
  end
end

local follow_internal = function()
  if vim.bo.filetype == "neo-tree" or vim.bo.filetype == "neo-tree-popup" then
    return false
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
    local follow_config = state.follow_current_file
    if not follow_config.leave_dirs_open or not follow_config.leave_files_open then
      collapse_nodes_with_cond(tree, function(node)
        local should_collapse_dir = node.type == "directory" and not follow_config.leave_dirs_open
        local should_collapse_file = node.type == "file" and not follow_config.leave_files_open
        return should_collapse_dir or should_collapse_file
      end)
      renderer.expand_to_node(state, follow_node)
      if was_expanded then
        follow_node:expand()
      end
    end
    if follow_config.expand_followed then
      if not follow_node:is_expanded() then
        follow_node:expand()
      end
    end
    if follow_config.always_focus_file or cur_node.path ~= path_to_reveal then
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

local diagnostic_update_internal = function()
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

M.diagnostic_update = function(delay)
  utils.debounce(
    "diagnostic_update",
    diagnostic_update_internal,
    delay,
    utils.debounce_strategy.CALL_LAST_ONLY
  )
end

local enable_preview = function(state, preview_config)
  local preview = require("neo-tree.sources.common.preview")

  if not preview.is_active() then
    state.config = preview_config
    state.commands.toggle_preview(state)
  end
end

M.auto_preview = function(preview_config)
  local state = get_state()

  if state.tree == nil or #vim.fn.win_findbuf(state.tree.bufnr) == 0 then
    manager.subscribe(M.name, {
      id = "neo-tree-diagnostics-auto-preview-handler",
      event = events.AFTER_RENDER,
      handler = function(new_state)
        if new_state.name == state.name then
          enable_preview(new_state, preview_config)
          return true
        end
      end,
    })
  else
    enable_preview(state, preview_config)
  end
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
    local node_ok, node = pcall(function()
      return state.tree:get_node()
    end)
    if not node_ok or node:get_parent_id() ~= path_to_reveal then
      renderer.position.set(state, path_to_reveal)
    end
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

  if config.refresh.event and config.refresh.event ~= "none" then
    manager.subscribe(M.name, {
      event = config.refresh.event,
      handler = utils.wrap(M.diagnostic_update, config.refresh.delay),
    })
  end

  if config.bind_to_cwd then
    manager.subscribe(M.name, {
      event = events.VIM_DIR_CHANGED,
      handler = wrap(manager.dir_changed),
    })
  end

  if type(config.follow_current_file) ~= "table" then
    config.follow_current_file = vim.tbl_extend("keep", {
      enabled = config.follow_current_file
    }, M.default_config.follow_current_file)
  end

  if config.follow_behavior then
    log.warn([[
      (diagnostics)
      `follow_behavior` has been deprecated
      in favor of `follow_current_file` (see README)]])

    config.follow_current_file = vim.tbl_extend("force", config.follow_current_file, config.follow_behavior)

    if config.follow_behavior.collapse_others ~= nil then
      log.warn([[
        (diagnostics)
        `follow_behavior.collapse_others` has been deprecated
        in favor of `follow_current_file.leave_dirs_open`
        and `follow_current_file.leave_files_open (see README)]])

      config.follow_current_file.leave_dirs_open = not config.follow_behavior.collapse_others
      config.follow_current_file.leave_files_open = not config.follow_behavior.collapse_others

      config.follow_current_file.collapse_others = nil
    end

    config.follow_behavior = nil
  end

  if config.follow_current_file.enabled then
    manager.subscribe(M.name, {
      event = events.VIM_BUFFER_ENTER,
      handler = M.follow,
    })
  end

  if type(config.auto_preview) ~= "table" then
    config.auto_preview = vim.tbl_extend("keep", {
      enabled = config.auto_preview
    }, M.default_config.auto_preview)
  end

  if config.auto_preview.enabled then
    manager.subscribe(M.name, {
      event = config.auto_preview.event,
      handler = utils.wrap(M.auto_preview, config.auto_preview.preview_config),
    })
  end
end

M.default_config = defaults

return M
