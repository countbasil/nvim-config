-- ~/.config/nvim/lua/plugins/autolist.lua
--
-- autolist.nvim (gaoDean/autolist.nvim): automatic list continuation for
-- Markdown/text — continues bullets/numbered lists/checkboxes on Enter/o/O,
-- auto-renumbers ordered lists after inserting/deleting/reindenting items,
-- and toggles checkboxes. Fits this repo's prose/Markdown editing focus.

return {
  "gaoDean/autolist.nvim",
  ft = { "markdown", "text" }, -- matches table-mode.lua's scoping; this
  -- repo's stated primary use case (prose/Markdown/JSON), not the
  -- tex/plaintex/norg filetypes autolist also supports upstream but aren't
  -- relevant here.
  config = function()
    require("autolist").setup()

    -- Bridge table for the custom <CR> mapping below, exposed globally
    -- (not a local upvalue) since the mapping's <Cmd>lua fragments run as
    -- independent `:lua` calls in the global Lua environment with no
    -- access to this closure — same rationale/naming convention as
    -- `_G.__ag_autosave_timer` in AG-autosave.lua. Reassigning its
    -- functions on every config() run (e.g. `<Leader>rc`/`:Lazy reload`)
    -- is harmless idempotent overwrite, no cleanup needed.
    _G.__ag_autolist_cr = _G.__ag_autolist_cr or {}
    local cr_bridge = _G.__ag_autolist_cr

    -- Captures state right after the real <CR> splits the line, before
    -- AutolistNewBullet (upstream) touches it: the exact text that just
    -- became the new line (`remainder`), and where <CR>/autoindent left
    -- the cursor on it (`pre_col`) — the correct cursor position for the
    -- common case where this line turns out not to be part of a list at
    -- all, and AutolistNewBullet ends up doing nothing.
    function cr_bridge.pre_cr()
      cr_bridge.remainder = vim.api.nvim_get_current_line()
      cr_bridge.pre_col = vim.api.nvim_win_get_cursor(0)[2]
    end

    -- Repositions the cursor after AutolistNewBullet has run. Two cases:
    --  * The line is unchanged (no list found, or upstream's own
    --    "delete the now-empty bullet line" branch, which also leaves
    --    this line's own text untouched) — keep whatever <CR> already
    --    set (`pre_col`), matching vanilla Enter behavior exactly.
    --  * Otherwise a bullet was prepended: upstream strips the
    --    remainder's OWN leading whitespace before re-prepending its
    --    computed marker (see autolist/auto.lua's new_bullet:
    --    `cur_line:gsub("^%s*", "", 1)`), so the final line's length
    --    minus the remainder's STRIPPED length gives exactly the
    --    marker's length — deliberately not re-deriving the marker via
    --    our own pattern match, so this stays correct for every marker
    --    style/branch upstream supports (plain, ordered-list increment,
    --    colon-indent, checkbox) without duplicating its logic.
    function cr_bridge.post_cr()
      local final_line = vim.api.nvim_get_current_line()
      local target_col
      if final_line == cr_bridge.remainder then
        target_col = cr_bridge.pre_col
      else
        local leading_ws = vim.fn.matchstr(cr_bridge.remainder, [[^\s*]])
        local stripped_len = #cr_bridge.remainder - #leading_ws
        target_col = math.max(#final_line - stripped_len, 0)
      end
      local row = vim.api.nvim_win_get_cursor(0)[1]
      vim.api.nvim_win_set_cursor(0, { row, target_col })
    end

    -- Upstream's own recommended mappings (README), applied buffer-locally
    -- via a FileType autocmd rather than global vim.keymap.set calls.
    -- Necessary, not just cautious: `ft` above only controls WHEN the
    -- plugin (and this config function) first lazy-loads — config() itself
    -- runs once per session, not once per buffer, so without this autocmd
    -- re-applying the mappings on every matching buffer, only the very
    -- first markdown/text buffer opened would get them, and a global
    -- (non-buffer-local) vim.keymap.set here would instead leak
    -- Enter/Tab/o/O/dd remaps into every OTHER filetype's buffers too,
    -- once the plugin loaded for the first time.
    local augroup = vim.api.nvim_create_augroup("AGAutolist", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = augroup,
      pattern = { "markdown", "text" },
      callback = function(args)
        local opts = { buffer = args.buf }

        -- Insert mode: continue the list on Enter; indent/dedent the
        -- current list item on Tab/Shift-Tab.
        --
        -- Tab/Shift-Tab can be shadowed here: AG-table-augmentation.lua
        -- adds its OWN buffer-local Insert-mode Tab/S-Tab (table cell nav)
        -- whenever vim-table-mode is enabled for a buffer, and that
        -- enable is buffer-wide, not scoped to just the table's own lines
        -- — so a markdown buffer with both a table and a list, with table
        -- mode toggled on, has table-mode's cell-nav Tab win everywhere in
        -- that buffer (buffer-local mappings set later take precedence),
        -- including inside the list. Accepted as reasonable: table mode is
        -- an explicit, deliberate per-buffer toggle, so list-Tab losing
        -- out only while you've specifically turned table mode on reads as
        -- predictable precedence, not a real conflict.
        -- Splitting mid-line and inserting the new bullet is upstream
        -- behavior (AutolistNewBullet), but upstream's own new_bullet()
        -- always leaves the cursor at the END of the new line (its
        -- utils.set_current_line unconditionally does `col("$")`) —
        -- correct for Enter at end-of-line (nothing follows the bullet
        -- anyway), but wrong for Enter mid-line: the cursor lands after
        -- the carried-over remainder text instead of right after the
        -- bullet marker, where typing should resume. Reported 2026-08-16.
        -- Fixed via cr_bridge above (see its comments for the approach).
        vim.keymap.set("i", "<CR>",
          "<CR><Cmd>lua __ag_autolist_cr.pre_cr()<CR>"
          .. "<Cmd>AutolistNewBullet<CR>"
          .. "<Cmd>lua __ag_autolist_cr.post_cr()<CR>",
          opts)
        vim.keymap.set("i", "<Tab>", "<Cmd>AutolistTab<CR>", opts)
        vim.keymap.set("i", "<S-Tab>", "<Cmd>AutolistShiftTab<CR>", opts)

        -- Normal mode: o/O continue the list when opening a new line
        -- (staying in Insert mode afterward, same as vanilla o/O) — <Cmd>
        -- mappings run the Ex command without leaving the current mode, so
        -- no <C-o> round trip is needed, unlike some other insert-mode
        -- mappings elsewhere in this config. <Leader>lr force-recalculates
        -- list numbering (useful after a manual edit autolist didn't
        -- automatically catch) — upstream's README suggests <C-r> for this,
        -- but that shadows builtin redo in every markdown/text buffer, so
        -- it's relocated next to <Leader>lb/<Leader>lB below (the other
        -- list-marker actions in this file) instead — "l" for list, "r"
        -- for recalculate reads cleaner than the <Leader>c* namespace,
        -- which already means "change" globally (init.lua). The marker-cycle
        -- mappings just below (<Leader>ln/<Leader>lp) were relocated from
        -- <Leader>cn/<Leader>cp to the same "l" namespace for consistency.
        --
        -- Deliberately NOT mapping <CR> here (previously bound to
        -- AutolistToggleCheckbox): as of 2026-07-18, Normal-mode <CR> is
        -- meant to behave the same across ALL filetypes (split line, stay
        -- in Insert — see AG-normal-mode-editing.lua), and a buffer-local
        -- mapping here would shadow that global one for exactly the
        -- markdown/text filetypes that are this repo's primary use case.
        -- Checkbox toggling is still available via
        -- `:AutolistToggleCheckbox`, just without a dedicated key, at
        -- Aaron's explicit choice of the "full override" option over
        -- keeping/relocating a dedicated toggle key.
        vim.keymap.set("n", "o", "o<Cmd>AutolistNewBullet<CR>", opts)
        vim.keymap.set("n", "O", "O<Cmd>AutolistNewBulletBefore<CR>", opts)
        vim.keymap.set("n", "<Leader>lr", "<Cmd>AutolistRecalculate<CR>", opts)

        -- Keep list numbering correct after deleting a line or
        -- (de|in)denting. These are plain non-recursive keys-strings (not
        -- an expr-mapping calling some autolist.dd()/d() function — an
        -- earlier version of this file tried that, guessing at an API from
        -- memory, and it crashed with "attempt to call field 'dd' (a nil
        -- value)": that function doesn't exist in the current plugin,
        -- confirmed by reading the actual installed source and README).
        -- The embedded "dd"/"d" below execute Vim's true builtin dd/d
        -- (non-recursive, so they don't loop back into this same mapping),
        -- so vanilla dd semantics (see AG-display-line-based-navigation.lua's
        -- own dr/dd discussion) are fully preserved — AutolistRecalculate is
        -- a harmless no-op when the current line isn't part of an ordered
        -- list, so this is safe to run unconditionally rather than needing
        -- its own list-detection check.
        vim.keymap.set("n", ">>", ">><Cmd>AutolistRecalculate<CR>", opts)
        vim.keymap.set("n", "<<", "<<<Cmd>AutolistRecalculate<CR>", opts)
        vim.keymap.set("n", "dd", "dd<Cmd>AutolistRecalculate<CR>", opts)
        vim.keymap.set("v", "d", "d<Cmd>AutolistRecalculate<CR>", opts)

        -- Cycle the current list's marker type (- -> * -> 1. -> 1) -> a) ->
        -- I. -> back to -, per `config.cycle`) forward/backward, with
        -- dot-repeat support via autolist's own *_dr helper functions
        -- (these genuinely exist in autolist.auto, unlike the dd/d ones
        -- above). <Leader>l-prefixed (list namespace) alongside
        -- <Leader>lb/<Leader>lB/<Leader>lr below, rather than <Leader>c*,
        -- which already means "change" globally (init.lua).
        vim.keymap.set("n", "<Leader>ln", require("autolist").cycle_next_dr,
          vim.tbl_extend("force", opts, { expr = true }))
        vim.keymap.set("n", "<Leader>lp", require("autolist").cycle_prev_dr,
          vim.tbl_extend("force", opts, { expr = true }))

        -- Visual mode: turn the selected lines into a bullet list, or strip
        -- list markers back off. Plain :s commands (not AutolistXxx
        -- commands) since this is about converting PLAIN TEXT into a list
        -- in the first place, not operating on an existing one — nothing
        -- upstream does this. Pressing `:` from Visual mode auto-fills the
        -- '<,'> range, so these apply to exactly the selected lines.
        --
        -- <Leader>lb ("listify bullets"): skips lines that already start
        -- with a marker (any of autolist's own marker types — unordered,
        -- numbered, lettered — not just -/+/*) rather than unconditionally
        -- prepending "- ", so re-running it on a selection that's already
        -- partly a list doesn't double up bullets on the lines that have
        -- one already. Also leaves fully blank/whitespace-only lines alone
        -- — verified via headless testing that without the `\(\S\)\@=`
        -- lookahead, Vim's regex backtracking would consume all-but-one of
        -- a whitespace-only line's spaces into \1, then plant a bullet
        -- using that last leftover space as the "content" character,
        -- turning e.g. a 3-space blank line into "  -  " instead of
        -- leaving it untouched. Trailing `e` flag: suppresses "E486:
        -- Pattern not found" (and the interactive press-ENTER prompt that
        -- comes with it) for the case where every line in the selection
        -- already has a marker, so there's nothing to convert.
        --
        -- <Leader>lB ("un-listify"): the reverse — strips a leading marker
        -- (any of the same types) back off, preserving indentation.
        vim.keymap.set("v", "<Leader>lb",
          [[:s/^\(\s*\)\%(-\|+\|\*\|\d\+[.)]\|[A-Za-z][.)]\)\@!\(\S\)\@=/\1- /e<CR>]],
          vim.tbl_extend("force", opts, { desc = "Bulletize selected lines (skip existing markers)" }))
        vim.keymap.set("v", "<Leader>lB",
          [[:s/^\(\s*\)\%(-\|+\|\*\|\d\+[.)]\|[A-Za-z][.)]\)\s*/\1/e<CR>]],
          vim.tbl_extend("force", opts, { desc = "Remove list markers from selected lines" }))
      end,
    })
  end,
}
