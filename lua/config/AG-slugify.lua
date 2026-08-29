-- ~/.config/nvim/lua/config/AG-slugify.lua
--
-- Visual mode: <leader>- replaces every space in the selection with a dash.
-- \%V restricts the match to the visual-selection bounds (so a
-- character/block-wise selection only touches text actually selected, not
-- the whole line); the '<,'> range makes the substitute run across every
-- line the selection spans, not just the cursor's line.
vim.keymap.set('x', '<leader>-', function()
  vim.cmd([['<,'>s/\%V /-/g]])
end, { desc = 'Replace spaces with dashes in selection' })
