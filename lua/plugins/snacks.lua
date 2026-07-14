-- ~/.config/nvim/lua/plugins/snacks.lua
--
-- snacks.nvim spec. Named after the plugin (not just "dashboard") since
-- this file's `opts` table is meant to grow to cover other snacks
-- modules too (e.g. the picker), not just the dashboard.
--
-- Requires lazy.nvim as your plugin manager. If you're on packer or
-- something else, the `opts` table below is the part that matters —
-- just pass it to snacks.nvim's setup() call instead.

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    dashboard = {
      enabled = true,
      preset = {
        -- Keymaps shown on the dashboard itself
        keys = {
          { icon = " ", key = "f", desc = "Find File",
            action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "r", desc = "Recent Files",
            action = ":lua Snacks.dashboard.pick('oldfiles')" },
          { icon = " ", key = "n", desc = "New File",
            action = ":ene | startinsert" },
          { icon = " ", key = "q", desc = "Quit",
            action = ":qa" },
        },
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        {
          icon = " ",
          title = "Recent Files",
          section = "recent_files",
          indent = 2,
          padding = 1,
          -- how many entries to show
          limit = 8,
          -- set to true to only show files under the current cwd
          cwd = false,
        },
        { section = "startup" },
      },
    },
    -- these two are what make `recent_files` and the `f`/`r` keys work
    picker = { enabled = true },
    input = { enabled = true },
  },
  keys = {
    -- General-purpose file picker, usable from any buffer (not just the dashboard)
    { "<Leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
    { "<Leader>fr", function() Snacks.picker.recent() end, desc = "Recent Files" },
    { "<Leader>fg", function() Snacks.picker.grep() end, desc = "Grep (live)" },
    { "<Leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
  },
}
