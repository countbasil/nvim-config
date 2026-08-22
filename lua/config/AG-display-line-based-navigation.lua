-- =============================================================
-- Display-line-based navigation & operators
-- (for prose/Markdown-heavy editing — VS Code/Xcode handle code)
-- =============================================================
-- j/k/0/$ now operate on *visual* rows (what you see on screen).
-- gj/gk/g0/g$ retain the original *logical*-line behavior as an
-- escape hatch. Applied across normal, visual, AND operator-pending
-- modes so that d$, dj, y0, etc. all respect display-line boundaries
-- too — otherwise e.g. d$ on a wrapped line would delete to the end
-- of the whole paragraph instead of just the visible row.

vim.keymap.set({ 'n', 'v', 'o' }, 'j', 'gj')
vim.keymap.set({ 'n', 'v', 'o' }, 'k', 'gk')
vim.keymap.set({ 'n', 'v', 'o' }, 'gj', 'j')
vim.keymap.set({ 'n', 'v', 'o' }, 'gk', 'k')

vim.keymap.set({ 'n', 'v', 'o' }, '0', 'g0')
vim.keymap.set({ 'n', 'v', 'o' }, '$', 'g$')
vim.keymap.set({ 'n', 'v', 'o' }, 'g0', '0')
vim.keymap.set({ 'n', 'v', 'o' }, 'g$', '$')

-- Home/End: built-in Home/End jump to the *logical* line's start/end, same
-- mismatch as unmapped 0/$ above. F11/F12 (via Keyboard Maestro) send these
-- directly now — KM was previously branching to send ^A/^E for VimR on the
-- assumption it's a Cocoa app expecting Emacs-style line-nav chords, but
-- ^A/^E turned out to already be claimed by native Vim behavior (^A =
-- increment number / repeat-last-insert, ^E = scroll / insert-char-below)
-- rather than being free for repurposing, and Aaron wanted those preserved
-- at the time. KM has been told VimR is NOT a Cocoa app so it sends plain
-- Home/End instead, which is a clean unclaimed key in both modes.
--
-- ^E was later (2026-07-09) deliberately repurposed anyway — see the
-- Insert-mode <C-e> mapping further down (grouped with the macOS-style
-- navigation section below, since it's really the same "end of logical
-- line" feature as Cmd+Down/Cmd+End) — giving up native i_CTRL-E
-- (insert char from line below) at Aaron's explicit request. ^A remains
-- untouched/preserved; this reversal applies to ^E only.
--
-- n/v/o (not just n) to match the 0/$ convention above, so d<End> etc. also
-- respect display-line boundaries. Insert mode uses <C-o> to run one
-- normal-mode command without leaving insert, picking up the display-line
-- 0/$ remap above for free rather than duplicating the g0/g$ logic here.
--
-- remap = true is required here: vim.keymap.set defaults to non-recursive,
-- which would mean the "0"/"$" inside "<C-o>0"/"<C-o>$" can't trigger our
-- own 0->g0 / $->g$ remap above — they'd silently fall through to Vim's
-- literal built-in 0/$ (logical-line start/end) instead, since a
-- non-recursive mapping's expanded keys are protected from further
-- remapping for their whole execution, even across the mode switch <C-o>
-- causes. This was caught 2026-07-08: pressing <Home> in insert mode did
-- nothing useful, but manually pressing <C-o> then 0 as two separate
-- keystrokes worked — because that second keystroke, typed fresh, DOES
-- go through the 0->g0 remap, unlike when it's bundled inside one
-- non-recursive mapped RHS.
vim.keymap.set({ 'n', 'v', 'o' }, '<Home>', 'g0')
vim.keymap.set({ 'n', 'v', 'o' }, '<End>', 'g$')
vim.keymap.set('i', '<Home>', '<C-o>0', { remap = true })
vim.keymap.set('i', '<End>', '<C-o>$', { remap = true })

-- Nvim defaults startofline OFF (unlike Vim), so gg/G preserve the previous
-- desired column instead of jumping to the target line's first non-blank.
-- That's especially bad with wrap+linebreak on: the preserved column lands
-- the cursor on a display row partway through a wrapped paragraph instead
-- of visually at the top/bottom. Force it on so gg/G/H/M/L/<C-d>/<C-u>
-- always land at the start of the line.
vim.opt.startofline = true

-- G (no count) overrides that, deliberately: it should land on the very
-- last character of the whole document, not the last line's first
-- non-blank — "go to the end" reasonably means the actual end. Counted G
-- (e.g. 5G, jump to line 5) is left alone and still honors 'startofline'
-- above; "last char of the document" is inherently a no-count concept, a
-- specific line isn't "the document".
--
-- vim.v.count is 0 (not nil) when no count was given. `normal!` (bang, not
-- bare `normal`) bypasses ALL custom mappings for both the G and the
-- trailing $: G itself isn't remapped elsewhere in this file, but the
-- trailing $ specifically needs the bypass to reach Vim's TRUE raw $
-- (logical end of line) rather than this file's own swapped meaning
-- (display-row end, top of this file) — same bypass technique already
-- used for Cmd+Up/Down and ^E elsewhere in this file.
--
-- n and v only, deliberately NOT o (operator-pending): tried n/v/o
-- together first, but dG came out corrupted (confirmed via headless
-- testing — deleted almost the whole buffer except a stray leftover
-- character). Combining a linewise jump (G) with a charwise refinement
-- ($) inside one Operator-pending callback confuses Vim's motion-type
-- inference for the resulting operator range. The actual ask here was
-- about cursor navigation, not about redefining what dG/yG operate over,
-- so Operator-pending G is left completely untouched (vanilla behavior)
-- rather than chasing that fragility for a case nobody asked for.
vim.keymap.set({ 'n', 'v' }, 'G', function()
  if vim.v.count == 0 then
    vim.cmd('normal! G$')
  else
    vim.cmd('normal! ' .. vim.v.count .. 'G')
  end
end)

-- Also adding these so can move across paragraphs with left/right arrows!
vim.opt.whichwrap:append("h,l,<,>,[,]")

-- =============================================================
-- Delete display row (dr)
-- =============================================================
-- Deletes only the current *visual* row rather than the whole
-- logical line, since native dd is always linewise and can't be
-- redefined to mean "visual row" (see prior discussion — there's
-- no buffer-level concept of a display row for dd to target).
--
-- Register behavior mirrors a native characterwise delete:
--   - Writes to the unnamed register "
--   - Writes to the small-delete register "-
--   - Deliberately does NOT populate "1-"9 (those are reserved
--     for linewise deletes like dd/dj, and this isn't one)
--
-- Bound to its own key (dr) rather than overriding dd, so macros
-- and plugins that assume dd == "delete whole logical line" still
-- work as expected.

local function delete_display_line()
  local line = vim.fn.line('.')

  vim.cmd('normal! g0')
  local start_col = vim.fn.col('.')

  vim.cmd('normal! g$')
  local end_col = vim.fn.col('.')

  local text_lines = vim.api.nvim_buf_get_text(0, line - 1, start_col - 1, line - 1, end_col, {})
  local deleted_text = table.concat(text_lines, '\n')

  vim.fn.setreg('"', deleted_text, 'c')
  vim.fn.setreg('-', deleted_text, 'c')

  vim.api.nvim_buf_set_text(0, line - 1, start_col - 1, line - 1, end_col, { '' })
end

vim.keymap.set('n', 'dr', delete_display_line)

-- =============================================================
-- macOS-style arrow-key / word-jump navigation (insert & visual mode)
-- =============================================================
-- <M-...> is Option (Meta), NOT Cmd (<D-...>) — deliberately, for
-- Left/Right. Keyboard Maestro on Aaron's machine rewrites Cmd+Left/Right to
-- Option+Left/Right and Shift+Cmd+Left/Right to Shift+Option+Left/Right
-- before Neovim ever sees them (confirmed live 2026-07-08: Cmd+Left/Right
-- was moving by character, not word — the tell that Cmd wasn't reaching
-- Neovim at all, since even the *unmapped* Shift+Left/Right built-in does
-- word-move, so falling all the way back to character-move meant the
-- modifier was being swapped out upstream, not merely mis-handled here).
-- <D-Left>/<D-Right> mappings would simply never fire under this KM setup.
--
-- Up/Down are the OPPOSITE case: KM has a separate rule that rewrites
-- Option+Up/Down (and Shift+Option+Up/Down) into PageUp/PageDown (and
-- Shift+PageUp/PageDown) — discovered 2026-07-08 as the actual cause of
-- "Shift+Option+Up/Down scrolls the viewport instead of selecting" reports,
-- not a Neovim mapping bug. So for Up/Down, Option is the unusable one, and
-- true Cmd (<D-Up>/<D-Down>/<S-D-Up>/<S-D-Down>) is used below instead,
-- since it reaches Neovim untouched. <D-...> only works in VimR (GUI);
-- Cmd can't be transmitted through iTerm2's terminal protocol at all.
--
-- If KM's behavior ever changes, revisit which notation (<M-...> vs
-- <D-...>) is actually reachable for each direction before assuming either
-- convention below still holds.
--
-- All of these use genuine builtin motions (gk/gj/g0/g$/b/w) directly
-- rather than the plain j/k/0/$ keys, same reasoning as delete_display_line
-- above using `normal! g0` — bypasses the swap entirely rather than
-- depending on it, so no remap=true is needed anywhere here (unlike the
-- Home/End mappings above, which deliberately DO thread through the 0->g0
-- swap and need remap=true for exactly that reason).

-- Insert mode: Up/Down move by display line, extending the gj/gk-for-j/k
-- philosophy at the top of this file to the arrow keys too — matters for
-- wrapped prose, same reasoning as the Home/End mappings. <C-o> runs one
-- Normal-mode command without leaving insert mode.
vim.keymap.set('i', '<Up>', '<C-o>gk')
vim.keymap.set('i', '<Down>', '<C-o>gj')

-- Insert mode: Option+Left/Right move by word (b/w) — this is actually
-- the physical key combo natively used for word-move on macOS anyway
-- (Cmd+Arrow is conventionally line start/end, which Home/End already
-- cover here), so this now lines up with native macOS convention rather
-- than repurposing it.
vim.keymap.set('i', '<M-Left>', '<C-o>b')
vim.keymap.set('i', '<M-Right>', '<C-o>w')

-- Insert mode: Option+Delete (Option+Backspace) deletes the word before the
-- cursor. <C-w> is already Vim's own built-in "delete back one word" in
-- Insert mode, so no custom motion assembly is needed here, unlike the
-- Left/Right/Up/Down cases above — just point the Option-Backspace keycode
-- at it, matching the same <M-...> notation established above for
-- Option+Left/Right.
vim.keymap.set('i', '<M-BS>', '<C-w>')

-- Insert mode: Cmd+Up/Down move to the START/END of the current LOGICAL
-- line — true Cmd here, not Option, per the Up/Down exception explained
-- atop this section (Option+Up/Down is claimed by a KM rule that turns it
-- into PageUp/PageDown). "Logical line" means the actual underlying buffer
-- line (regardless of how many display rows it wraps across); see the
-- header comment at the top of the file.
--
-- NOT gk/gj: tried that first (moves to the same COLUMN on the adjacent
-- logical line), but live testing 2026-07-08 showed that's the wrong unit
-- entirely — Aaron wanted "jump to this line's boundary" (what Home/End do
-- for the display row, just for the whole logical line instead), not "step
-- one line down keeping curswant". Corrected to plain 0/$.
--
-- Plain "0"/"$" here, NOT "g0"/"g$": counterintuitive given the rest of
-- this file, where the g-prefixed motion is consistently the one that
-- bypasses the swap to reach the "genuine builtin" meaning (gk/gj/g0/g$
-- elsewhere in this section). But for LINE-BOUNDARY motions specifically,
-- it's the other way around — Vim's true, original 0/$ already mean
-- logical-line start/end, while true g0/g$ mean display-row start/end (the
-- opposite of gk/gj, where true k/j are logical and true gk/gj are
-- display). This file's top-of-file swap remaps plain 0/$ to trigger g0/g$
-- and vice versa, so using literal "0"/"$" here — non-recursive, no
-- remap = true, exactly like the gk/gj/b/w motions above bypass the j/k
-- swap — reaches Vim's true original 0/$ (logical-line bounds) directly,
-- ignoring this file's swap entirely rather than routing through it.
vim.keymap.set('i', '<D-Up>', '<C-o>0')
vim.keymap.set('i', '<D-Down>', '<C-o>$')

-- Insert mode: ^E moves to the end of the current logical line, no
-- selection — same plain-$ bypass motion as Cmd+Down/Cmd+End above, just
-- without the leading v. Deliberately repurposes native i_CTRL-E (insert
-- char from line below), which this file's Home/End comment above used to
-- explicitly avoid touching — reversed 2026-07-09 at Aaron's explicit
-- request once it turned out Keyboard Maestro was already intercepting
-- physical ^E and rewriting it into something else before it ever reached
-- Neovim (matching the same silent-KM-rewrite pattern as Cmd/Option
-- elsewhere in this file), so native i_CTRL-E was already unreachable via
-- the physical key in practice, not actually being "preserved" at all.
vim.keymap.set('i', '<C-e>', '<C-o>$')

-- Visual mode: Shift+Home/End extend to display-line start/end;
-- Shift+Option+Left/Right extend by word. Plain motions, no <C-o> needed —
-- already in a Normal-mode-compatible mode where a motion directly extends
-- the pending selection.
--
-- Right uses `e` (end of word), not `w` (start of NEXT word): with Vim's
-- default inclusive selection, extending to `w` swallows the trailing
-- space after the current word (and the next word's first character) —
-- confirmed live 2026-08-08 as visibly wrong, selecting past the word
-- into the following whitespace. `e` stops exactly at the current word's
-- last character, matching how word-selection actually behaves in modern
-- GUI text editors (e.g. macOS's own Option+Shift+Right). Left keeps `b`
-- (start of previous/current word) — extending backward to `b` has no
-- equivalent overshoot, so no analogous swap is needed there.
--
-- Shift+Cmd+Up/Down extend to the current logical line's start/end (0/$) —
-- true Cmd, not Shift+Option, per the Up/Down exception atop this section
-- (Shift+Option+Up/Down is claimed by KM's Shift+PageUp/PageDown rewrite,
-- confirmed live 2026-07-08 as the actual cause of the "scrolls instead of
-- selecting" reports). See the Insert-mode Cmd+Up/Down comment above for
-- why plain 0/$ (not g0/g$) is the right bypass motion for logical-line
-- bounds specifically, and why gk/gj (tried first) was the wrong unit —
-- selecting to the same column on the adjacent line instead of to this
-- line's actual start/end, dragging in part of the neighboring line.
vim.keymap.set('v', '<S-D-Up>', '0')
vim.keymap.set('v', '<S-D-Down>', '$')

-- Shift+Cmd+Home/End extend to the current logical line's start/end — same
-- plain-0/$ bypass motion as Shift+Cmd+Up/Down just above (and so, in this
-- case, functionally redundant with it: both land on the same target).
-- Kept as its own mapping anyway since Home/End is the more natural
-- muscle-memory key for "start/end of line" specifically.
vim.keymap.set('v', '<S-D-Home>', '0')
vim.keymap.set('v', '<S-D-End>', '$')
vim.keymap.set('v', '<S-Home>', 'g0')
vim.keymap.set('v', '<S-End>', 'g$')
vim.keymap.set('v', '<S-M-Left>', 'b')
vim.keymap.set('v', '<S-M-Right>', 'e')

-- Plain Shift+Left/Right/Up/Down (no Option/Cmd): Vim ships its own default
-- mappings for these before any custom mapping gets a chance — Insert mode
-- <S-Left>/<S-Right> default to word-move (equivalent to <C-o>b/<C-o>w), and
-- <S-Up>/<S-Down> default to page-scroll (<PageUp>/<PageDown>), the latter
-- also active by default in Visual mode. Confirmed live 2026-07-08: plain
-- Shift+Left/Right was moving by word instead of extending the selection by
-- character, and Shift+Up/Down was scrolling the viewport instead of
-- touching the cursor/selection at all. Overridden here to match ordinary
-- macOS-style Shift-arrow behavior: char-wise for Left/Right (word is
-- already claimed by Shift+Option above, and there's no unit smaller than a
-- character to fall back to), display-line-wise for Up/Down (same unit
-- already used for Shift+Option+Up/Down — vertical arrow movement has no
-- granularity finer than a display line to offer instead).
vim.keymap.set('v', '<S-Left>', 'h')
vim.keymap.set('v', '<S-Right>', 'l')
vim.keymap.set('v', '<S-Up>', 'gk')
vim.keymap.set('v', '<S-Down>', 'gj')

-- Insert mode: the same Shift-combos also need their OWN insert-mode
-- mappings — they don't do anything from insert mode otherwise, since
-- the visual-mode mappings above only apply once already IN visual mode.
-- <Esc>v<motion> leaves insert, starts a charwise selection anchored at
-- the current cursor position, and extends it by the same motion — NOT
-- <C-o>v<motion>, since <C-o>'s "one command, then return to Insert"
-- contract is ambiguous/untested for a multi-part sequence like entering
-- a whole other mode plus a motion, whereas <Esc>v<motion> has no such
-- ambiguity. This deliberately does NOT return to Insert mode afterward
-- — staying in Visual mode is the point, so further Shift-presses keep
-- extending the same selection (they hit the plain visual-mode mappings
-- above from here on, no longer needing this insert-mode entry point).
-- Plain 0/$ (not g0/g$), same bypass reasoning as the Visual-mode
-- Shift+Cmd+Up/Down mapping above.
vim.keymap.set('i', '<S-D-Up>', '<Esc>v0')
vim.keymap.set('i', '<S-D-Down>', '<Esc>v$')
vim.keymap.set('i', '<S-D-Home>', '<Esc>v0')
vim.keymap.set('i', '<S-D-End>', '<Esc>v$')
vim.keymap.set('i', '<S-Home>', '<Esc>vg0')
vim.keymap.set('i', '<S-End>', '<Esc>vg$')
vim.keymap.set('i', '<S-M-Left>', '<Esc>vb')
vim.keymap.set('i', '<S-M-Right>', '<Esc>ve')

-- Insert-mode entry points for the plain Shift-arrow mappings above, same
-- reasoning as the Shift+Option/Shift+Home/End entry points above them.
vim.keymap.set('i', '<S-Left>', '<Esc>vh')
vim.keymap.set('i', '<S-Right>', '<Esc>vl')
vim.keymap.set('i', '<S-Up>', '<Esc>vgk')
vim.keymap.set('i', '<S-Down>', '<Esc>vgj')

-- =============================================================
-- macOS-style arrow-key / word-jump navigation (Normal mode)
-- =============================================================
-- Same physical key combos as the Insert/Visual-mode section above, now
-- also wired up for Normal mode. <M-...> here is genuinely Option (Meta),
-- not a Keyboard-Maestro-rewritten Cmd — see the note atop the
-- Insert/Visual section above for why Cmd notation isn't used anywhere in
-- this file.

-- Plain Up/Down move by display line, same as j/k already do (top of this
-- file) — extended to both n AND o (operator-pending), same reasoning as
-- j/k getting both there: so e.g. d<Down> deletes to the next display row,
-- not the next logical line, matching "like j/k do" exactly rather than
-- just visually moving the cursor.
vim.keymap.set({ 'n', 'o' }, '<Up>', 'gk')
vim.keymap.set({ 'n', 'o' }, '<Down>', 'gj')

-- Option+Left/Right move by word, matching the Insert-mode Option+Left/
-- Right mapping above (b/w directly — no <C-o> needed, Normal mode already
-- runs motions natively without leaving/re-entering any other mode).
vim.keymap.set('n', '<M-Left>', 'b')
vim.keymap.set('n', '<M-Right>', 'w')

-- Option+Delete (Option+Backspace) deletes the word before the cursor,
-- matching the Insert-mode Option+Backspace mapping above. Plain `db` (Vim's
-- well-known "delete back a word" idiom) leaves the character under the
-- cursor behind, since Normal-mode cursor sits ON a character rather than
-- between two — confirmed live 2026-07-08 as surprising/unwanted, since
-- Insert mode's <C-w> consumes that trailing character too. Trailing `x`
-- consumes it to match. `"_` (black hole register) on both the db and the x
-- so neither write to any register, mirroring i_CTRL-W's own behavior in
-- Insert mode (it doesn't touch registers at all either) — same reasoning
-- as the black-hole-register choice in table-mode.lua's <Leader>t' mapping.
vim.keymap.set('n', '<M-BS>', '"_db"_x')

-- Cmd+Up/Down move to the start/end of the current logical line (0/$) —
-- true Cmd, not Option, per the Up/Down exception explained atop the
-- Insert/Visual-mode section above. See that section's Cmd+Up/Down comment
-- for why plain 0/$ (not g0/g$) is the right bypass motion here.
vim.keymap.set('n', '<D-Up>', '0')
vim.keymap.set('n', '<D-Down>', '$')

-- ^E moves to the end of the current logical line — same plain-$ bypass
-- motion as Cmd+Down above, and the Normal-mode counterpart to the
-- Insert-mode ^E mapping earlier in this file. Deliberately repurposes
-- native Normal-mode CTRL-E (scroll window down one line), same
-- 2026-07-09 decision as the Insert-mode one — see that mapping's comment
-- for why (Keyboard Maestro was already intercepting physical ^E before
-- it reached Neovim, so the native behavior wasn't actually reachable via
-- the physical key anyway).
vim.keymap.set('n', '<C-e>', '$')

-- Shift+Left/Right/Up/Down, Shift+Cmd+Up/Down, Shift+Option+Left/Right, and
-- Shift+Home/End start a charwise/linewise visual selection from Normal
-- mode and immediately extend it by the same unit as their Insert/
-- Visual-mode counterparts above (character, display line, logical line,
-- word — `b` backward, `e` forward, see the Visual-mode section's comment
-- for why forward uses `e` not `w` — and display-line-start/end
-- respectively) — "v<motion>" rather than "<Esc>v<motion>", since Normal
-- mode has no Insert-mode state to escape out of first.
--
-- <S-D-Up>/<S-D-Down> were missing entirely until 2026-07-08 (this whole
-- combo just fell through unmapped), which is why it was scrolling the
-- viewport instead of doing anything cursor/selection-related — there was
-- no Normal-mode mapping to catch it at all, unlike Insert mode which
-- already had one. Plain <S-Left>/<S-Right> had the exact same gap,
-- caught 2026-08-21: with no Normal-mode entry point, they fell through to
-- Vim's own default word-motion (the behavior described/rejected in the
-- Visual-mode section's comment above) instead of starting a selection,
-- while <S-Up>/<S-Down> right below worked fine — the asymmetry is what
-- gave it away.
vim.keymap.set('n', '<S-Left>', 'vh')
vim.keymap.set('n', '<S-Right>', 'vl')
vim.keymap.set('n', '<S-Up>', 'vgk')
vim.keymap.set('n', '<S-Down>', 'vgj')
-- Shift+Cmd+Up/Down/Home/End: plain 0/$ (not g0/g$), same bypass reasoning
-- as the Insert/Visual-mode Cmd+Up/Down mappings above — extends to this
-- line's actual start/end rather than to the same column on the adjacent
-- line. Home/End kept as their own mapping alongside Up/Down for the same
-- "more natural muscle memory" reasoning as the Visual-mode section above,
-- even though they're functionally redundant with Shift+Cmd+Up/Down here.
vim.keymap.set('n', '<S-D-Up>', 'v0')
vim.keymap.set('n', '<S-D-Down>', 'v$')
vim.keymap.set('n', '<S-D-Home>', 'v0')
vim.keymap.set('n', '<S-D-End>', 'v$')
vim.keymap.set('n', '<S-M-Left>', 'vb')
vim.keymap.set('n', '<S-M-Right>', 've')
vim.keymap.set('n', '<S-Home>', 'vg0')
vim.keymap.set('n', '<S-End>', 'vg$')

-- =============================================================
-- Tab switching (Ctrl+Tab / Shift+Ctrl+Tab)
-- =============================================================
-- Confirmed on VimR: Ctrl+Tab already cycles to the NEXT tab natively
-- (outside Neovim, no mapping involved) in whatever mode was active when
-- pressed — Shift+Ctrl+Tab, the conventional pairing for "previous",
-- didn't have any native counterpart, so it fell through unhandled.
-- Rather than only patching the missing direction, both are mapped
-- explicitly here across every mode, so behavior no longer depends on
-- however VimR's native handling happens to vary by mode (untested
-- whether it actually covers Insert/Visual/Terminal the same way).
--
-- Unlike the <D-...> (Cmd) mappings elsewhere in this file, Ctrl-modified
-- keys are ordinary terminal-transmittable sequences in principle, so
-- these may also reach terminal Neovim under iTerm2 — but that's
-- untested; iTerm2 itself may claim Ctrl+Tab/Shift+Ctrl+Tab for its own
-- tab switching before Neovim ever sees them, same "intercepted
-- upstream" possibility documented for other keys throughout this file.
-- Revisit if it doesn't fire there.
--
-- `<Cmd>...<CR>` (not a plain `gt`/`gT` keystroke replay) runs the Ex
-- command directly against whatever mode is currently active, without
-- the mode-specific bypass gymnastics used elsewhere in this file
-- (<C-o> for Insert, <Esc>-then-re-enter for Visual) — per `:help
-- :map-cmd`, this is specifically designed to fire from any mode without
-- first leaving it, which is what makes one mapping usable everywhere
-- here instead of needing a separate RHS per mode. Confirmed via headless
-- testing: switching tabs from Insert mode this way leaves the cursor
-- correctly positioned on the destination tab's window; from Visual
-- mode, the selection is dropped (switching tabs moves focus to an
-- entirely different window, so there's no selection left to preserve
-- across the jump — same has always been true of any tab/window switch
-- initiated mid-selection, nothing new introduced here).
--
-- t (Terminal mode) included alongside n/i/v so tab-switching works
-- without first escaping out of a running terminal buffer. c (Cmdline
-- mode) deliberately excluded: switching tabs mid-command-entry is an
-- unusual edge case nobody asked for, and interacting with the in-
-- progress command-line typed so far isn't worth the risk of surprising
-- behavior for a case with no real use here.
vim.keymap.set({ 'n', 'i', 'v', 't' }, '<C-Tab>', '<Cmd>tabnext<CR>', { desc = "Next tab" })
vim.keymap.set({ 'n', 'i', 'v', 't' }, '<C-S-Tab>', '<Cmd>tabprevious<CR>', { desc = "Previous tab" })


