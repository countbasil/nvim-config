-- =============================================================
-- Auto-`lcd` to the current file's directory
-- =============================================================
-- Keeps the *window-local* working directory in sync with whatever
-- file is focused, so relative-path commands (:e, netrw, shell-outs)
-- resolve against the file you're actually looking at rather than
-- wherever Neovim happened to be launched from.
--
-- Uses `:lcd` rather than `vim.opt.autochdir` deliberately: autochdir
-- changes the *global* cwd for every window, so with multiple splits/
-- tabs open on files in different directories, each buffer switch
-- stomps on every other window's idea of "current directory". `:lcd`
-- scopes the change to just the window that triggered it.
--
-- Fires on:
--   - BufEnter / BufWinEnter: covers normal buffer switches (splits,
--     tabs, :b, :e, etc.)
--   - BufWritePost: covers a new/unnamed buffer being written out to
--     a path in a different directory than wherever lcd last pointed
--     — `:w somewhere/else/file.txt` on a brand-new buffer wouldn't
--     otherwise trigger a directory update.
--
-- Guards against buffers where the path doesn't resolve to a real
-- on-disk directory: unnamed buffers (empty filename) and special
-- buftypes (terminal, quickfix, nofile, prompt, help, etc. — anything
-- with a non-empty 'buftype' is not a normal file buffer).

local function lcd_to_file_dir()
  if vim.bo.buftype ~= '' then
    return
  end

  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == '' then
    return
  end

  local dir = vim.fn.fnamemodify(filepath, ':p:h')
  if vim.fn.isdirectory(dir) == 0 then
    return
  end

  pcall(vim.cmd.lcd, dir)
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter', 'BufWritePost' }, {
  callback = lcd_to_file_dir,
  desc = "lcd to current file's directory",
})
