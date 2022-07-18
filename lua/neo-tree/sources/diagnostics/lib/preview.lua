local vim = vim
local utils = require("neo-tree.utils")
local highlights = require("neo-tree.ui.highlights")

local neo_tree_preview = vim.api.nvim_create_namespace("neo_tree_preview")

Preview = {}

---Creates a new preview.
---@param state table The state of the source.
---@return table preview A new preview. A preview is a table consisting of the following keys:
--  active = boolean           Whether the preview is active.
--  winid = number             The id of the window being used to preview.
--  is_neo_tree_window boolean Whether the preview window belongs to neo-tree.
--  bufnr = number             The buffer that is currently in the preview window.
--  start_loc = array or nil   An array-like table specifying the (0-indexed) starting location of the previewed text.
--  end_loc = array or nil     An array-like table specifying the (0-indexed) ending location of the preview text.
--  truth = table              A table containing information to be restored when the preview ends.
--These keys should not be altered directly. Note that the keys `start`, `end` and `truth`
--may be inaccurate if `active` is false.
function Preview:new(state)
  local preview = {}
  preview.active = false
  setmetatable(preview, { __index = self })
  preview:findWindow(state)
  return preview
end

---Preview a buffer in the preview window and optionally reveal and highlight the previewed text.
---@param bufnr number? The number of the buffer to be previewed.
---@param start_loc table? The (0-indexed) starting location of the previewed text. May be absent.
---@param end_loc table? The (0-indexed) ending location of the previewed text. May be absent
function Preview:preview(bufnr, start_loc, end_loc)
  bufnr = bufnr or self.bufnr
  if not self.active then
    self:activate()
  end

  if bufnr ~= self.bufnr then
    vim.api.nvim_win_set_buf(self.winid, bufnr)
  end

  self:clearHighlight()

  self.bufnr = bufnr
  self.start_loc = start_loc
  self.end_loc = end_loc

  self:reveal()
  self:highlight()
end

---Reverts the preview and inactivates it, restoring the preview window to the true buffer.
function Preview:revert()
  self.active = false
  self:clearHighlight()

  if not vim.api.nvim_win_is_valid(self.winid) then
    return
  end

  local bufnr = self.truth.bufnr
  self.bufnr = bufnr
  vim.api.nvim_win_set_buf(self.winid, bufnr)
  vim.api.nvim_win_call(self.winid, function()
    vim.fn.winrestview(self.truth.view)
  end)
  vim.api.nvim_buf_set_option(self.bufnr, "bufhidden", self.truth.options.bufhidden)
  vim.api.nvim_win_set_option(self.winid, "foldenable", self.truth.options.foldenable)
end

---Finds the appropriate window and updates the preview accordingly.
---@param state table The state of the source.
function Preview:findWindow(state)
  local winid, is_neo_tree_window = utils.get_appropriate_window(state)
  if winid == self.winid then
    return
  end

  if self.active then
    self:revert()
    self.winid, self.is_neo_tree_window = winid, is_neo_tree_window
    self:preview()
  else
    self.winid, self.is_neo_tree_window = winid, is_neo_tree_window
    self.bufnr = vim.api.nvim_win_get_buf(self.winid)
  end
end

---Activates the preview, but does not populate the preview window,
function Preview:activate()
  if self.active then
    return
  end
  self.truth = {
    bufnr = self.bufnr,
    view = vim.api.nvim_win_call(self.winid, vim.fn.winsaveview),
    options = {
      bufhidden = vim.api.nvim_buf_get_option(self.bufnr, "bufhidden"),
      foldenable = vim.api.nvim_win_get_option(self.winid, "foldenable")
    },
  }
  vim.api.nvim_buf_set_option(self.bufnr, "bufhidden", "hide")
  vim.api.nvim_win_set_option(self.winid, "foldenable", false)
  self.active = true
end

---Move the cursor to the previewed location and center the screen.
function Preview:reveal()
  local loc = self.start_loc or self.end_loc
  if not self.active or not self.winid or not loc then
    return
  end
  vim.api.nvim_win_set_cursor(self.winid, { loc[1] + 1, loc[2] })
  vim.api.nvim_win_call(self.winid, function()
    vim.cmd("normal! zz")
  end)
end

---Highlight the previewed range
function Preview:highlight()
  if not self.active or not self.bufnr then
    return
  end
  local start_loc, end_loc = self.start_loc, self.end_loc
  if not start_loc and not end_loc then
    return
  elseif not start_loc then
    start_loc = end_loc
  elseif not end_loc then
    end_loc = start_loc
  end

  local highlight = function(line, col_start, col_end)
    vim.api.nvim_buf_add_highlight(
      self.bufnr,
      neo_tree_preview,
      highlights.PREVIEW,
      line,
      col_start,
      col_end
    )
  end

  local start_line, end_line = start_loc[1], end_loc[1]
  local start_col, end_col = start_loc[2], end_loc[2]
  if start_line == end_line then
    highlight(start_line, start_col, end_col)
  else
    highlight(start_line, start_col, -1)
    for line = start_line + 1, end_line - 1 do
      highlight(line, 0, -1)
    end
    highlight(end_line, 0, end_col)
  end
end

---Clear the preview highlight in the buffer currently in the preview window.
function Preview:clearHighlight()
  vim.api.nvim_buf_clear_namespace(self.bufnr, neo_tree_preview, 0, -1)
end

return Preview
