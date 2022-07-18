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
local common = require("neo-tree.sources.common.components")
local utils = require("neo-tree.utils")

local spaces = function(n)
  return string.rep(" ", n)
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

local get_diag_icon = function(severity, right_padding)
  if severity == nil then
    return {}
  end

  right_padding = right_padding or 1

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
  defined.text = defined.text and defined.text:gsub("%s+$", spaces(right_padding))

  local fallback = {
    text = severity:sub(1, 1) .. spaces(right_padding),
    highlight = "DiagnosticSign" .. severity,
  }

  return {
    text = defined.text or fallback.text,
    highlight = defined.texthl or fallback.highlight,
  }
end

local M = {}

M.code = function(config, node, state)
  local highlight = config.highlight or highlights.DIAG_CODE or "Comment"
  local code = node.extra.diag_struct.code
  if not code then
    return {}
  else
    return {
      text = "(" .. code .. ") ",
      highlight = highlight,
    }
  end
end

M.diagnostic_count = function(config, node, state)
  local severity = config.severity
  local icon = get_diag_icon(severity)
  local highlight = config.highlight or icon.highlight or highlights.DIAG_COUNT or "TabLineSel"

  if node.path == nil then
    return {}
  end

  local diag_counts = state.diagnostics_lookup[node.path]
  if diag_counts == nil then
    return {}
  end

  local count = 0
  if severity == nil then
    for _, sev in ipairs({ "Error", "Warn", "Info", "Hint", "Other" }) do
      count = count + (diag_counts[sev] or 0)
    end
  else
    count = diag_counts[severity] or 0
  end
  if count == 0 and not config.show_when_none then
    return {}
  end

  local icon_padding = config.icon_padding or 1
  local icon_text = icon.text and icon.text:gsub("%s+$", spaces(icon_padding)) or ""

  local text = icon_text .. count

  local left_padding = config.left_padding or 1
  local right_padding = config.right_padding or 1
  local text = spaces(left_padding) .. text .. spaces(right_padding)

  return {
    text = text,
    highlight = highlight,
  }
end

M.grouped_path = function(config, node, state)
  local highlight = config.highlight or highlights.DIRECTORY_NAME
  local grouped_path = node.extra and node.extra.grouped_path
  if grouped_path == nil then
    return {}
  else
    return {
      text = grouped_path,
      highlight = highlight,
    }
  end
end

M.icon = function(config, node, state)
  if node.type ~= "diagnostic" then
    return common.icon(config, node, state)
  end

  local diag = node.extra.diag_struct
  local severity = diag_severity_to_string(diag.severity)

  return get_diag_icon(severity)
end

M.position = function(config, node, state)
  local highlight = config.highlight or highlights.DIAG_POSITION or "LineNr"
  local diag = node.extra.diag_struct
  local lnum, col = diag.lnum + 1, diag.col + 1
  return {
    text = "[" .. lnum .. ", " .. col .. "]",
    highlight = highlight,
  }
end

M.name = function(config, node, state)
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

M.source = function(config, node, state)
  local highlight = config.highlight or highlights.DIAG_SOURCE or "Comment"
  local source = node.extra.diag_struct.source
  if not source then
    return {}
  else
    return {
      text = source .. " ",
      highlight = highlight,
    }
  end
end

return vim.tbl_deep_extend("force", common, M)
