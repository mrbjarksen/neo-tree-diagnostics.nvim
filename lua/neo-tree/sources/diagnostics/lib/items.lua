local vim = vim
local renderer = require("neo-tree.ui.renderer")
local utils = require("neo-tree.utils")
local file_items = require("neo-tree.sources.common.file-items")
local log = require("neo-tree.log")

local M = {}

local diag_struct_to_item = function(diag)
  local path = vim.api.nvim_buf_get_name(diag.bufnr or 0)
  local lines = tostring(diag.lnum + 1)
  if diag.end_lnum ~= nil then
    lines = lines .. "-" .. (diag.end_lnum + 1)
  end
  local cols = tostring(diag.col)
  if diag.end_col ~= nil then
    cols = cols .. "-" .. (diag.end_col + 1)
  end
  return {
    id = path .. ":" .. lines .. ":" .. cols .. ":" .. diag.message,
    name = diag.message,
    path = path,
    type = "diagnostic",
    extra = { diag_struct = diag },
  }
end

local group_dirs_and_files
group_dirs_and_files = function(node, is_root)
  if node.type ~= "directory" or node.children == nil then
    return node
  end

  for i, child in ipairs(node.children) do
    node.children[i] = group_dirs_and_files(child)
  end

  if #node.children ~= 1 then
    return node
  end

  local child = node.children[1]
  if child.type ~= "file" then
    return node
  end

  if not is_root then
    child.extra = child.extra or {}
    child.extra.grouped_path = child.extra.grouped_path or ""
    child.extra.grouped_path = node.name .. utils.path_separator .. child.extra.grouped_path
    return child
  end

  return node
end

local compare_position = function(line_a, col_a, line_b, col_b)
  if line_a == nil or col_a == nil or line_b == nil or col_b == nil then
    return false
  end
  if line_a == line_b then
    if col_a == col_b then
      return nil 
    else
      return col_a < col_b
    end
  else
    return line_a < line_b
  end
end

local diag_sort_func = function(mode, a, b)
  local ad, bd = a.extra.diag_struct, b.extra.diag_struct
  if mode == "severity" and ad.severity and bd.severity then
    if ad.severity ~= bd.severity then
      return ad.severity < bd.severity
    end
  end
  local start_compare = compare_position(ad.lnum, ad.col, bd.lnum, bd.col)
  if start_compare == nil then
    return compare_position(ad.end_lnum, ad.end_col, ad.end_lnum, ad.end_col)
  else
    return start_compare
  end
end

M.get_diagnostics = function(state)
  if state.loading then
    return
  end
  state.loading = true

  local context = file_items.create_context(state)
  local root = file_items.create_item(context, state.path, "directory")
  root.name = vim.fn.fnamemodify(root.path, ":~")
  root.loaded = true
  root.search_pattern = state.search_pattern
  context.folders[root.path] = root

  local diag_items_by_buffer = {}
  for _, diag in ipairs(vim.diagnostic.get()) do
    local bufnr = diag.bufnr
    if bufnr ~= nil then
      local diag_item = diag_struct_to_item(diag)
      if diag_items_by_buffer[bufnr] == nil then
        diag_items_by_buffer[bufnr] = {}
      end
      table.insert(diag_items_by_buffer[bufnr], diag_item)
    end
  end

  for bufnr, diag_items in pairs(diag_items_by_buffer) do
    local path = vim.api.nvim_buf_get_name(bufnr)
    local rootstub = path:sub(1, #state.path)
    if rootstub == state.path then
      local is_loaded = vim.api.nvim_buf_is_loaded(bufnr)
      if is_loaded or state.show_unloaded then
        local success, item = pcall(file_items.create_item, context, path, "file")
        if success then
          local sort_func
          if type(state.diag_sort_function) == "function" then
            sort_func = state.diag_sort_function
          else
            if not vim.tbl_contains({ "severity", "position" }, state.diag_sort_function) then
              log.debug('Value for diag_sort_function not recognized. Falling back to "severity"')
              state.diag_sort_function = "severity"
            end
            -- NOTE: using utils.wrap here does not work, since
            -- the resulting function does not return anything. 
            sort_func = function(a, b)
              return diag_sort_func(state.diag_sort_function, a, b)
            end
          end
          table.sort(diag_items, sort_func)
          item.children = diag_items
        else
          log.error("Error creating item for " .. path .. ": " .. item)
        end
      end
    end
  end

  if state.group_dirs_and_files then
    root = group_dirs_and_files(root, true)
  end

  state.diagnostics_lookup = utils.get_diagnostic_counts()

  local root_nodes = { root }

  state.default_expanded_nodes = {}
  for id, _ in pairs(context.folders) do
    table.insert(state.default_expanded_nodes, id)
  end
  if state.position and state.position.node_id then
    table.insert(state.default_expanded_nodes, state.position.node_id)
  end

  file_items.deep_sort(root.children)
  renderer.show_nodes(root_nodes, state)
  state.loading = false
end

return M
