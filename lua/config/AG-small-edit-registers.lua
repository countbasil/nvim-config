-- ~/.config/nvim/lua/config/AG-small-edit-registers.lua
--
-- Problem: `clipboard=unnamedplus` (init.lua) links the unnamed register ""
-- to the macOS system clipboard "+, and Vim's own rule is that "" (and so
-- "+) is updated by ANY yank/delete/change regardless of size — including
-- throwaway single-character edits like `x`/`s`/`cw`. That meant a small
-- edit right after a deliberate big cut silently replaced the big cut as
-- the default paste target (both in Neovim's `p` and via Cmd+V anywhere
-- else on the Mac, since both ultimately read the same system clipboard).
--
-- Goal: make `x`/`s`/`c` (any size) stop touching ""/"+ at all, while
-- still landing in whatever register Vim's own delete/change logic would
-- already have used ("- for a small edit, "1 for a linewise/multi-line
-- one), so the content stays reachable there when wanted. Deliberately
-- NOT applied to `d` (any size, any mode): Aaron wants `d` to remain the
-- one key that's a "real cut" and keeps populating the big
-- register/clipboard regardless of size — every OTHER delete/change key
-- (`x`/`s`/`c`) is throwaway and should stay silent, however much it
-- touches.
--
-- Why not a simple `"_x`/`"-x` register-prefix remap: Vim's documented
-- rule is that "" is filled by a delete/change REGARDLESS of which
-- register was explicitly targeted, with the sole exception of the black
-- hole register "_ — but writing to "_ discards the text entirely
-- (nothing lands in "- either). So `x` below runs completely natively
-- (letting Vim's own, already-correct logic populate "- and set ""), then
-- immediately restores ""/"+ to their pre-command snapshot.
--
-- Why `s`/`c` are NOT handled the same way (a nested `vim.cmd('normal! ...
-- c')` that ends in Insert mode): `:help :normal` documents that an
-- unfinished Insert-mode entry is aborted (as if <Esc> was typed) the
-- moment the :normal command itself finishes — confirmed live 2026-09-13
-- via headless test (a naive operatorfunc-based reimplementation of `c`
-- dropped back to Normal mode instead of leaving Insert mode active for
-- the replacement text). Reimplementing `c`'s exact cursor/auto-indent
-- behavior across charwise/linewise/blockwise well enough to avoid that
-- trap isn't worth the risk. Instead, `s`/`c` are left completely native
-- (no remap at all — real Insert-mode entry, cursor placement, and
-- linewise blank-line auto-indent all keep working exactly as Vim
-- intends), and the register side effect is corrected afterward via
-- TextYankPost, which Neovim fires after any yank/delete/change:
-- `vim.v.event.operator` reports 'y'/'d'/'c'. Confirmed empirically
-- (headless test, 2026-09-13) that `x` and a plain small `d` both report
-- as 'd' (indistinguishable — hence `x` needs the direct-wrapper
-- treatment below instead), while `s` and `c` of ANY size report as 'c',
-- distinctly from 'd' — exactly the split needed to leave `d` fully
-- untouched while catching every `s`/`c`, small or not (broadened
-- 2026-09-23 from "single-line `c` only" — Aaron wants `c` to be a
-- throwaway key across the board, same as `x`, with `d` remaining the
-- sole exception).
--
-- A shadow copy of "the last legitimate big-register value" (`last_big`)
-- is kept up to date on every non-suppressed event and reapplied whenever
-- an `s`/`c` event tries to overwrite ""/"+ with throwaway content.

local last_big

local function snapshot_current()
  return {
    reg = vim.fn.getreg('"'), regtype = vim.fn.getregtype('"'),
    plus = vim.fn.getreg('+'), plustype = vim.fn.getregtype('+'),
  }
end

local function apply(snap)
  vim.fn.setreg('"', snap.reg, snap.regtype)
  vim.fn.setreg('+', snap.plus, snap.plustype)
end

last_big = snapshot_current()

-- x: always confined to one line (stops at end of line even with a count
-- exceeding the remaining characters) — always "small". Handled here by
-- direct wrap rather than the TextYankPost hook below, since x's event
-- reports operator == 'd', indistinguishable from a real small `d` there
-- (which must NOT be suppressed). `suppress_next_yankpost` tells that
-- hook to ignore x's own event entirely — this wrapper restores ""/"+
-- itself, synchronously, right after the delete.
local suppress_next_yankpost = false

vim.keymap.set('n', 'x', function()
  local snap = snapshot_current()
  suppress_next_yankpost = true
  vim.cmd('normal! ' .. vim.v.count1 .. 'x')
  suppress_next_yankpost = false -- belt-and-suspenders: reset even if x deleted nothing and TextYankPost never fired
  apply(snap)
end, { desc = 'Delete char (small — does not touch ""/system clipboard)' })

-- Visual-mode x (added 2026-09-22, at Aaron's explicit request): always
-- "small" regardless of how much the selection actually spans — unlike
-- everything else in this file, this one is NOT limited to genuinely
-- tiny edits. The point isn't "x happens to be small", it's "x is the
-- key for 'discard this, I don't want it as my next paste', however
-- big the Visual selection was", with plain `d` left as the one that
-- still means "this is a real cut, save it as usual".
--
-- Same operator=='d' ambiguity as Normal-mode x (Visual x and Visual d
-- are literally the same delete operation as far as Vim's internals are
-- concerned — Visual mode has no separate "delete one char" meaning for
-- x the way Normal mode does), so this needs the same direct-wrapper
-- treatment rather than the TextYankPost-based approach below.
--
-- Explicitly targets "- (rather than just running bare `x` and letting
-- Vim's own routing decide) because Vim only auto-routes a delete into
-- "- when it's small BY VIM'S definition (single line) — a multi-line
-- Visual selection would otherwise land in "1 instead, which is exactly
-- the case this mapping exists to redirect. An explicit register target
-- still doesn't stop "" from also being set (only the black hole "_
-- does — see the file-level comment above), hence the same
-- snapshot/restore dance as Normal-mode x, not a plain `"-x` on its own.
vim.keymap.set('v', 'x', function()
  local snap = snapshot_current()
  suppress_next_yankpost = true
  vim.cmd('normal! "-x')
  suppress_next_yankpost = false
  apply(snap)
end, { desc = 'Delete Visual selection (small — does not touch ""/system clipboard)' })

vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('AGSmallEditRegisters', { clear = true }),
  callback = function()
    if suppress_next_yankpost then
      suppress_next_yankpost = false
      return
    end

    local e = vim.v.event

    if e.operator == 'c' then
      apply(last_big)
    else
      last_big = snapshot_current()
    end
  end,
})
