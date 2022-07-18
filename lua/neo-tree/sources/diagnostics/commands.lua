--This file should contain all commands meant to be used by mappings.

local vim = vim
local cc = require("neo-tree.sources.common.commands")
local diagnostics = require("neo-tree.sources.diagnostics")
local utils = require("neo-tree.utils")
local renderer = require("neo-tree.ui.renderer")
local manager = require("neo-tree.sources.manager")
local log = require("neo-tree.log")

local M = {}

local refresh = utils.wrap(manager.refresh, diagnostics.name)
local redraw = utils.wrap(manager.redraw, diagnostics.name)

local is_not_diagnostic = function(node)
  return node.type ~= "diagnostic"
end

M.add = function(state)
  cc.add(state, refresh)
end

M.add_directory = function(state)
  cc.add_directory(state, refresh)
end

M.copy_to_clipboard = function(state)
  local node = state.tree:get_node()
  if node.type == "diagnostic" then
    return
  end
  cc.copy_to_clipboard(state, redraw)
end

M.copy_to_clipboard_visual = function(state, selected_nodes)
  selected_nodes = vim.tbl_filter(is_not_diagnostic, selected_nodes)
  if #selected_nodes == 0 then
    return
  end
  cc.copy_to_clipboard_visual(state, selected_nodes, redraw)
end

M.cut_to_clipboard = function(state)
  local node = state.tree:get_node()
  if node.type == "diagnostic" then
    return
  end
  cc.cut_to_clipboard(state, redraw)
end

M.cut_to_clipboard_visual = function(state, selected_nodes)
  selected_nodes = vim.tbl_filter(is_not_diagnostic, selected_nodes)
  if #selected_nodes == 0 then
    return
  end
  cc.cut_to_clipboard_visual(state, selected_nodes, redraw)
end

M.copy = function(state)
  local node = state.tree:get_node()
  if node.type == "diagnostic" then
    return
  end
  cc.copy(state, redraw)
end

M.move = function(state)
  local node = state.tree:get_node()
  if node.type == "diagnostic" then
    return
  end
  cc.move(state, redraw)
end

M.paste_from_clipboard = function(state)
  cc.paste_from_clipboard(state, refresh)
end

M.delete = function(state)
  local node = state.tree:get_node()
  if node.type == "diagnostic" then
    return
  end
  cc.delete(state, refresh)
end

M.delete_visual = function(state, selected_nodes)
  selected_nodes = vim.tbl_filter(is_not_diagnostic, selected_nodes)
  if #selected_nodes == 0 then
    return
  end
  cc.delete_visual(state, selected_nodes, refresh)
end

local reveal_position = function(line, col, winid)
  winid = winid or 0
  local position = { line + 1, col }
  vim.api.nvim_win_set_cursor(winid, position)
  vim.api.nvim_win_call(winid, function()
    vim.cmd("normal! zvzz") -- expand folds and center cursor
  end)
end

local open_with_cmd = function(state, open_cmd, toggle_directory, open_file)
  local tree = state.tree
  local success, node = pcall(tree.get_node, tree)
  if node.type == "message" then
    return
  end
  if not (success and node) then
    log.debug("Could not get node.")
    return
  end

  local function open()
    local path = node.path
    if type(open_file) == "function" then
      open_file(state, path, open_cmd)
    else
      utils.open_file(state, path, open_cmd)
    end
  end

  if node.type == "diagnostic" then
    local diag = node.extra.diag_struct
    open()
    reveal_position(diag.lnum, diag.col)
  elseif utils.is_expandable(node) then
    if toggle_directory and node.type == "directory" then
      toggle_directory(node)
    elseif node:has_children() then
      local updated = false
      if node:is_expanded() then
        updated = node:collapse()
      else
        updated = node:expand()
      end
      if updated then
        renderer.redraw(state)
      end
    end
  end
end

---Open file or directory in the closest window
---@param state table The state of the source
---@param toggle_directory function The function to call to toggle a directory
---open/closed
M.open = function(state, toggle_directory)
  open_with_cmd(state, "e", toggle_directory)
end

---Open file or directory in a split of the closest window
---@param state table The state of the source
---@param toggle_directory function The function to call to toggle a directory
---open/closed
M.open_split = function(state, toggle_directory)
  open_with_cmd(state, "split", toggle_directory)
end

---Open file or directory in a vertical split of the closest window
---@param state table The state of the source
---@param toggle_directory function The function to call to toggle a directory
---open/closed
M.open_vsplit = function(state, toggle_directory)
  open_with_cmd(state, "vsplit", toggle_directory)
end

---Open file or directory in a new tab
---@param state table The state of the source
---@param toggle_directory function The function to call to toggle a directory
---open/closed
M.open_tabnew = function(state, toggle_directory)
  open_with_cmd(state, "tabnew", toggle_directory)
end

M.refresh = refresh

M.rename = function(state)
  cc.rename(state, refresh)
end

---Marks potential windows with letters and will open the give node in the picked window.
---@param state table The state of the source
---@param path string The path to open
---@param cmd string Command that is used to perform action on picked window
local use_window_picker = function(state, path, cmd)
  local success, picker = pcall(require, "window-picker")
  if not success then
    print(
      "You'll need to install window-picker to use this command: https://github.com/s1n7ax/nvim-window-picker"
    )
    return
  end
  local picked_window_id = picker.pick_window()
  if picked_window_id then
    vim.api.nvim_set_current_win(picked_window_id)
    vim.cmd(cmd .. ' ' .. vim.fn.fnameescape(path))
  end
end

---Marks potential windows with letters and will open the give node in the picked window.
M.open_with_window_picker = function(state, toggle_directory)
  open_with_cmd(state, 'edit', toggle_directory, use_window_picker)
end

---Marks potential windows with letters and will open the give node in a split next to the picked window.
M.split_with_window_picker = function(state, toggle_directory)
  open_with_cmd(state, 'split', toggle_directory, use_window_picker)
end

---Marks potential windows with letters and will open the give node in a vertical split next to the picked window.
M.vsplit_with_window_picker = function(state, toggle_directory)
  open_with_cmd(state, 'vsplit', toggle_directory, use_window_picker)
end

cc._add_common_commands(M)

return M
