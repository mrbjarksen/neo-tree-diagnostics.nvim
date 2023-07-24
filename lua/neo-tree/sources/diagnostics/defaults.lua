local config = {
  auto_preview = { -- May also be set to `true`
    enabled = false, -- Whether to automatically enable preview mode
    preview_config = {}, -- Config table to pass to auto preview (for example `{ use_float = true }`)
    event = "neo_tree_buffer_enter", -- The event to enable auto preview upon (for example `"neo_tree_window_after_open"`)
  },
  bind_to_cwd = true,
  diag_sort_function = "severity", -- "severity" means diagnostic items are sorted by severity in addition to their positions
                                   -- "position" means diagnostic items are sorted strictly by their positions
                                   -- May also be a function
  follow_behavior = { -- Behavior when `follow_current_file` is true
    always_focus_file = false, -- Focus the followed file, even when focus is currently on a diagnostic item belonging to that file
    expand_followed = true, -- Ensure the node of the followed file is expanded
    collapse_others = true, -- Ensure other nodes are collapsed
  },
  follow_current_file = true,
  group_dirs_and_files = true, -- when true, empty folders and files will be grouped together
  group_empty_dirs = true, -- when true, empty directories will be grouped together
  show_unloaded = true, -- show diagnostics from unloaded buffers
  refresh = {
    delay = 100, -- Time (in ms) to wait before updating diagnostics. Might resolve some issues with Neovim hanging.
    event = "vim_diagnostic_changed", -- Event to use for updating diagnostics (for example `"neo_tree_buffer_enter"`)
                                      -- Set to `false` or `"none"` to disable automatic refreshing
    max_items = false, -- The maximum number of diagnostic items to attempt processing
                       -- Set to `false` for no maximum
  },
  renderers = {
    file = {
      { "indent" },
      { "icon" },
      { "grouped_path" },
      { "name" },
      { "diagnostic_count", show_when_none = true },
      { "split_diagnostic_counts", left_padding = 1 },
      { "clipboard" },
    },
    diagnostic = {
      { "indent" },
      { "icon" },
      { "message" },
      { "source" },
      { "code" },
      { "position" },
    },
  },
  window = {
    mappings = {},
  },
}

return config
