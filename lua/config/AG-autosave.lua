-- =============================================================
-- Data-loss prevention: persistent undo, backup copies, autosave,
-- and auto-persisting brand-new unnamed buffers.
-- =============================================================
-- Applies to all buffers/filetypes (not just prose) — this nvim config
-- is prose-focused, but there's no reason to leave code scratch buffers
-- unprotected just because "real" code editing usually happens in
-- VS Code/Xcode instead.

local M = {}

function M.setup()
  -- clear = true: makes setup() safe to call more than once (e.g. via
  -- <Leader>rc re-sourcing init.lua) by wiping this group's autocmds
  -- before re-creating them, instead of piling up duplicate copies.
  local augroup = vim.api.nvim_create_augroup('AGAutosave', { clear = true })

  -- ---------------------------------------------------------
  -- Persistent undo: undo history survives closing/reopening a file.
  -- ---------------------------------------------------------
  local undodir = vim.fn.stdpath('state') .. '/undo'
  vim.fn.mkdir(undodir, 'p')
  vim.opt.undofile = true
  vim.opt.undodir = undodir

  -- ---------------------------------------------------------
  -- Backup copies: keep a `~`-style pre-overwrite snapshot of every
  -- file, centralized (not scattered next to the original) and keyed
  -- by full path (trailing `//`) so same-named files in different
  -- directories don't collide.
  -- ---------------------------------------------------------
  local backupdir = vim.fn.stdpath('state') .. '/backup'
  vim.fn.mkdir(backupdir, 'p')
  vim.opt.backup = true
  vim.opt.backupdir = backupdir .. '//'

  -- ---------------------------------------------------------
  -- Autosave already-named buffers.
  --
  -- Debounced: each edit (re)schedules a save 5s out; a further edit
  -- before it fires cancels and reschedules, so it only actually runs
  -- once you've paused for 5s — nothing happens while idle or mid-typing.
  -- Deliberately not CursorHold/'updatetime': that couples this to a
  -- global option which also controls swapfile write frequency, and
  -- there's no reason to touch a global for a save interval this module
  -- owns. Also deliberately not TextChanged(I) doing the write directly,
  -- since that fires on essentially every keystroke (a disk write, and
  -- for files under ag-buffer/ a OneDrive sync event, per character
  -- typed). InsertLeave/FocusLost cancel any pending debounce and save
  -- immediately instead, since those are already natural stopping points.
  --
  -- The pending timer handle is stashed on _G (not a local/upvalue) so
  -- that a <Leader>rc reload — which clears this module from
  -- package.loaded and re-executes the whole file — can find and cancel
  -- a still-pending timer from the previous load. Without this, a reload
  -- mid-debounce would leak a timer running independently of the new
  -- module instance, since libuv timers aren't tied to Lua's module cache.
  -- ---------------------------------------------------------
  local AUTOSAVE_DEBOUNCE_MS = 5000

  local function autosave()
    -- buftype ~= '': terminal/quickfix/nofile/etc — not a real file buffer.
    -- filename == '': unnamed buffer — handled separately below, since
    -- `:update` has no path to write to yet.
    if vim.bo.buftype ~= '' or vim.api.nvim_buf_get_name(0) == '' then
      return
    end
    -- `update` (vs `write`) only writes if 'modified' is set, so this is
    -- a cheap no-op if nothing actually changed.
    pcall(vim.cmd.update)
  end

  local function cancel_pending_autosave()
    if _G.__ag_autosave_timer then
      pcall(function()
        _G.__ag_autosave_timer:stop()
        _G.__ag_autosave_timer:close()
      end)
      _G.__ag_autosave_timer = nil
    end
  end

  -- Clean up a debounce timer left pending by a previous setup() call
  -- (e.g. a reload that happened mid-debounce), rather than leaking it.
  cancel_pending_autosave()

  local function schedule_autosave()
    cancel_pending_autosave()
    _G.__ag_autosave_timer = vim.uv.new_timer()
    _G.__ag_autosave_timer:start(
      AUTOSAVE_DEBOUNCE_MS,
      0,
      vim.schedule_wrap(function()
        autosave()
        _G.__ag_autosave_timer = nil
      end)
    )
  end

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = augroup,
    callback = schedule_autosave,
    desc = 'Schedule an autosave 5s after the last edit',
  })

  vim.api.nvim_create_autocmd({ 'InsertLeave', 'FocusLost' }, {
    group = augroup,
    callback = function()
      cancel_pending_autosave()
      autosave()
    end,
    desc = 'Autosave immediately on leaving insert mode / losing focus',
  })

  -- ---------------------------------------------------------
  -- Final safety net: flush any pending autosave immediately when
  -- Neovim is about to exit, instead of leaving it to the 5s debounce.
  --
  -- Added 2026-08-09 after investigating a real data-loss report (the
  -- last few seconds of typing in a buffer were missing after a VimR
  -- restart). Evidence pointed at a genuine gap here, not a fluke: a
  -- leftover, undeleted .swp file for that buffer (Neovim always
  -- deletes its own swapfile on a clean exit, so a surviving one means
  -- the previous session ended abruptly) and no VimLeavePre/ExitPre
  -- autocmd anywhere in this module to force a final write before
  -- exiting. Without one, an edit landing inside the 5s debounce window
  -- (with no intervening InsertLeave/FocusLost — e.g. quitting straight
  -- out of Insert mode) was only saved if nothing interrupted that
  -- 5-second wait. This can't help against a true crash or `kill -9` —
  -- no autocmd fires for those, by definition — but it closes the more
  -- common gap of a normal `:qa`/Cmd+Q racing the debounce.
  --
  -- `:wall` (not a loop calling autosave() per buffer) covers every
  -- modified, already-named buffer in one call, matching Vim's own
  -- built-in "save everything" semantics. Unnamed buffers don't need
  -- separate handling here: persist_new_buffer() below already gives a
  -- new buffer a real filename on its very first edit, so by the time
  -- VimLeavePre fires any buffer with actual content already has one.
  -- ---------------------------------------------------------
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = augroup,
    callback = function()
      cancel_pending_autosave()
      pcall(vim.cmd, 'silent! wall')
    end,
    desc = 'Flush any pending autosave before Neovim exits',
  })

  -- ---------------------------------------------------------
  -- Auto-persist brand-new unnamed buffers on first edit.
  --
  -- Fires immediately on the first character typed (not throttled like
  -- the autosave above) because this is the one-time "give this buffer
  -- a real file on disk" action, not a recurring save — waiting for a
  -- typing pause would defeat the point of protecting against a crash
  -- that happens before you ever pause. A buffer-local flag makes sure
  -- it only fires once per buffer even though TextChanged(I) fires on
  -- every keystroke.
  --
  -- Target dir is synced via OneDrive (HIPAA-compliant per Aaron), so
  -- this survives local disk loss too, not just a crash.
  -- ---------------------------------------------------------
  local buffer_dir = vim.fn.expand(
    '~/Library/CloudStorage/OneDrive-UW/ag-buffer'
  )

  local function unique_path(ext)
    local base = os.date('%Y-%m-%d_%H%M%S')
    local path = buffer_dir .. '/' .. base .. ext
    local suffix = 2
    -- Guards against two new buffers created within the same second.
    while vim.uv.fs_stat(path) do
      path = buffer_dir .. '/' .. base .. '_' .. suffix .. ext
      suffix = suffix + 1
    end
    return path
  end

  local function persist_new_buffer()
    if vim.b.ag_persisted then
      return
    end
    if vim.bo.buftype ~= '' or vim.api.nvim_buf_get_name(0) ~= '' then
      return
    end
    vim.b.ag_persisted = true

    vim.fn.mkdir(buffer_dir, 'p')
    -- filetype is usually still unset for a genuinely new buffer; default
    -- to .md since that's this config's primary use case.
    local ext = vim.bo.filetype == '' and '.md' or ('.' .. vim.bo.filetype)
    local path = unique_path(ext)

    -- keepalt: don't clobber the alternate-file (`#`) register with this
    -- new name, matching what a manual `:w path` would do.
    pcall(vim.cmd, 'keepalt write ' .. vim.fn.fnameescape(path))
  end

  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    group = augroup,
    callback = persist_new_buffer,
    -- nested: without this, the `keepalt write` above wouldn't cascade
    -- into firing BufWritePost — Neovim disables autocmds triggering
    -- further autocmds by default, and the lcd-to-file's-directory
    -- autocmd (autocmds.lua) depends on BufWritePost to pick up the
    -- new buffer's directory. Without nested, the write still succeeds,
    -- but `:pwd` silently stays wherever nvim was launched from.
    nested = true,
    desc = 'Auto-persist a new unnamed buffer to ag-buffer/ on first edit',
  })
end

return M
