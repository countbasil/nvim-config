-- ~/.config/nvim/lua/plugins/mini-move.lua
--
-- mini.move (echasnovski/mini.move): move the current line, or a Visual
-- selection, in any direction — with automatic reindent on vertical moves.
-- Installed standalone (not the full echasnovski/mini.nvim suite), matching
-- this repo's minimalism: only pull in the one module actually wanted.
--
-- Mapped to Control+h/j/k/l (not mini.move's own Option/<M-...> defaults),
-- at Aaron's explicit request 2026-07-09 after weighing the trade-offs:
--   - <C-h> (left/line_left): Insert mode's built-in meaning is "delete char
--     before cursor" (same action as Backspace). On some terminal configs
--     the physical Backspace key is itself transmitted as literal Ctrl-H,
--     which would make this collide with real Backspace — low risk on this
--     specific setup (VimR's GUI frontend distinguishes true <BS> from
--     <C-h>; modern macOS/iTerm2 default to DEL-based erase, not ^H), but
--     worth knowing if it's ever moved to a different terminal setup.
--   - <C-j> (down/line_down): built-in Normal-mode alias for `j` — lowest
--     impact of the four, rarely used directly, and `j` itself is already
--     repurposed for display-line movement elsewhere in this config anyway.
--   - <C-k> (up/line_up): shadows Vim's built-in digraph entry
--     (<C-k>a: -> ä, etc., in both Normal and Insert mode) — a real loss if
--     digraphs are ever used for accented/special characters.
--   - <C-l> (right/line_right): a DEFINITE, pre-existing conflict, not
--     hypothetical — <C-l> is already bound in Insert mode for table-mode's
--     manual realign (AG-table-augmentation.lua), buffer-local whenever
--     table mode is active, and is Vim's native full-screen-redraw
--     everywhere else. Since Neovim resolves a buffer-local mapping over a
--     global one, table-mode's realign wins inside an active table (this
--     mini.move mapping simply won't fire there); outside table-mode
--     buffers, this mini.move mapping wins over the (rarely-needed)
--     built-in redraw. Accepted as-is at Aaron's request rather than
--     picking a different key for `right`/`line_right`.
--
-- To customize further: change any of the six `mappings` entries below to
-- whatever keys you want — `line_*` covers Normal-mode single-line moves,
-- the other four cover Visual-mode selection moves; they're independent,
-- so e.g. line moves and selection moves could use different keys entirely
-- if wanted. Set any entry to `""` to disable just that one
-- direction/mode. Full option list: `:help MiniMove.config`.
--
-- Insert-mode Ctrl+h/j/k/l (logical-line move, added 2026-07-17) are NOT
-- part of `mappings` below — mini.move has no Insert-mode concept of its
-- own, so they're hand-wired in the `config` function further down instead.
-- Change/remove those there, not here.

return {
  "echasnovski/mini.move",
  version = false,
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    mappings = {
      -- Move Visual selection in Visual mode.
      left = "<C-h>",
      right = "<C-l>",
      down = "<C-j>",
      up = "<C-k>",

      -- Move current line in Normal mode.
      line_left = "<C-h>",
      line_right = "<C-l>",
      line_down = "<C-j>",
      line_up = "<C-k>",
    },
    options = {
      -- Automatically reindent selection during linewise vertical move.
      reindent_linewise = true,
    },
  },
  -- A `config` function (rather than relying on lazy.nvim's automatic
  -- `opts` -> `setup(opts)` call) is needed here so the same Ctrl+h/j/k/l
  -- keys can also move the current *logical* line from Insert mode,
  -- extended to Insert mode at Aaron's explicit request 2026-07-17 despite
  -- real conflicts with Insert mode's own built-in meanings for all three
  -- of <C-h> (Backspace), <C-j> (line break, same as <CR>), and <C-k>
  -- (digraph entry) — accepted knowingly, not overlooked.
  config = function(_, opts)
    require("mini.move").setup(opts)

    -- `<Cmd>...<CR>` (not `<C-o>...`, unlike every other Insert-mode
    -- mapping in AG-display-line-based-navigation.lua) because
    -- MiniMove.move_line() is a multi-step operation (yank/delete/paste/
    -- reindent via its own internal `normal!`-bypass helper, not a single
    -- Normal-mode keystroke) — `<C-o>` only runs exactly one Normal-mode
    -- command before returning to Insert mode, which doesn't fit. A
    -- `<Cmd>` mapping executes the Ex command without leaving the current
    -- mode at all (mirrors how mini.move wires its own Normal-mode
    -- mappings: `<Cmd>lua MiniMove.move_line(...)<CR>`), so Insert mode is
    -- preserved across the move, and MiniMove.move_line()'s own cursor-
    -- column correction (H.correct_cursor_col) keeps the cursor at the
    -- same relative column it had before the move rather than snapping to
    -- the moved line's first non-blank.
    vim.keymap.set("i", "<C-h>", "<Cmd>lua MiniMove.move_line('left')<CR>")
    vim.keymap.set("i", "<C-l>", "<Cmd>lua MiniMove.move_line('right')<CR>")
    vim.keymap.set("i", "<C-j>", "<Cmd>lua MiniMove.move_line('down')<CR>")
    vim.keymap.set("i", "<C-k>", "<Cmd>lua MiniMove.move_line('up')<CR>")
  end,
}
