-- Personal augmentations to vim-table-mode, layered on top rather than in
-- plugins/table-mode.lua so plugin updates never risk clobbering custom
-- behavior.
--
-- NOTABLE:
-- > Table mode Tab/⇧Tab navigation
--

-- ============================================================
-- Table Mode: Tab / Shift-Tab for cell navigation
-- ============================================================
-- Falls back to Tab's default jumplist behavior (<C-i>/<C-o>) when Table Mode
-- is off, so this is safe to map globally rather than scoping to a filetype.
-- Depends on vim-table-mode's buffer-local b:table_mode_active flag.

-- Precompute raw termcodes once; expr-mappings don't auto-parse <> notation on
-- return, so we need the actual byte sequences ready to hand back.
local jump_forward = vim.api.nvim_replace_termcodes("<C-i>", true, true, true)
local jump_back = vim.api.nvim_replace_termcodes("<C-o>", true, true, true)

-- ============================================================
-- Table Mode: smart Tab — add a cell/row when there's nowhere to go
-- ============================================================
-- Default ]| moves to the next cell in the row, wrapping to the next row's
-- first cell when already at the row's last cell. Fine for navigating an
-- existing table, but does nothing useful when there's truly nowhere to
-- go — either the current row is shorter than the table's real column
-- count (ragged, e.g. mid-typing before the row's filled out) or you're
-- at the table's last cell with no row below yet. This makes Tab behave
-- like a spreadsheet "fill forward":
--
--   1. Next cell already exists on this row -> normal ]| (unchanged).
--   2. This row is ragged (fewer cells than the table's column count,
--      established from the header/first row) -> append a new cell to
--      THIS row, cursor at the start of its content (2 past the opening
--      pipe, i.e. after a single leading space).
--   3. At the table's true last column, and a next row already exists ->
--      normal ]| (unchanged; it already wraps down correctly).
--   4. At the table's true last column, no next row exists -> close off
--      the current row (add a trailing | if missing), append a new empty
--      row, cursor at the start of that row's first cell.
--
-- ColumnNr()/ColumnCount() are vim-table-mode's own, reused rather than
-- reimplemented so column-counting matches the plugin's own notion of
-- cell boundaries exactly. Crucial: ColumnCount is PER LINE (that row's
-- own count of *closed*, pipe-bounded cells), not table-wide — the
-- table's real column count has to come from the header/first row
-- specifically (GetFirstRowOrHeader) to tell "ragged row" apart from
-- "genuinely last column".
--
-- Realign is called explicitly rather than left to the plugin's own
-- auto-align-on-TextChanged, because cursor placement here depends on
-- knowing the POST-realign cell boundaries, and auto-align's firing isn't
-- guaranteed to have already happened synchronously by the time this
-- function needs to compute where to put the cursor.
local function table_smart_tab()
  local lnum = vim.fn.line(".")

  -- Deliberately not vim-table-mode's own IsLastCell() here: it compares
  -- ColumnNr (cursor's conceptual column) against ColumnCount (only
  -- *closed*, pipe-bounded cells on this line) for equality, so it's
  -- wrong when the cursor is mid-typing the row's last cell and hasn't
  -- typed its closing "|" yet — ColumnNr comes out ahead of ColumnCount
  -- and the equality check silently reports false instead of true. Caught
  -- via headless testing (a row missing its trailing pipe did nothing at
  -- all on Tab). Comparing them directly here with < instead handles that
  -- case correctly, and ColumnNr (not ColumnCount) is used below for the
  -- ragged/last-column comparison too, for the same reason.
  local cursor_col_nr = vim.fn["tablemode#spreadsheet#ColumnNr"](".")
  local row_col_count = vim.fn["tablemode#spreadsheet#ColumnCount"](".")

  if cursor_col_nr < row_col_count then
    -- A later, already-closed cell exists on this row: jump to it.
    vim.cmd("normal ]|")
    return
  end

  local header_line = vim.fn["tablemode#spreadsheet#GetFirstRowOrHeader"](".")
  local table_col_count = vim.fn["tablemode#spreadsheet#ColumnCount"](header_line)

  if cursor_col_nr < table_col_count then
    -- Ragged row: add a cell to THIS row. The row's own last cell already
    -- ends with a closing "|" (or, if it doesn't yet, complete it first,
    -- same as the last-column case below) — that pipe IS the new cell's
    -- opening boundary, so only "   |" gets appended, not " |   |". An
    -- earlier version appended " |   |" unconditionally, duplicating the
    -- existing pipe into an extra unintended cell — caught via headless
    -- testing when it corrupted the border row.
    local line = vim.fn.getline(lnum)
    if not line:match("|%s*$") then
      line = line .. "|"
    end
    vim.fn.setline(lnum, line .. "   |")
    vim.api.nvim_win_set_cursor(0, { lnum, #line })
    vim.fn["tablemode#table#Realign"](".")

    -- Recompute the new cell's opening pipe position after realign rather
    -- than trusting pre-realign byte offsets, and land the cursor 2
    -- columns past it (i.e. after a single leading space) — the same
    -- "start of cell" convention vim-table-mode's own MoveToStartOfCell
    -- uses, and what the last-column/new-row case below does too.
    local realigned = vim.fn.getline(lnum)
    local _, second_last_pipe = realigned:sub(1, #realigned - 1):find(".*|")
    vim.api.nvim_win_set_cursor(0, { lnum, second_last_pipe + 1 })
    return
  end

  -- Genuinely at the table's last column: try the default motion first —
  -- if a next row already exists, ]| already wraps to it correctly.
  vim.cmd("normal ]|")
  if vim.fn.line(".") ~= lnum then
    return
  end

  -- No next row existed: close off this row, append a new one.
  local line = vim.fn.getline(lnum)
  if not line:match("|%s*$") then
    vim.fn.setline(lnum, line .. "|")
  end
  vim.fn.append(lnum, "|" .. string.rep(" |", table_col_count))
  vim.api.nvim_win_set_cursor(0, { lnum + 1, 0 })
  vim.fn["tablemode#table#Realign"](".")
  vim.fn["tablemode#spreadsheet#MoveToStartOfCell"]()
end

-- ============================================================
-- Table Mode: realign preserving cursor position
-- ============================================================
-- Realign repads column widths, which can shift where the CURRENT cell's
-- content starts if an EARLIER column in the same row changed width (e.g.
-- column 1 growing from 1 to 3 characters wide shifts column 2's start
-- rightward by 2). The cursor's raw byte column doesn't know about that
-- shift, so restoring it as-is after Realign silently points at the wrong
-- place — caught via headless testing (typing into a cell, realigning,
-- then continuing to type landed the new text mid-word instead of at the
-- end). Fixed by capturing the cursor's offset RELATIVE TO the start of
-- its own cell's content before realigning, then finding that same
-- (row, column-index) cell again afterward and reapplying the offset —
-- relative position within a cell survives realign even when the cell's
-- padding/width changes; an absolute byte column doesn't.
local function table_realign_preserving_cursor()
  local lnum = vim.fn.line(".")
  local cursor_col_nr = vim.fn["tablemode#spreadsheet#ColumnNr"](".")

  local save_pos = vim.api.nvim_win_get_cursor(0)
  vim.fn["tablemode#spreadsheet#MoveToStartOfCell"]()
  local offset_into_cell = save_pos[2] - vim.api.nvim_win_get_cursor(0)[2]
  vim.api.nvim_win_set_cursor(0, save_pos)

  vim.fn["tablemode#table#Realign"](".")

  -- Walk back to the same column index: seed at cell 1's start, then ]|
  -- (cursor_col_nr - 1) times. Deliberately NOT starting the loop at raw
  -- column 0 (the row's leading pipe) — ]| has a special case where
  -- starting exactly ON a separator does `2l` from right there instead of
  -- searching for the NEXT one first, so a loop seeded at column 0 lands
  -- one cell short of where it should (caught via headless testing: it
  -- consistently landed in cell 1 instead of cell 2). Seeding within cell
  -- 1's own content avoids that special case, since ]| only takes the
  -- "already on a separator" shortcut when literally sitting on one.
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
  vim.fn["tablemode#spreadsheet#MoveToStartOfCell"]()
  for _ = 2, cursor_col_nr do
    vim.cmd("normal ]|")
  end
  vim.api.nvim_win_set_cursor(0, { lnum, vim.api.nvim_win_get_cursor(0)[2] + offset_into_cell })
end

-- remap = true is required: vim-table-mode binds its cell motions as
-- buffer-local recursive maps (nmap <buffer> ]| <Plug>(table-mode-motion-right)),
-- so the "]|"/"[|" this expr-mapping returns must be allowed to trigger that
-- mapping too. vim.keymap.set defaults to non-recursive, which would make the
-- returned "]|"/"[|" hit raw ]/| as builtins instead — i.e. do nothing, which
-- was the actual bug (caught 2026-07-08: Tab/S-Tab silently no-op'd in table
-- mode). The jump_forward/jump_back fallback is already a resolved raw
-- termcode, not a mappable key sequence, so remap=true doesn't affect it.
--
-- <Tab> itself is no longer an expr-mapping (table_smart_tab does direct
-- buffer mutation via setline/append, which 'textlock' forbids from within
-- an expr-mapping callback — expr-mappings can only return keys to be fed
-- back in, not mutate the buffer directly).
--
-- The non-table-mode fallback uses nvim_feedkeys, not `:normal! <keys>` —
-- jump_forward (<C-i>'s termcode) is literally a single Tab/whitespace
-- character, and embedding it as a trailing Ex-command-line argument gets
-- silently stripped by Vim's command-line whitespace-trimming, leaving
-- bare "normal!" with no argument at all (E471). Hit this live after a
-- restart. feedkeys sends the raw keys directly with no Ex-command-line
-- parsing, so a whitespace-only key sequence isn't at risk of the same
-- trimming.
vim.keymap.set("n", "<Tab>", function()
  if vim.b.table_mode_active == 1 then
    table_smart_tab()
  else
    vim.api.nvim_feedkeys(jump_forward, "n", false)
  end
end, { desc = "Table: next cell, extending the table if needed (else jumplist forward)" })

vim.keymap.set("n", "<S-Tab>", function()
  if vim.b.table_mode_active == 1 then
    return "[|"
  else
    return jump_back
  end
end, { expr = true, remap = true, desc = "Table: previous cell (else jumplist back)" })

-- Insert-mode Tab/Shift-Tab cell navigation: only mapped buffer-locally while
-- table mode is actually on for that buffer (toggled via vim-table-mode's own
-- User TableModeEnabled/Disabled autocmds), rather than an always-on expr
-- mapping like the normal-mode one above. Insert mode's default <Tab> isn't a
-- simple key sequence — it's expandtab/softtabstop-aware indent logic with no
-- equivalent "fallback" key to hand back from an expr mapping — so the
-- cleanest way to preserve stock Tab behavior when table mode is off is to
-- not have a mapping at all outside table mode, rather than try to reimplement
-- indent-aware tab insertion here.
--
-- <C-o> runs one Normal-mode command (here, the plugin's own [| motion,
-- buffer-local per s:Map above) and returns to Insert mode automatically
-- afterward — satisfies "stay in insert mode across the move" for free.
-- remap = true so [| can trigger vim-table-mode's buffer-local recursive
-- mapping, same reasoning as the normal-mode mappings above.
--
-- <Tab> can't use the same <C-o> trick: table_smart_tab may run several
-- :normal sub-commands internally (not just one), and each :normal
-- implicitly exits back to Normal mode at the end of its own execution —
-- <C-o>'s one-command-then-return-to-insert guarantee only covers a
-- single command, not a multi-step function. So it's called directly
-- (not via <C-o>) and insert mode is explicitly restored afterward with
-- startinsert, which resumes at the cursor position table_smart_tab left
-- behind.
-- <C-l>: manual realign from insert mode. Unclaimed by both Vim's own
-- defaults (no :help i_CTRL-L exists) and the rest of this config
-- (checked via :imap before picking it) — and matches the near-universal
-- "refresh/redraw" convention for <C-l> across shells/editors (readline,
-- tmux, etc.), which maps naturally onto "refresh the table".
--
-- Despite Realign being a single function call (unlike table_smart_tab's
-- multi-step :normal chain), <C-o><Cmd>TableModeRealign<CR> does NOT work
-- here — caught via headless testing: realigning mid-insert through <C-o>
-- silently did nothing at all (header/border stayed stale even though a
-- cell had grown much wider), while calling the exact same
-- tablemode#table#Realign directly (no <C-o> involved) from a plain
-- Normal-mode context worked correctly. table_smart_tab's own direct
-- Lua-call-then-startinsert pattern already calls this same function
-- successfully from insert mode, so <C-l> uses that same pattern rather
-- than <C-o> — root cause not fully chased down (plausibly something
-- about undo-tree state or <Cmd> execution timing while <C-o>'s pending
-- "return to insert" is still in flight), but the working pattern was
-- already established, so no need to.
vim.api.nvim_create_autocmd("User", {
  pattern = "TableModeEnabled",
  desc = "Table mode: map Tab/S-Tab to cell nav and C-l to realign in insert mode too",
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.keymap.set("i", "<Tab>", function()
      table_smart_tab()
      vim.cmd("startinsert")
    end, { buffer = bufnr, desc = "Table: next cell, extending the table if needed" })
    vim.keymap.set("i", "<S-Tab>", "<C-o>[|", { buffer = bufnr, remap = true, desc = "Table: previous cell" })
    vim.keymap.set("i", "<C-l>", function()
      table_realign_preserving_cursor()
      vim.cmd("startinsert")
    end, { buffer = bufnr, desc = "Realign table" })
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "TableModeDisabled",
  desc = "Table mode: restore stock insert-mode Tab/S-Tab/C-l",
  callback = function()
    local bufnr = vim.api.nvim_get_current_buf()
    pcall(vim.keymap.del, "i", "<Tab>", { buffer = bufnr })
    pcall(vim.keymap.del, "i", "<S-Tab>", { buffer = bufnr })
    pcall(vim.keymap.del, "i", "<C-l>", { buffer = bufnr })
  end,
})
