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
        vim.keymap.set("i", "<CR>", "<CR><Cmd>AutolistNewBullet<CR>", opts)
        vim.keymap.set("i", "<Tab>", "<Cmd>AutolistTab<CR>", opts)
        vim.keymap.set("i", "<S-Tab>", "<Cmd>AutolistShiftTab<CR>", opts)

        -- Normal mode: o/O continue the list when opening a new line
        -- (staying in Insert mode afterward, same as vanilla o/O) — <Cmd>
        -- mappings run the Ex command without leaving the current mode, so
        -- no <C-o> round trip is needed, unlike some other insert-mode
        -- mappings elsewhere in this config. <CR> toggles a checkbox under
        -- the cursor; <C-r> force-recalculates list numbering (useful
        -- after a manual edit autolist didn't automatically catch).
        vim.keymap.set("n", "o", "o<Cmd>AutolistNewBullet<CR>", opts)
        vim.keymap.set("n", "O", "O<Cmd>AutolistNewBulletBefore<CR>", opts)
        vim.keymap.set("n", "<CR>", "<Cmd>AutolistToggleCheckbox<CR><CR>", opts)
        vim.keymap.set("n", "<C-r>", "<Cmd>AutolistRecalculate<CR>", opts)

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
        -- above). <Leader>c-prefixed to fit this config's existing
        -- <Leader>{t,f,r,cd,w}* leader-key namespace without colliding
        -- with any of it.
        vim.keymap.set("n", "<Leader>cn", require("autolist").cycle_next_dr,
          vim.tbl_extend("force", opts, { expr = true }))
        vim.keymap.set("n", "<Leader>cp", require("autolist").cycle_prev_dr,
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
