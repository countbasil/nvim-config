-- lua/plugins/table-mode.lua
-- vim-table-mode: auto-aligning markdown/text tables

-- Fill current cell with the contents of the cell directly above, on both
-- <Leader>t' and ⌘' (the latter matching Excel's "fill down from cell
-- above" muscle memory). ⌘' only ever fires in VimR/MacVim — true Cmd
-- can't reach terminal Neovim at all (see the <D-...> discussion in
-- AG-display-line-based-navigation.lua) — so <Leader>t' remains the only
-- way to trigger this over iTerm2; ⌘' is purely an added shortcut there,
-- not a replacement. A plain local function, not a table value, so both
-- keymap entries below wire up to the exact same function object instead
-- of two independent copies.
--
-- A Lua function rather than a raw keystroke string: yanking with yi|
-- moves the cursor to the start of whatever it just yanked, so a naive
-- "{|"zyi|}| round trip lands back on the wrong cell (}|'s cell
-- resolution isn't simply "same column, next line" once the cursor's
-- shifted) — caught via headless testing when it filled the wrong
-- column. Recording the exact (line, col) before moving and forcibly
-- restoring it with nvim_win_set_cursor sidesteps relying on any motion
-- to "return" correctly.
--
-- Uses `:normal` (no bang) rather than `:normal!`: the bang form
-- bypasses ALL custom mappings, including vim-table-mode's own
-- buffer-local {|/i| Plug mappings, which would silently no-op —
-- different from e.g. delete_display_line's use of `normal! g0` in
-- AG-display-line-based-navigation.lua, where bypassing mappings to
-- reach the true builtin g0 is exactly what's wanted there.
--
-- Register z (not ""/"+) so this doesn't clobber the clipboard the way
-- <Leader>tc's yank intentionally does. The change operator's own delete
-- also writes to the unnamed register regardless of z, which with
-- 'clipboard=unnamedplus' (init.lua) leaks to the system clipboard too —
-- caught via headless testing. "_ci| (black hole register) discards the
-- old cell content without writing it anywhere, unlike <Leader>tR's
-- plain ci|, where leaving the replaced text in the unnamed register is
-- normal, expected c-operator behavior, not something to guard against.
-- ci|<C-r>z within one :normal call (not two) so the register paste
-- happens while still in the Insert mode ci| entered — :normal
-- implicitly exits Insert mode at the end of its own execution, which is
-- exactly the desired final state here (unlike <Leader>tR, which
-- deliberately stays in Insert mode and so is a plain keymap rather than
-- a :normal call).
local function fill_cell_from_above()
  local lnum = vim.fn.line('.')

  -- If the cursor is sitting exactly ON a separator, nudge it into
  -- the cell that separator opens (2 columns right — the same
  -- "start of cell" convention MoveToStartOfCell/Tab's new-cell
  -- placement already use), not the cell it closes. Moving left
  -- instead was tried first and confirmed wrong via live use: for
  -- an interior separator that lands in the PRIOR cell, not the
  -- next one. Right is also correct for the row's leading pipe
  -- (resolves to cell 1 either way), so no special-case needed
  -- there. No guard against running past the row's closing pipe —
  -- `2l`-equivalent motion just stops at end of line rather than
  -- erroring, and closing the cell text object's own forward
  -- search handles the rest.
  local col = vim.fn.col('.')
  if vim.fn.getline(lnum):sub(col, col) == '|' then
    vim.api.nvim_win_set_cursor(0, { lnum, col + 1 })
  end

  -- Which cell (by index, not byte column) the cursor is in, so it
  -- can be relocated by column index rather than trusting a raw
  -- byte column that realign below may invalidate.
  local cursor_col_nr = vim.fn['tablemode#spreadsheet#ColumnNr']('.')

  -- Ensure the current row has a proper closing pipe before
  -- touching the i| text object. Without one, the text object's
  -- forward search for the next separator can fail to find one on
  -- this line at all, and with 'wrapscan' on by default, wraps onto
  -- unrelated lines instead — confirmed via headless testing to
  -- corrupt the whole table (3 lines collapsed into one mangled
  -- line), not just misbehave locally.
  local line = vim.fn.getline(lnum)
  local closed_pipe = false
  if not line:match('|%s*$') then
    if line:match('%s$') then
      vim.fn.setline(lnum, line .. '|')
    else
      vim.fn.setline(lnum, line .. ' |')
    end
    closed_pipe = true
  end

  -- If a pipe was just added, realign before the {|"zyi| step below
  -- moves up to grab the cell above — that motion relies on this
  -- row's byte columns lining up with the header's, and a
  -- freshly-closed-but-not-yet-repadded row doesn't, so the move-up
  -- can land in the wrong column of the row above entirely.
  -- Confirmed via headless testing: without this, it grabbed the
  -- header's 3rd column instead of the 2nd for a cell that had
  -- needed its pipe closed first.
  --
  -- Realigning can itself shift where THIS cell starts (e.g.
  -- widening cell 1 pushes cell 2 rightward), landing the cursor's
  -- unadjusted raw column exactly ON the new separator between
  -- them instead of inside cell 2 — the same on-a-separator
  -- special-case as the nudge above, just reintroduced by the
  -- realign. So re-locate by column index afterward (seed at cell
  -- 1's start, then ]| cursor_col_nr - 1 times) rather than
  -- trusting the stale column — same technique and same reasoning
  -- as table_realign_preserving_cursor in AG-table-augmentation.lua.
  if closed_pipe then
    vim.fn['tablemode#table#Realign']('.')
    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    vim.fn['tablemode#spreadsheet#MoveToStartOfCell']()
    for _ = 2, cursor_col_nr do
      vim.cmd('normal ]|')
    end
  end

  -- Save/restore register z's prior contents (value + type, e.g.
  -- charwise/linewise/blockwise) around this function's own
  -- internal use of it, so a register the user is deliberately
  -- storing something in isn't silently clobbered as a side effect.
  local saved_reg = vim.fn.getreg('z')
  local saved_regtype = vim.fn.getregtype('z')

  local pos = vim.api.nvim_win_get_cursor(0)
  vim.cmd('normal {|"zyi|')
  vim.api.nvim_win_set_cursor(0, pos)
  vim.cmd('normal "_ci|' .. vim.api.nvim_replace_termcodes('<C-r>z', true, true, true))
  -- Pasted content may be a different width than what was there
  -- before, so realign to repad the column — same reasoning as the
  -- explicit Realign calls in AG-table-augmentation.lua's smart Tab.
  vim.fn['tablemode#table#Realign']('.')

  vim.fn.setreg('z', saved_reg, saved_regtype)
end

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
