-- ~/.config/nvim/lua/config/lazy.lua
--
-- This file bootstraps lazy.nvim (clones it from GitHub the first time
-- nvim starts if it isn't present yet), then tells it to load every
-- plugin spec file found under lua/plugins/*.lua.
--
-- You do NOT need to `git clone` lazy.nvim yourself — this code does it
-- for you on first launch.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  -- lazy.nvim isn't installed yet: clone it.
  -- --filter=blob:none makes git skip downloading file contents until
  -- needed, so the clone is fast.
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- track the latest stable release, not main
    lazypath,
  })
end

-- Prepend lazy.nvim to Neovim's 'runtimepath' so `require("lazy")` below
-- can find it.
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  -- Every .lua file inside lua/plugins/ is expected to `return { ... }`
  -- a plugin spec (or list of specs). lazy.nvim will find and load them
  -- all automatically — you don't list them here individually.
  spec = { { import = "plugins" } },

  -- Generates lua/../lazy-lock.json pinning exact plugin commits, so
  -- `:Lazy restore` can reproduce your setup elsewhere (e.g. another Mac).
  install = { colorscheme = {} },
  checker = { enabled = false }, -- set true if you want auto update-checks
})
