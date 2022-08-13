--This file should contain all commands meant to be used by mappings.

local vim = vim
local cc = require("neo-tree.sources.common.commands")
local diagnostics = require("neo-tree.sources.diagnostics")
local utils = require("neo-tree.utils")
local manager = require("neo-tree.sources.manager")

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

M.refresh = refresh

M.rename = function(state)
  cc.rename(state, refresh)
end

cc._add_common_commands(M)

return M
