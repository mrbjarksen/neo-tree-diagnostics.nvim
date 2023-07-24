-- This file contains the built-in components. Each componment is a function
-- that takes the following arguments:
--      config: A table containing the configuration provided by the user
--              when declaring this component in their renderer config.
--      node:   A NuiNode object for the currently focused node.
--      state:  The current state of the source providing the items.
--
-- The function should return either a table, or a list of tables, each of which
-- contains the following keys:
--    text:      The text to display for this item.
--    highlight: The highlight group to apply to this text.

local highlights = require("neo-tree.ui.highlights")
local diag_highlights = require("neo-tree.sources.diagnostics.highlights")
local common = require("neo-tree.sources.common.components")
local utils = require("neo-tree.utils")
local vim = vim

local spaces = function(n)
  return string.rep(" ", n)
end

local create_component = function(parts, default_highlight)
  local component = {}
  for _, part in pairs(parts) do
    if type(part) == "string" and part ~= "" then
      part = {
        text = part,
        highlight = default_highlight
      }
    elseif type(part) == "table" and utils.truthy(part.text) then
      part = {
        text = part.text,
        highlight = part.highlight or default_highlight
      }
    end

    if type(part) == "table" and part.text and part.highlight then
      local last = component[#component]
      if last and part.highlight == last.highlight then
        last.text = last.text .. part.text
      else
        component[#component+1] = part
      end
    end
  end

  if #component == 1 then
    return component[1]
  else
    return component
  end
end

local diag_severity_to_string = function(severity)
  if severity == vim.diagnostic.severity.ERROR then
    return "Error"
  elseif severity == vim.diagnostic.severity.WARN then
    return "Warn"
  elseif severity == vim.diagnostic.severity.INFO then
    return "Info"
  elseif severity == vim.diagnostic.severity.HINT then
    return "Hint"
  else
    return nil
  end
end

local get_diag_icon = function(config, severity)
  if severity == nil or severity == "all" then
    return {}
  end

  local defined = vim.fn.sign_getdefined("DiagnosticSign" .. severity)
  if #defined == 0 then
    -- backwards compatibility...
    local old_severity = severity
    if severity == "Warning" then
      old_severity = "Warn"
    elseif severity == "Information" then
      old_severity = "Info"
    end
    defined = vim.fn.sign_getdefined("LspDiagnosticsSign" .. old_severity)
  end
  defined = defined and defined[1] or {}
  defined.text = defined.text and defined.text:gsub("%s*$", "")

  local fallback = {
    text = severity:sub(1, 1),
    highlight = "DiagnosticSign" .. severity,
  }

  local override = {
    text = config.symbols and config.symbols[severity:lower()],
    highlight = config.highlights and config.highlights[severity:lower()],
  }

  return {
    text = override.text or defined.text or fallback.text,
    highlight = override.highlight or defined.texthl or fallback.highlight,
  }
end

local M = {}

M.diagnostic_count = function(config, node, state)
  local severity = config.severity or "all"
  local icon = get_diag_icon(config, severity)
  local highlight = config.highlight or icon.highlight or diag_highlights.TOTAL_COUNT

  if node.path == nil then
    return {}
  end

  local diag_counts = state.diagnostics_lookup[node.path]
  if diag_counts == nil then
    return {}
  end

  local count = 0
  if severity == "all" then
    for _, sev in ipairs({ "Error", "Warn", "Info", "Hint" }) do
      count = count + (diag_counts[sev] or 0)
    end
  else
    count = diag_counts[severity] or 0
  end
  if count == 0 and not config.show_when_none then
    return {}
  end

  local icon_padding = config.icon_padding or 1
  local icon_text = icon.text and (icon.text .. spaces(icon_padding)) or ""

  local text = icon_text .. count

  local left_padding = config.left_padding or 1
  local right_padding = config.right_padding or 1
  text = spaces(left_padding) .. text .. spaces(right_padding)

  return {
    text = text,
    highlight = highlight,
  }
end

M.split_diagnostic_counts = function(config, node, state)
  local conf = vim.deepcopy(config)

  local severities = conf.severities or { "Error", "Warn", "Info", "Hint" }
  local left_padding = conf.left_padding or 0
  local right_padding = conf.right_padding or 0
  local between = conf.between or " "

  conf.left_padding = 0
  conf.right_padding = 0

  local components = { spaces(left_padding) }
  for _, sev in ipairs(severities) do
    conf.severity = sev
    local component = M.diagnostic_count(conf, node, state)
    if component.text and component.text ~= "" then
      components[#components+1] = component
      components[#components+1] = between
    end
  end
  components[#components] = spaces(right_padding)

  if #components == 1 then
    return {}
  end

  return create_component(components, config.highlight or highlights.DIM_TEXT)
end

M.grouped_path = function(config, node, state)
  local highlight = config.highlight or diag_highlights.GROUPED_PATH
  local grouped_path = node.extra and node.extra.grouped_path
  local no_next_padding = config.no_next_padding
  if no_next_padding == nil then
    no_next_padding = true
  end
  if grouped_path == nil then
    return {}
  else
    return {
      text = grouped_path,
      highlight = highlight,
      no_next_padding = no_next_padding,
    }
  end
end

M.icon = function(config, node, state)
  if node.type ~= "diagnostic" then
    return common.icon(config, node, state)
  end

  local diag = node.extra.diag_struct
  local severity = diag_severity_to_string(diag.severity)

  local left_padding = config.left_padding or 0
  local right_padding = config.right_padding or 2
  local icon = get_diag_icon(config, severity)
  icon.text = icon.text or ""
  icon.text = spaces(left_padding) .. icon.text .. spaces(right_padding)

  return icon
end

M.name = function(config, node, state)
  if node.type == "diagnostic" then
    return M.message(config, node, state)
  end
  local highlight = config.highlight or highlights.FILE_NAME_OPENED
  local name = node.name
  if node.type == "directory" then
    if node:get_depth() == 1 then
      highlight = highlights.ROOT_NAME
      name = "DIAGNOSTICS in " .. name
    else
      highlight = highlights.DIRECTORY_NAME
    end
  end
  return {
    text = name .. " ",
    highlight = highlight,
  }
end

M.position = function(config, node, state)
  local highlight = config.highlight or diag_highlights.POSITION
  local diag = node.extra.diag_struct
  local lnum, col = diag.lnum + 1, diag.col + 1
  local left = config.left or "["
  local middle = config.middle or ", "
  local right = config.right or "]"

  return create_component({
    left, tostring(lnum), middle, tostring(col), right
  }, highlight)
end

M.bufnr = function(config, node, state)
  local highlight = config.highlight or highlights.BUFFER_NUMBER
  local bufnr = node.extra.diag_struct.bufnr
  if not bufnr then
    return {}
  end

  local left = config.left or "#"
  local right = config.right or ""

  local min_width = config.min_width or 0
  bufnr = string.format("%" .. min_width .. "d", bufnr)

  return create_component({ left, bufnr, right }, highlight)
end

M.lnum = function(config, node, state)
  local highlight = config.highlight or diag_highlights.POSITION
  local lnum = tostring(node.extra.diag_struct.lnum + 1)
  local left, right = config.left or "", config.right or ""

  local min_width = config.min_width or 0
  lnum = string.format("%" .. min_width .. "d", lnum)

  return create_component({ left, tostring(lnum), right }, highlight)
end

M.end_lnum = function(config, node, state)
  local highlight = config.highlight or diag_highlights.POSITION
  local end_lnum = node.extra.diag_struct.end_lnum
  local left, right = config.left or {}, config.right or {}
  if not end_lnum then
    return {}
  else
    end_lnum = end_lnum + 1
  end

  local min_width = config.min_width or 0
  end_lnum = string.format("%" .. min_width .. "d", end_lnum)

  return create_component({ left, end_lnum, config }, highlight)
end

M.col = function(config, node, state)
  local highlight = config.highlight or diag_highlights.POSITION 
  local col = tostring(node.extra.diag_struct.col + 1)
  local left, right = config.left or "", config.right or ""

  local min_width = config.min_width or 0
  col = string.format("%" .. min_width .. "d", col)

  return create_component({ left, tostring(col), right }, highlight)
end

M.end_col = function(config, node, state)
  local highlight = config.highlight or diag_highlights.POSITION
  local end_col = node.extra.diag_struct.end_col
  local left, right = config.left or "", config.right or ""
  if not end_col then
    return {}
  else
    end_col = end_col + 1
  end

  local min_width = config.min_width or 0
  end_col = string.format("%" .. min_width .. "d", end_col)

  return create_component({ left, tostring(end_col), right }, highlight)
end

M.severity = function(config, node, state)
  local highlight = config.highlight or diag_highlights.SEVERITY_NUMBER
  local severity = node.extra.diag_struct.severity
  local left, right = config.left or "", config.right or ""
  if not severity then
    return {}
  end

  return create_component({ left, tostring(severity), right }, highlight)
end

M.message = function(config, node, state)
  local highlight = config.highlight or diag_highlights.MESSAGE
  local message = node.extra.diag_struct.message
  local left = config.left or ""
  local right = config.right or " "

  return create_component({ left, message, right }, highlight)
end

M.source = function(config, node, state)
  local highlight = config.highlight or diag_highlights.SOURCE
  local source = node.extra.diag_struct.source
  local left = config.left or ""
  local right = config.right or " "
  if not source then
    return {}
  end

  return create_component({ left, source, right }, highlight)
end

M.code = function(config, node, state)
  local highlight = config.highlight or diag_highlights.CODE
  local code = node.extra.diag_struct.code
  local left = config.left or "("
  local right = config.right or ") "

  if not code then
    return {}
  end

  return create_component({ left, code, right }, highlight)
end

return vim.tbl_deep_extend("force", common, M)
