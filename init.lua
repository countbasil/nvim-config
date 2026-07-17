-- ajg modifications for vim/nvim

-- set leader (like meta key) to space
vim.g.mapleader = " "

-- enable lazy.nvim plugin manager
require("config.lazy")

-- enable my tweaks including 
require("config.AG-titlecase").setup()  -- * title case function [maps to `gl`]

-- my display-line [vs file-line] navigation (incl display-line def for `dr`)
require('config.AG-display-line-based-navigation')

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
--  - cd = change explorer's dir to current file's dir
--  - w = word wrap toggle
--  - l = clear search highlight + redraw screen
--
--  [From other files]
--  - t* = table mode functions [table-mode plug-in & AG-table-augmentation config]
--  - f* = file functions find/recent/grep/buffers [snacks]
--  - l* = list functions (bulletize/un-bulletize selection) [autolist.nvim config, markdown/text only]

-- rc = reload config [init.lua]
vim.keymap.set('n', '<Leader>rc', function()
  -- Lua caches every require()d module, so re-sourcing init.lua alone
  -- would just re-run the *cached* (stale) versions of our own config
  -- modules rather than picking up file edits. Clearing every
  -- "config.*" entry here (rather than naming individual files) means
  -- any module added under lua/config/ in the future is covered
  -- automatically, with no need to remember to update this list.
  for name, _ in pairs(package.loaded) do
    if name == 'config' or name:match('^config%.') then
      package.loaded[name] = nil
    end
  end
  vim.cmd("source $MYVIMRC")
  print("Config reloaded!")
end, { desc = "Reload config" })

-- cd = change file explorer directory to current 
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
