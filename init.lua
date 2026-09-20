-- ajg modifications for vim/nvim

-- set leader (like meta key) to space
vim.g.mapleader = " "

-- enable lazy.nvim plugin manager
require("config.lazy")

-- enable my tweaks including 
require("config.AG-titlecase").setup()  -- * title case function [maps to `gl`]

-- slugify: replace spaces with dashes in a Visual-mode selection [maps to `<Leader>-`]
require('config.AG-slugify')

-- collapse blank-line paragraph breaks to a single newline [maps to `<Leader>1`]
require('config.AG-collapse-blank-lines')

-- my display-line [vs file-line] navigation (incl display-line def for `dr`)
require('config.AG-display-line-based-navigation')

-- Normal-mode <CR> (split line, stay in Insert) / <BS> (delete char, stay in Normal)
require('config.AG-normal-mode-editing')

-- x/s/c (single-line only) stop overwriting ""/system clipboard, so a
-- throwaway small edit can't clobber a deliberate big cut/yank as the
-- default paste target
require('config.AG-small-edit-registers')

-- personal augmentations to vim-table-mode (e.g. Tab/S-Tab cell nav)
require('config.AG-table-augmentation')

-- autocommands (currently: auto-`lcd` to the current file's directory)
require('config.autocmds')

-- data-loss prevention: persistent undo, backups, autosave, auto-persist new buffers
require('config.AG-autosave').setup()

-- prevent aText (system text expander) from corrupting its buffer around Normal-mode commands
require('config.AG-atext-guard')

-- sync clipboard to Mac
vim.opt.clipboard = "unnamedplus"

-- appearance
vim.opt.background = "dark"
vim.cmd("colorscheme slate")

-- [IS THIS NEEDED? Added when seemed not to get config changes on `:rc`
-- Workaround for VimR not auto-populating package.path from stdpath('config')
local config_lua_path = vim.fn.stdpath('config') .. '/lua'
package.path = config_lua_path .. '/?.lua;' .. config_lua_path .. '/?/init.lua;' .. package.path


-----------------------------
-- leader-key functions
-----------------------------
-- NOTABLE LEADER-KEY FUNCTIONS:
--  - rc = reload config
--  - cd = change global working directory to current file's dir (affects
--         every window/tab in this Neovim instance that doesn't already
--         have its own `:lcd` override, e.g. via autocmds.lua's auto-lcd;
--         does NOT change where already-open buffers in other windows save)
--  - w = word wrap toggle
--  - l = clear search highlight + redraw screen
--  - d = delete (Normal-mode operator or Visual selection) without yanking
--
--  [From other files]
--  - t* = table mode functions [table-mode plug-in & AG-table-augmentation config]
--  - f* = file functions find/recent/grep/buffers [snacks]
--  - l* = list functions (bulletize/un-bulletize selection) [autolist.nvim config, markdown/text only]

-- rc = reload config [init.lua]
--
-- Also reloads lazy.nvim-managed plugin specs (lua/plugins/*.lua),
-- covering the gap the CLAUDE.md docs used to call out (":Lazy reload
-- needed separately"). Two independent problems, two independent fixes:
--
-- 1. lua/config/*.lua modules ARE real require()d Lua modules, so the
--    cache-clear loop below (unchanged) handles them exactly as before.
--
-- 2. lua/plugins/*.lua files are NOT require()d the normal way — lazy's
--    Spec:import() reads them with loadfile() and never populates
--    package.loaded for them, so the cache-clear loop can't reach them
--    regardless of what it matches. Instead:
--      - `Plugin.load()` re-parses every spec fresh from disk into
--        Config.plugins (the same re-parse lazy's own background
--        change-detection watcher already runs a couple seconds after
--        any save — see lazy/manage/reloader.lua — but done here
--        synchronously so "reload now" actually means now).
--      - Each plugin's `_.handlers` cache is cleared before reload:
--        lazy's own Handler.enable() only re-resolves a plugin's
--        keys/events/etc from the current spec when that cache is
--        empty, so leaving it in place after a spec re-parse would
--        silently keep re-arming the OLD keys/opts (confirmed via
--        headless test 2026-09-20: without this, an edited `desc` on
--        <Leader>fR never took effect across repeated reloads).
--      - `Loader.reload(plugin)` then re-runs that plugin's
--        init/opts/config/keys from the refreshed spec — the same
--        thing `:Lazy reload <plugin>` does for one plugin from the
--        UI, done here for all of them at once.
--      - The synthetic "lazy.nvim" self-entry (present in
--        Config.plugins for internal bookkeeping) is skipped: reloading
--        it walks and clears lazy.nvim's OWN lua/ modules mid-loop,
--        which corrupts every subsequent plugin's reload in the same
--        pass (confirmed via headless test 2026-09-20 — errors only
--        appeared for plugins processed after it, order-dependently).
--
--    Known gap, not worked around: removing a `keys` entry (or other
--    handler-managed binding) from a spec file and reloading does NOT
--    unbind the old mapping — lazy's handler-disable path deletes then
--    immediately re-creates the same real keymap rather than dropping
--    it (confirmed via headless test 2026-09-20). A key that's actually
--    been deleted from a spec, not just edited, needs a real restart to
--    stop working. Additions and in-place edits (opts, keys' rhs
--    functions, desc, etc.) — the common case — reload cleanly.
vim.keymap.set('n', '<Leader>rc', function()
  -- config.lazy is skipped here: it's just the bootstrap that calls
  -- require("lazy").setup(), and lazy.nvim refuses to run setup() a
  -- second time in one session (it warns "Re-sourcing your config is
  -- not supported" and returns immediately) — clearing and
  -- re-requiring it would only produce that warning on every reload
  -- rather than actually reloading anything. Plugin specs under
  -- lua/plugins/*.lua are reloaded explicitly below instead.
  for name, _ in pairs(package.loaded) do
    if (name == 'config' or name:match('^config%.')) and name ~= 'config.lazy' then
      package.loaded[name] = nil
    end
  end
  vim.cmd("source $MYVIMRC")

  require("lazy.core.plugin").load()
  local plugin_errors = {}
  for name, plugin in pairs(require("lazy.core.config").plugins) do
    if name ~= "lazy.nvim" then
      plugin._.handlers = nil
      local ok, err = pcall(require("lazy.core.loader").reload, plugin)
      if not ok then
        table.insert(plugin_errors, name .. ": " .. tostring(err))
      end
    end
  end

  if #plugin_errors > 0 then
    vim.notify(
      "Config reloaded, but some plugins failed to reload:\n" .. table.concat(plugin_errors, "\n"),
      vim.log.levels.ERROR
    )
  else
    print("Config reloaded!")
  end
end, { desc = "Reload config" })

-- cd = change Neovim's global working directory to the current file's
-- folder. Global (`:cd`, not `:lcd`/`:tcd`), so it applies instance-wide —
-- but windows already showing a real file already have their own `:lcd`
-- override from autocmds.lua's auto-lcd-on-BufEnter, which takes
-- precedence over this global value for them. In practice this mainly
-- matters for windows without a file loaded yet (empty/scratch, terminal,
-- a fresh split) and for relative-path lookups (:e, :find, netrw, snacks
-- pickers) run afterward — it has no effect on where buffers already open
-- elsewhere save, since Neovim pins each buffer to its own absolute path
-- as soon as it's loaded, regardless of later `:cd` calls (confirmed via
-- headless testing 2026-07-26).
vim.keymap.set('n', '<Leader>cd', ':cd %:p:h<CR>', { desc = "Change directory to current file's folder" })

-- w = word wrap toggle
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true

vim.keymap.set('n', '<Leader>w', function()
  vim.wo.wrap = not vim.wo.wrap
  print(vim.wo.wrap and "wrap ON" or "wrap OFF")
end, { desc = "Toggle wrap" })

-- l = clear search highlight + redraw screen. Plain <C-l> used to do the
-- redraw half of this (never the nohlsearch half — that's a common
-- convention in OTHER Vim configs, but was never actually present here),
-- until mini.move claimed <C-l> globally in Normal mode for "move line
-- right" (lua/plugins/mini-move.lua). Rather than put this on <C-S-l>,
-- Ctrl+letter conventionally sends the same control byte regardless of
-- Shift in a raw terminal stream (Ctrl-L is always 0x0C), so iTerm2 likely
-- can't distinguish <C-S-l> from plain <C-l> at all without extended
-- keyboard protocol support — a Leader-based key sidesteps that ambiguity
-- entirely and is guaranteed to behave identically in VimR and iTerm2.
--
-- The redraw needs Vim's TRUE builtin Ctrl-L, bypassing mini.move's own
-- <C-l> redefinition. First tried a plain string RHS mixing <Cmd>...<CR>
-- with a trailing literal <C-l> — worked in headless testing, but reported
-- live 2026-07-16 as moving the cursor right instead of redrawing,
-- suggesting that combination doesn't reliably parse the trailing <C-l> as
-- the special key once <Cmd> has already run (headless feedkeys apparently
-- didn't catch this — same class of headless/live divergence as the
-- wrapped-line arrow-key testing gap noted earlier in this file).
-- `vim.cmd('normal! ' .. <C-l> termcode)` is the same `normal!`-bypass
-- technique already proven throughout AG-display-line-based-navigation.lua
-- (e.g. delete_display_line's `normal! g0`) — bang bypasses ALL mappings
-- unambiguously, guaranteed to reach the true builtin regardless of how
-- the preceding Ex command executed.
vim.keymap.set('n', '<Leader>l', function()
  vim.cmd('nohlsearch')
  vim.cmd('normal! ' .. vim.api.nvim_replace_termcodes('<C-l>', true, true, true))
end, { desc = "Clear search highlight and redraw screen" })

-- d = delete without yanking. `"_d` selects the black-hole register ("_)
-- for the delete that follows, so plain `d` in Normal mode (an operator,
-- awaiting a motion — e.g. <Leader>dw, <Leader>dd via the doubled-key
-- convention) skips the unnamed/numbered/small-delete registers entirely,
-- leaving whatever was last yanked or deleted with plain `d`/`dr`/etc.
-- undisturbed for a later paste. Same black-hole-register technique
-- already used in table-mode.lua's <Leader>t' mapping and dr's
-- Insert-mode word-delete (AG-display-line-based-navigation.lua's
-- <M-BS> mapping).
--
-- Default (non-recursive) mapping, matching the rest of this file: the
-- embedded `"` and `d` reach Vim's true register-select and delete
-- operator directly, not whatever `d` might mean through some other
-- mapping.
vim.keymap.set('n', '<Leader>d', [["_d]], { desc = "Delete without yanking" })

-- Visual-mode delete, cursor-position-preserving. Reported 2026-08-08:
-- deleting a characterwise Visual selection on a wrapped display line can
-- leave the cursor at the end of the whole LOGICAL line instead of where
-- the deleted text started (i.e. where `c` would leave it, ready to type
-- a replacement) — inconsistent with this config's overall display-line
-- philosophy (AG-display-line-based-navigation.lua). Couldn't reproduce
-- the drift in headless testing (no real screen there to compute display
-- rows/wrap against — a known headless/live gap, see that file's
-- <C-l> mapping comment for a prior instance), so rather than chase
-- Vim's internal cursor/curswant logic blind, this sidesteps it entirely:
-- capture the selection's buffer-coordinate start (comparing the visual
-- anchor `'v'` against the cursor `'.'` — whichever comes first in the
-- buffer) BEFORE deleting, do the delete, then explicitly place the
-- cursor there, clamped to the resulting line's length (Normal mode
-- can't sit past the last character the way Insert mode can).
--
-- Deliberately scoped to charwise Visual (`mode() == 'v'`) only, per
-- explicit request — linewise Visual (`V`) is left running native `d`
-- unmodified. Every Shift-arrow selection entry point in this config
-- (AG-display-line-based-navigation.lua) uses charwise `v`, never `V`, so
-- this covers the actual selection workflow in use here.
---@param blackhole boolean use the black-hole register instead of the unnamed one
local function visual_delete_preserve_cursor(blackhole)
  if vim.fn.mode() ~= 'v' then
    vim.cmd('normal! ' .. (blackhole and '"_d' or 'd'))
    return
  end

  local anchor = vim.fn.getpos('v')
  local cursor = vim.fn.getpos('.')
  local start = anchor
  if cursor[2] < anchor[2] or (cursor[2] == anchor[2] and cursor[3] < anchor[3]) then
    start = cursor
  end
  local start_line, start_col = start[2], start[3] - 1 -- getpos col is 1-indexed

  vim.cmd('normal! ' .. (blackhole and '"_d' or 'd'))

  local line_len = #vim.fn.getline(start_line)
  if start_col >= line_len then
    start_col = math.max(line_len - 1, 0)
  end
  pcall(vim.api.nvim_win_set_cursor, 0, { start_line, start_col })
end

vim.keymap.set('v', 'd', function() visual_delete_preserve_cursor(false) end,
  { desc = "Delete selection (cursor lands where `c` would leave it)" })
vim.keymap.set('v', '<Leader>d', function() visual_delete_preserve_cursor(true) end,
  { desc = "Delete selection without yanking" })

-- Backspace deletes the Visual selection to the black hole register —
-- standard macOS text-editing convention (Backspace/Delete removes a
-- selection), extending the "macOS-style" editing this config already
-- leans into elsewhere (AG-display-line-based-navigation.lua). Shares
-- the same cursor-preserving logic as <Leader>d above rather than
-- native `"_d`, for the same reason.
vim.keymap.set('v', '<BS>', function() visual_delete_preserve_cursor(true) end,
  { desc = "Delete selection without yanking (Backspace)" })

-- c = change without yanking. Same black-hole-register technique as
-- <Leader>d above, applied to the `c` operator instead: `"_c` in Normal
-- mode (e.g. <Leader>cw, <Leader>cc) or Visual mode (replace the
-- selection) both drop into Insert mode as `c` normally does, but the
-- replaced text is discarded into the black hole register rather than
-- overwriting the unnamed/numbered registers.
vim.keymap.set({ 'n', 'v' }, '<Leader>c', [["_c]], { desc = "Change without yanking" })
