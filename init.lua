-- ajg modifications for vim/nvim

-- set leader (like meta key) to space
vim.g.mapleader = " "

-- sync clipboard to Mac
vim.opt.clipboard = "unnamedplus"


-- appearance
vim.opt.background = "dark"
vim.cmd("colorscheme slate")


-----------------------------
-- leader-key functions
-----------------------------

-- rc = reload init.lua
vim.keymap.set('n', '<Leader>rc', function()  
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
