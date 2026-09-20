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
      -- Anchor content near the top instead of snacks' default vertical
      -- centering (dashboard.row is the literal number of blank lines
      -- padded above the content when set — see snacks/dashboard.lua's
      -- `self.row = self.opts.row or <computed center>`; nil is what
      -- triggers centering, so any number, including 1, opts out of it).
      row = 1,
      -- Move each row's shortcut key from the right edge to right after
      -- its icon, on the left, instead (reported 2026-08-16). There's no
      -- direct opts knob for this — snacks/dashboard.lua's D:format
      -- hardcodes icon into the left-aligned column and key into the
      -- right-aligned one — so this folds the key into the icon
      -- formatter's own output instead (a real per-field customization
      -- point) and blanks the key formatter so nothing is left on the
      -- right. Applies uniformly to every section (keys AND recent_files)
      -- since both go through the same two formatters.
      --
      -- Note on the file icons themselves (also asked about 2026-08-16):
      -- they currently carry no real information — every recent file
      -- renders the identical generic glyph (confirmed by rendering the
      -- dashboard headlessly and inspecting the buffer), because this
      -- config has neither mini.icons nor nvim-web-devicons installed for
      -- Snacks.util.icon to draw a real per-filetype icon from. Left as a
      -- generic marker rather than removed, since the ask was to
      -- reposition them, not drop them — installing mini.icons would make
      -- them meaningful if wanted later.
      formats = {
        icon = function(item)
          local icon
          if item.file and (item.icon == "file" or item.icon == "directory") then
            icon = Snacks.dashboard.icon(item.file, item.icon)
          else
            icon = { item.icon or " ", hl = "icon" }
          end
          if item.key then
            return { icon[1] .. " " .. item.key, hl = icon.hl }
          end
          return icon
        end,
        key = function() return { "" } end,
      },
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
          limit = 20,
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
    { "<Leader>fe", function() Snacks.picker.explorer() end, desc = "File Explorer" },
    -- Rename the current buffer's file on disk. LSP-aware (unlike vim-eunuch's
    -- :Rename/:Move, which it replaces): notifies willRenameFiles/didRenameFiles
    -- so any attached LSP client can update references, then moves the file and
    -- re-points the buffer at the new path.
    --
    -- This is a custom prompt rather than a bare call to
    -- Snacks.rename.rename_file() (which has no hook to customize its
    -- internal vim.ui.input call): that plugin default prompts with the
    -- FULL filename (incl. extension) as pre-filled text, cursor at the
    -- end, positioned near the top of the screen with only a subtle
    -- border — easy to miss (reported 2026-08-16: looked like nothing was
    -- happening because the prompt rendered outside where the cmdline
    -- normally appears at the bottom).
    --
    -- Fixes applied here:
    --  1. Explicit rounded border + title, positioned near the bottom
    --     (win.row = -3; negative row is bottom-relative per snacks.win's
    --     `pos()` — see snacks/win.lua) so it's unmistakable.
    --  2. Full filename shown (nothing pre-cleared), cursor placed at the
    --     end of the STEM — i.e. right before the extension — instead of
    --     upstream's cursor-at-very-end. Typing at that point appends a
    --     suffix to the name while leaving the extension untouched. A real
    --     Visual-mode "select the basename, type to replace" isn't
    --     achievable here: snacks.input's prompt buffer (buftype=prompt)
    --     is Insert-mode-only, and Insert mode has no concept of "selected
    --     text the next keystroke overwrites" the way a GUI rename box
    --     does — so the full name stays visible and editable rather than
    --     being pre-cleared (tried first, rejected 2026-08-16: Aaron wants
    --     the existing name intact to build on, not gone).
    --  3. Dotfiles/extensionless files (no real "extension" to protect)
    --     fall back to plain cursor-at-end of the whole name.
    --  4. If the current name is a date slug (AG-autosave.lua's
    --     auto-persist convention for brand-new buffers, YYYY-MM-DD_HHMMSS
    --     or YYYY-MM-DD_HHMMSS_N — see AG-autosave.lua's unique_path()),
    --     it carries no descriptive info, so the buffer's first line is
    --     offered as the starting stem instead (still fully editable, same
    --     as the name-intact behavior above) with characters illegal or
    --     misleading in a filename swapped out: "/" (POSIX-illegal) and
    --     ":" (Finder silently remaps this to "/" internally on
    --     HFS+/APFS, so it's avoided too) become "-", other control
    --     characters are dropped, and surrounding whitespace is trimmed.
    {
      "<Leader>fR",
      function()
        local from = vim.api.nvim_buf_get_name(0)
        if from == "" then
          return vim.notify("No file in current buffer", vim.log.levels.WARN)
        end
        from = vim.fn.fnamemodify(from, ":p")
        local dir = vim.fn.fnamemodify(from, ":h")
        local basename = vim.fn.fnamemodify(from, ":t")
        local stem = basename:match("^(.-)%.[^.]*$")
        local ext = stem and basename:sub(#stem + 1) or ""

        local default_stem = stem or basename
        -- Lua patterns have no `|` alternation and no quantifier on a
        -- parenthesized group (unlike regex, "(_%d+)?" is NOT "optional
        -- _%d+" — it silently never matches), hence two explicit checks
        -- for "with" and "without" the collision suffix.
        local is_date_slug = default_stem:match("^%d%d%d%d%-%d%d%-%d%d_%d%d%d%d%d%d$")
          or default_stem:match("^%d%d%d%d%-%d%d%-%d%d_%d%d%d%d%d%d_%d+$")
        if is_date_slug then
          local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ""
          local candidate = first_line:gsub("[/:]", "-"):gsub("%c", "")
          candidate = candidate:gsub("^%s+", ""):gsub("%s+$", "")
          if candidate ~= "" then
            default_stem = candidate
          end
        end
        local default = default_stem .. ext

        local cursor_col = #default_stem

        local win = Snacks.input({
          prompt = "New File Name",
          default = default,
          win = {
            border = "rounded",
            title_pos = "center",
            row = -3,
          },
        }, function(value)
          if not value or value == "" or value == basename then
            return
          end
          Snacks.rename.rename_file({ from = from, to = dir .. "/" .. value })
        end)

        vim.schedule(function()
          if win and win.win and vim.api.nvim_win_is_valid(win.win) then
            vim.api.nvim_win_set_cursor(win.win, { 1, cursor_col })
          end
        end)
      end,
      desc = "Rename File",
    },
    -- Delete the current buffer's file on disk and close the buffer. Replaces
    -- vim-eunuch's :Delete. Permanent (not trash), matching :Delete's own
    -- behavior — mirrors what the explorer's `d` action does, just without
    -- needing to open the explorer first.
    {
      "<Leader>fD",
      function()
        local file = vim.api.nvim_buf_get_name(0)
        if file == "" then
          return vim.notify("No file in current buffer", vim.log.levels.WARN)
        end
        local choice = vim.fn.confirm("Delete " .. vim.fn.fnamemodify(file, ":~:.") .. "?", "&Yes\n&No", 2)
        if choice ~= 1 then return end
        if vim.fn.delete(file) ~= 0 then
          return vim.notify("Failed to delete " .. file, vim.log.levels.ERROR)
        end
        Snacks.bufdelete({ file = file, force = true })
      end,
      desc = "Delete File",
    },
  },
}
