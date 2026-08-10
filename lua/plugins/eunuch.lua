-- lua/plugins/eunuch.lua
-- vim-eunuch: Unix shell command sugar as Ex commands (:Delete, :Rename,
-- :Move, :Mkdir, :Chmod, :SudoWrite, etc.) — keeps file-management operations
-- inside Vim instead of dropping to a shell.
--
-- Lazy-loaded on `cmd`: pure Vimscript, no autocmd/ftplugin behavior needed
-- until one of its commands is actually invoked.
return {
  "tpope/vim-eunuch",
  cmd = {
    "Mkdir",     -- create directory, including intermediate ones
    "Unlink",    -- delete file, keep buffer
    "Remove",    -- alias for :Unlink
    "Delete",    -- delete buffer and file together
    "Copy",      -- copy current file to a destination
    "Move",      -- rename/move file on disk, update buffer name
    "Duplicate", -- like :Copy, but relative to current file's directory
    "Rename",    -- like :Move, but relative to current file's directory
    "Chmod",     -- change permissions of current file
    "Cfind",     -- shell find, results into quickfix
    "Clocate",   -- shell locate, results into quickfix
    "Lfind",     -- like :Cfind, into location list
    "Llocate",   -- like :Clocate, into location list
    "SudoWrite", -- write file with sudo
    "SudoEdit",  -- edit file with sudo
    "Wall",      -- write all windows/tabs with unsaved changes
    "W",         -- alias for :Wall
  },
}
