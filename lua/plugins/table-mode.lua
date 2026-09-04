-- lua/plugins/table-mode.lua
-- vim-table-mode: auto-aligning markdown/text tables

-- Fill current cell with the contents of the cell directly above, on both
-- <Leader>t' and ⌘' (the latter matching Excel's "fill down from cell
-- above" muscle memory) in Normal mode — ⌘' also works in Insert mode,
-- wired up in AG-table-augmentation.lua alongside its own Tab/S-Tab/C-l.
-- ⌘' only ever fires in VimR/MacVim — true Cmd can't reach terminal
-- Neovim at all (see the <D-...> discussion in
-- AG-display-line-based-navigation.lua) — so <Leader>t' remains the only
-- way to trigger this over iTerm2; ⌘' is purely an added shortcut there,
-- not a replacement.
--
-- The implementation itself lives in AG-table-augmentation.lua (see its
-- "fill cell from the cell above" section for the full mechanism), not
-- here, for the same reason table_smart_tab/table_realign_preserving_cursor
-- live there: that file exists specifically so custom behavior survives
-- plugin updates. Required rather than defined locally so both this
-- file's Normal-mode entries and that file's Insert-mode one share the
-- exact same function object instead of maintaining separate copies.
local fill_cell_from_above = require('config.AG-table-augmentation').fill_cell_from_above

return {
  "dhruvasagar/vim-table-mode",
  ft = { "markdown", "text" },  -- lazy-load only for relevant filetypes
  init = function()
    -- Use pipe syntax with markdown-compatible corners (|---|---|)
    vim.g.table_mode_corner = "|"

    -- Character used to separate columns while typing (before alignment)
    vim.g.table_mode_separator = "|"

    -- Auto-align table as you type (set to 0 if you find it too aggressive)
    vim.g.table_mode_auto_align = 1

    -- Realign on every keystroke inside a table; can be slow on huge tables
    vim.g.table_mode_update_time = 500

    -- Remap the leader used for table-mode-specific commands
    -- Default is <Leader>t; change if that collides with your existing mappings
    vim.g.table_mode_map_prefix = "<Leader>t"

    -- Enable formula support (e.g. =SUM(a1:a3)) evaluated with <Leader>t=
    vim.g.table_mode_enable_tableize_dquote = 1
  end,
  keys = {
    -- Toggle table mode manually (also auto-activates on typing '|' at line start
    -- if table_mode_auto_align picks it up, but explicit toggle is more reliable)
    { "<Leader>tm", "<cmd>TableModeToggle<CR>", desc = "Toggle Table Mode" },

    -- Tableize a visual selection of tab- or comma-separated text into a table
    { "<Leader>tt", ":Tableize<CR>", mode = "v", desc = "Tableize Selection" },

    -- Realign the current table manually
    { "<Leader>tr", "<cmd>TableModeRealign<CR>", desc = "Realign Table" },

    -- Copy current cell's contents to the system clipboard. Targets "+
    -- explicitly rather than relying on 'clipboard=unnamedplus' (set in
    -- init.lua) so this stays correct even if that global setting changes.
    -- remap = true: i| is vim-table-mode's own buffer-local recursive
    -- mapping (nmap <buffer> i| <Plug>(table-mode-cell-text-object-i)),
    -- so our own mapping must allow it to be triggered rather than falling
    -- through to raw i/| as builtins (same class of bug as the earlier
    -- Tab/S-Tab and Home/End fixes this session).
    { "<Leader>tc", '"+yi|', remap = true, desc = "Copy cell to clipboard" },

    -- Replace cell contents: delete the cell's content and drop into
    -- Insert mode to type a replacement, same as ci| directly. remap =
    -- true for the same reason as above.
    { "<Leader>tR", "ci|", remap = true, desc = "Replace cell contents" },

    -- Fill current cell from the cell above — see fill_cell_from_above's
    -- own comment (top of file) for the mechanism and why it's a shared
    -- function. Two independent keys entries, same function object.
    { "<Leader>t'", fill_cell_from_above, desc = "Fill cell from cell above" },
    { "<D-'>", fill_cell_from_above, desc = "Fill cell from cell above (⌘', Excel-style)" },
  },
}
