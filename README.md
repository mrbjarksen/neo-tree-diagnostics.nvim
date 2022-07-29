# neo-tree-diagnostics

An extension for [neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim)
implementing a source for viewing workspace diagnostics.

![neo-tree-diagnostics](https://user-images.githubusercontent.com/62466569/181661222-8548e37d-d5d2-4f44-938f-39789ff9d4dc.png)

## Installation

Installing this plugin should be possible using your package manager of choice,
assuming neo-tree.nvim has been installed.
The following uses [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "mrbjarksen/neo-tree-diagnostics.nvim",
  requires = "nvim-neo-tree/neo-tree.nvim",
  module = "neo-tree.sources.diagnostics", -- if wanting to lazyload
}
```

## Configuration

Configuration is done within the neo-tree config:

```lua
require("neo-tree").setup({
  sources = {
    "filesystem",
    "buffers",
    "git_status",
    "diagnostics",
    -- ...and any additional source
  },
  -- These are the defaults
  diagnostics = {
    bind_to_cwd = true,
    diag_sort_function = "severity", -- "severity" means diagnostic items are sorted by severity in addition to their positions.
                                     -- "position" means diagnostic items are sorted strictly by their positions.
                                     -- May also be a function.
    follow_behavior = { -- Behavior when `follow_current_file` is true
      always_focus_file = false, -- Focus the followed file, even when focus is currently on a diagnostic item belonging to that file.
      expand_followed = true, -- Ensure the node of the followed file is expanded
      collapse_others = true, -- Ensure other nodes are collapsed
    },
    follow_current_file = true,
    group_dirs_and_files = true, -- when true, empty folders and files will be grouped together
    group_empty_dirs = true, -- when true, empty directories will be grouped together
    show_unloaded = true, -- show diagnostics from unloaded buffers
  },
})
```

For information on customizing components and renderers, see the [wiki](https://github.com/mrbjarksen/neo-tree-diagnostics.nvim/wiki/Components-and-renderers).

## Usage

The recommended command to use is the following:

```
:Neotree diagnostics reveal bottom
```

