-- ~/.config/nvim/lua/config/AG-collapse-blank-lines.lua
--
-- <Leader>1 collapses every run of 2+ newlines (i.e. blank-line paragraph
-- breaks) down to a single newline, in Visual mode over the selection, or
-- in Normal mode over the whole buffer (nothing to select, so select it
-- first).
--
-- Deliberately STRING rhs's, not Lua functions: pressing `:` while still in
-- Visual mode is what makes Vim auto-populate the '<,'> range and set the
-- '< / '> marks from the live selection in the first place. A Lua function
-- callback runs without that ':'-triggered mark-setting ever happening, so
-- '< / '> would be stale/unset instead. See AG-slugify.lua for the same
-- pattern with a fuller writeup (confirmed via headless testing there).
--
-- Normal-mode variant just prepends `ggVG` to select the whole buffer in
-- Visual mode first, then falls into the same ':'-triggered range mechanic.
--
-- \n in the search pattern matches a newline; \r in the replacement is what
-- actually inserts one (\n in the replacement would insert a null byte
-- instead) -- that asymmetry is normal Vim regex behavior, not a typo.
vim.keymap.set('x', '<Leader>1', [[:s/\n\n\+/\r/g<CR>]],
  { desc = 'Collapse blank lines to a single newline (selection)' })

vim.keymap.set('n', '<Leader>1', [[ggVG:s/\n\n\+/\r/g<CR>]],
  { desc = 'Collapse blank lines to a single newline (whole buffer)' })
