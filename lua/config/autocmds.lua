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

-- =============================================================
-- Open the Snacks dashboard in a brand-new, empty tab
-- =============================================================
-- Snacks' own dashboard only opens itself once, automatically, on the
-- `UIEnter` autocmd -- i.e. when Neovim starts with no file arguments
-- (see snacks/dashboard.lua's M.setup(), wired up in snacks/init.lua's
-- per-module UIEnter list). That fires exactly once per session, so it
-- has no equivalent for a brand-new TAB opened mid-session (`:tabnew`,
-- `<C-w>T`) -- those would otherwise land on a bare empty buffer instead
-- of the same dashboard a new window/instance shows.
--
-- Fires on TabNewEntered (after the new tab and its window are already
-- current), not TabNew (fires before the switch, while the old tab is
-- still current) -- otherwise nvim_get_current_buf()/_win() below would
-- refer to the wrong tab.
--
-- Guarded to only fire for a genuinely blank slate -- ordinary buftype,
-- unnamed, unmodified, a single empty line -- mirroring the same checks
-- snacks/dashboard.lua's own M.setup() applies to the startup buffer, so
-- `:tabnew somefile.txt`, `:tab split`, `:tab help foo`, etc. are left
-- alone.
--
-- Snacks.dashboard() is called WITH explicit buf/win (matching how
-- M.setup() opens the startup dashboard) rather than bare. A bare call
-- spawns an entirely new scratch buffer in a floating window layered on
-- top of whatever's already there -- right for summoning the dashboard
-- over existing work, but wrong here: a fresh tab should just BE the
-- dashboard, full-pane, the way a new window/instance is.
vim.api.nvim_create_autocmd('TabNewEntered', {
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()

    if vim.bo[buf].buftype ~= '' then
      return
    end
    if vim.api.nvim_buf_get_name(buf) ~= '' then
      return
    end
    if vim.bo[buf].modified then
      return
    end
    if vim.api.nvim_buf_line_count(buf) > 1
      or (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or '') ~= '' then
      return
    end

    Snacks.dashboard({ buf = buf, win = win })
  end,
  desc = 'Open Snacks dashboard in a brand-new empty tab',
})
