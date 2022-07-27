local highlights = require("neo-tree.ui.highlights")
local vim = vim

local M = {}

M.TOTAL_COUNT = "NeoTreeDiagTotalCount"
M.GROUPED_PATH = "NeoTreeDiagGroupedPath"
M.POSITION = "NeoTreeDiagPosition"
M.SEVERITY_NUMBER = "NeoTreeDiagSeverityNumber"
M.MESSAGE = "NeoTreeDiagMessage"
M.SOURCE = "NeoTreeDiagSource"
M.CODE = "NeoTreeDiagCode"

M.setup = function()
  local create_highlight_group = highlights.create_highlight_group

  create_highlight_group(M.TOTAL_COUNT, { "TabLineSel" })
  create_highlight_group(M.GROUPED_PATH, { highlights.DIRECTORY_NAME, "Directory" })
  create_highlight_group(M.POSITION, { "LineNr" })
  create_highlight_group(M.SEVERITY_NUMBER, { "SpecialChar" })
  create_highlight_group(M.MESSAGE, { highlights.NORMAL, "Normal" })
  create_highlight_group(M.SOURCE, { highlights.MESSAGE, "Comment" })
  create_highlight_group(M.CODE, { highlights.MESSAGE, "Comment" })
end

return M
