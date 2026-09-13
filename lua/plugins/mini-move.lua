-- ~/.config/nvim/lua/plugins/mini-move.lua
--
-- mini.move (echasnovski/mini.move): move the current line, or a Visual
-- selection, in any direction. Installed standalone (not the full
-- echasnovski/mini.nvim suite), matching this repo's minimalism: only pull
-- in the one module actually wanted.
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
      -- down/up left unmapped here (`""` = mini.move creates no keymap for
      -- them at all — see H.map's early-return on an empty lhs) and hand-
      -- wired instead, further down, to force whole-logical-line behavior
      -- regardless of how the Visual selection was made. See the comment
      -- there for why.
      down = "",
      up = "",

      -- Move current line in Normal mode.
      line_left = "<C-h>",
      line_right = "<C-l>",
      line_down = "<C-j>",
      line_up = "<C-k>",
    },
    options = {
      -- Off (reported 2026-09-12), not mini.move's own default of `true`.
      -- With `true`, every vertical move ends with a Vim `=` reindent of
      -- the moved line(s) (mini/move.lua: `cmd('==')` for move_line,
      -- `cmd('=gv')` for move_selection). This config sets no
      -- 'indentexpr'/'cindent'/'lisp' anywhere (prose/Markdown/JSON have
      -- no such filetype indenter installed), and Vim's `=` with none of
      -- those active falls back to copying the indent of the
      -- newly-adjacent line rather than leaving the moved line alone --
      -- confirmed headlessly: a 4-space-indented line moved next to a
      -- 0-indent line has its own indent silently zeroed out. For code
      -- (where an indentexpr/cindent IS active) that fallback never
      -- triggers and this reindent would be genuinely useful, but here it
      -- only ever means "meaningful indentation (nested list items,
      -- blockquotes, JSON nesting) can get silently rewritten by a line
      -- move" -- exactly the "line becomes indented" symptom reported,
      -- confusingly visible only on the first move that actually crosses
      -- an indent-level boundary (moving between same-indent neighbors is
      -- a no-op for this fallback, so it doesn't visibly recur until the
      -- next real level change). Reproduces identically in Normal
      -- (move_line), Insert (same move_line, hand-wired below), and
      -- Visual mode (move_selection's `=gv`) alike, despite only being
      -- reported for the first two -- so this is disabled globally rather
      -- than per-mode.
      reindent_linewise = false,
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

    -- Visual-mode <C-j>/<C-k> (added 2026-09-12): force the move to act on
    -- whole logical lines no matter which Visual submode the selection was
    -- made in.
    --
    -- MiniMove.move_selection()'s vertical move only treats the selection
    -- as full lines when Vim's own mode() reports linewise Visual ('V')
    -- (see mini/move.lua's `is_linewise = cur_mode == 'V'`). In charwise
    -- ('v') or blockwise ('<C-v>') mode it cuts and moves only the exact
    -- selected characters, dragging just that span down between the
    -- surrounding text and effectively splitting the line it came from —
    -- not what "move this line" should mean. Aaron wants Up/Down to always
    -- carry every logical line the selection touches as a unit, regardless
    -- of which Visual submode he happened to select with — Left/Right are
    -- unaffected by this since a horizontal move is a within-line shift
    -- either way, so those keep mini.move's own selection-relative default.
    --
    -- Fix: if not already linewise, press `V` first. Pressing `V` while
    -- already in Visual mode doesn't start a new selection — it switches
    -- the existing selection's type in place, extending it to the same
    -- full lines it already spanned (a real ambiguity only for a single
    -- already-linewise selection, where `V` would instead exit Visual
    -- mode entirely — hence the `~= 'V'` guard below). A Lua function
    -- callback (like mini.move's own `<Cmd>...<CR>` mappings, unlike a
    -- literal-keys string rhs) runs without leaving Visual mode, so
    -- `vim.fn.mode()` inside it still reports the live selection's actual
    -- submode and `MiniMove.move_selection()` still sees real '<,'> marks.
    local function move_selection_as_lines(direction)
      if vim.fn.mode() ~= "V" then
        vim.cmd("normal! V")
      end
      MiniMove.move_selection(direction)
    end

    vim.keymap.set("x", "<C-j>", function() move_selection_as_lines("down") end,
      { desc = "Move selection down (whole lines)" })
    vim.keymap.set("x", "<C-k>", function() move_selection_as_lines("up") end,
      { desc = "Move selection up (whole lines)" })
  end,
}
