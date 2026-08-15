-- =============================================================
-- Prevent aText (system-wide text expansion) from corrupting its own
-- typed-character buffer around Normal-mode commands.
-- =============================================================
-- aText watches raw keystrokes at the OS level with no awareness that Vim
-- is modal. When a Normal-mode command like `dw` consumes two keystrokes
-- without inserting any text, aText still appends d/w to its own internal
-- "recently typed" buffer, which then diverges from the actual document
-- content. This causes two problems: (1) a real abbreviation typed right
-- after a command doesn't match, because aText's buffer still has the
-- phantom command characters glued in front of it; (2) phantom characters
-- can coincidentally combine with subsequently-typed real text to match a
-- *different* abbreviation, triggering an unintended expansion whose
-- inserted keystrokes then get interpreted as Vim commands if this happens
-- outside Insert mode.
--
-- A synthetic lone Command-key tap (which resets aText's buffer as a side
-- effect) via System Events was considered and rejected: the synthetic
-- key-down's actual OS-level delivery is delayed by osascript's
-- process/interpreter cold-start (~100-300ms), during which a real
-- physical keystroke could coincide with it and get composed into an
-- unintended system shortcut (Cmd+S, Cmd+W, Cmd+Q, etc.) — a risk inherent
-- to injecting a synthetic keyboard event at all, regardless of timing
-- strategy.
--
-- Instead: aText exposes its own AppleScript `enable`/`disable` commands.
-- Toggling those isn't a synthetic keyboard event at all, so there's no
-- possibility of it colliding with real keystrokes to form an accidental
-- shortcut. It's also fully deterministic: aText observes nothing while
-- disabled, so no partial buffer contamination is possible no matter how
-- many phantom Normal-mode commands run. Aaron confirmed empirically that
-- disabling and re-enabling aText leaves its buffer cleared, not just
-- paused-with-stale-content-intact.
--
-- enable (on InsertEnter) is synchronous (vim.fn.system): blocks until
-- aText is confirmed re-enabled, closing the gap where an abbreviation
-- typed immediately after entering Insert mode might not expand. disable
-- (on InsertLeave) is async (vim.fn.jobstart): there's no equivalent need
-- for it to block — any lag just means aText sees a few more trailing
-- Normal-mode phantom keystrokes for a moment longer, which is harmless,
-- since the next real typing session still starts clean regardless
-- (guaranteed by the synchronous enable). Full sync on both ends would
-- add a real, guaranteed pause to every single Insert-mode entry AND exit
-- — i/a/o and <Esc> are some of the most frequent keys in modal editing —
-- so only paying that cost on the one transition that actually needs it
-- keeps the tax to a minimum.
--
-- Residual known gap, not worked around: even a synchronous enable only
-- guarantees ordering with respect to Neovim's own processing — it can't
-- control when the user physically generates the next keystroke. aText
-- watches raw key events at the OS level independent of Neovim's input
-- queue, so if real typing resumes with zero pause immediately after `i`,
-- it's possible to outrun the enable call's own latency (process spawn +
-- Apple Event round-trip) and have the first character or two land before
-- aText has actually finished coming back online. Confirmed happening in
-- practice 2026-07-08. Always a silent missed expansion, never corruption.
-- Precompiling the AppleScript below (skipping the parse/compile step)
-- narrows this window somewhat; it doesn't eliminate it, since the
-- remaining cost is osascript's own process/interpreter startup, not
-- script compilation.
--
-- The two `enable`/`disable` commands are precompiled once into
-- stdpath('state') (not the portable, Stow-managed config tree — compiled
-- .scpt files are generated binary artifacts, not source, matching how
-- AG-autosave.lua already keeps undodir/backupdir out of the git-tracked
-- directory) rather than passed as `-e` source text on every single call,
-- since InsertEnter/InsertLeave fire on essentially every mode switch.

local state_dir = vim.fn.stdpath('state') .. '/atext-guard'
vim.fn.mkdir(state_dir, 'p')

-- v2: also mirrors this module's own Insert-mode state into a Keyboard
-- Maestro variable (AGaTextInsertMode), so KM's own app-activation-based
-- aText toggles (which predate this module and know nothing about Vim's
-- mode) can check it before blindly disabling aText out from under an
-- in-progress Insert-mode session — e.g. switching away from VimR mid-Insert
-- and back was unconditionally turning aText back off. Filename bumped
-- (not just editing enable.scpt/disable.scpt in place) so an existing
-- precompiled cache from before this change doesn't silently keep running
-- the old aText-only script.
local enable_scpt = state_dir .. '/enable-v2.scpt'
local disable_scpt = state_dir .. '/disable-v2.scpt'

if vim.fn.filereadable(enable_scpt) == 0 then
  vim.fn.system({
    'osacompile', '-o', enable_scpt, '-e',
    'tell application "aText" to enable\n'
      .. 'tell application "Keyboard Maestro Engine" to setvariable "AGaTextInsertMode" to "1"',
  })
end
if vim.fn.filereadable(disable_scpt) == 0 then
  vim.fn.system({
    'osacompile', '-o', disable_scpt, '-e',
    'tell application "aText" to disable\n'
      .. 'tell application "Keyboard Maestro Engine" to setvariable "AGaTextInsertMode" to "0"',
  })
end

local augroup = vim.api.nvim_create_augroup('AGAtextGuard', { clear = true })

-- <C-o> (used by several insert-mode mappings elsewhere in this config —
-- Home/End, arrow-key display-line nav, Cmd+Left/Right word nav) fires a
-- full InsertLeave+InsertEnter round trip for its "leave, run one command,
-- return" cycle — confirmed directly (autocmd counters both incremented on
-- a single <C-o> press). Without this, EVERY <C-o> keypress paid the
-- synchronous InsertEnter osascript call's full latency, surfacing as a
-- noticeable delay on every arrow-key press — reported live 2026-07-08.
--
-- Fix: defer the InsertLeave disable by one event-loop tick (vim.schedule)
-- instead of running it immediately. If InsertEnter fires again before
-- that tick runs — which a <C-o> round trip does, synchronously, within
-- the same keypress — cancel the pending disable and skip the enable
-- entirely: aText was never actually disabled, so there's nothing to
-- re-enable. A genuine leave (heading off to do real Normal-mode editing)
-- has no immediate follow-up InsertEnter, so the deferred disable runs
-- normally, just one tick later than before — imperceptible next to human
-- reaction time between keystrokes.
--
-- disable_token (not a plain boolean) guards against rapid successive
-- <C-o> presses: each InsertLeave captures its own token value before
-- scheduling, and the deferred callback only acts if that token is STILL
-- current when it runs — otherwise a newer Leave/Enter cycle has already
-- superseded it, and that cycle's own callback is responsible instead.
local disable_token = 0

vim.api.nvim_create_autocmd('InsertEnter', {
  group = augroup,
  desc = 'Re-enable aText (sync) before real typing resumes',
  callback = function()
    if disable_token > 0 then
      disable_token = 0
      return
    end
    vim.fn.system({ 'osascript', enable_scpt })
  end,
})

vim.api.nvim_create_autocmd('InsertLeave', {
  group = augroup,
  desc = 'Disable aText (async, deferred) so Normal-mode commands stay invisible to it',
  callback = function()
    disable_token = disable_token + 1
    local this_token = disable_token
    vim.schedule(function()
      if disable_token ~= this_token then
        return
      end
      disable_token = 0
      vim.fn.jobstart({ 'osascript', disable_scpt })
    end)
  end,
})
