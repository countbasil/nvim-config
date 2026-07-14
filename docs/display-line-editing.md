# Neovim Config — Display-Line Editing Setup

## Environment
- **Config root**: `~/.config/nvim/` (confirmed via `stdpath('config')`)
- **Structure**: modular, using `lua/` subdirectory convention:
  ```
  ~/.config/nvim/
  ├── init.lua
  └── lua/
      └── config/
          ├── options.lua
          ├── keymaps.lua      <- work described below lives here
          └── autocmds.lua
  ```
- **Plugin manager**: none installed yet (lazy.nvim was discussed as a likely future choice but is NOT currently set up — don't assume its presence)
- **Target environments — must work in BOTH**:
  1. **VimR** (macOS GUI wrapper, bundled/embedded Neovim runtime — CI-built paths like `/Users/runner/work/vimr/vimr/Neovim/.deps/...`)
  2. **Neovim in iTerm2** (standard terminal Neovim, likely via Homebrew) — this is the primary reference implementation and should be treated as the "correct" baseline when the two environments diverge in behavior
- **Primary use case for this editor**: prose/Markdown/JSON editing — NOT general code editing (VS Code and Xcode handle that). This context shaped several design decisions below.
- **Dotfiles**: managed via GNU Stow, git-backed — this config directory is expected to be portable across machines via that repo.

## Goal of the Work
Make normal-mode (and visual/operator-pending) navigation and editing respect **display lines** (visual screen rows, relevant when `wrap` is on) rather than **logical lines** (actual buffer lines, which for wrapped prose paragraphs can span many screen rows).

## Key Design Decisions

### 1. Full swap of `j`/`k`/`0`/`$` with `gj`/`gk`/`g0`/`g$`
- `j`/`k`/`0`/`$` → now move/operate by **display line** (the new default, since editor is primarily used for wrapped prose)
- `gj`/`gk`/`g0`/`g$` → preserved as the **escape hatch** to original logical-line behavior
- Applied across **all three modes**: `n` (normal), `v` (visual), `o` (operator-pending)
  - Operator-pending inclusion was a deliberate correction mid-design: without it, `d$` on a wrapped line would delete to the end of the *entire logical line/paragraph*, not just the visible row — a significant footgun for prose editing that defeats the purpose of the remap.

### 2. Custom `dr` ("delete row") function
- Native `dd` **cannot** be redefined to mean "delete display row" — `dd` is a linewise operator baked into Vim's core operator model; there's no buffer-level concept of a "display row" as an addressable unit the way there is for a logical line
- Solution: a standalone Lua function bound to `dr` (not overriding `dd`), so plugins/macros that assume `dd` = "delete whole logical line" remain unaffected
- **Register handling** was explicitly designed to match native Vim conventions:
  - Writes to `"` (unnamed register)
  - Writes to `"-` (small-delete register — the register Vim uses for *characterwise* deletes under one line)
  - Deliberately does **NOT** populate `"1`–`"9` (those are reserved for linewise deletes like `dd`/`dj`, and this operation is characterwise, so populating them would be inconsistent with vanilla Vim behavior)
- **Known limitation, not yet implemented**: no dot-repeat (`.`) support. This would require either the `vim-repeat` plugin's API or manually setting `vim.o.operatorfunc` and invoking `dr` as a proper Vim operator rather than a plain keymap function.
- **Also not implemented**: count support (e.g., `3dr` to delete 3 display rows) — current version ignores `vim.v.count`.

### 3. `set startofline` (in `init.lua`)
- Nvim defaults `startofline` **off** (unlike Vim, which defaults it on) — so by default `gg`/`G`/`H`/`M`/`L`/`<C-d>`/`<C-u>` preserve the cursor's previous desired column instead of jumping to the target line's first non-blank
- This is normally a minor cosmetic difference, but combines badly with the display-line remaps above: a large preserved column (e.g. left over from a `g$`/end-of-line on a long line) gets applied to the target logical line, which — if it's a long wrapped paragraph — puts the cursor on a display row partway down the paragraph instead of visually at the top/bottom, even though `gg`/`G` did land on the correct logical line
- Fix: `vim.opt.startofline = true`, restoring the classic-Vim behavior so `gg`/`G` always land at the first non-blank

## Current File Contents

### `~/.config/nvim/lua/config/keymaps.lua`
```lua
-- =============================================================
-- Display-line-based navigation & operators
-- =============================================================
vim.keymap.set({ 'n', 'v', 'o' }, 'j', 'gj')
vim.keymap.set({ 'n', 'v', 'o' }, 'k', 'gk')
vim.keymap.set({ 'n', 'v', 'o' }, 'gj', 'j')
vim.keymap.set({ 'n', 'v', 'o' }, 'gk', 'k')

vim.keymap.set({ 'n', 'v', 'o' }, '0', 'g0')
vim.keymap.set({ 'n', 'v', 'o' }, '$', 'g$')
vim.keymap.set({ 'n', 'v', 'o' }, 'g0', '0')
vim.keymap.set({ 'n', 'v', 'o' }, 'g$', '$')

-- =============================================================
-- Delete display row (dr)
-- =============================================================
local function delete_display_line()
  local line = vim.fn.line('.')

  vim.cmd('normal! g0')
  local start_col = vim.fn.col('.')

  vim.cmd('normal! g$')
  local end_col = vim.fn.col('.')

  local text_lines = vim.api.nvim_buf_get_text(0, line - 1, start_col - 1, line - 1, end_col, {})
  local deleted_text = table.concat(text_lines, '\n')

  vim.fn.setreg('"', deleted_text, 'c')
  vim.fn.setreg('-', deleted_text, 'c')

  vim.api.nvim_buf_set_text(0, line - 1, start_col - 1, line - 1, end_col, { '' })
end

vim.keymap.set('n', 'dr', delete_display_line)
```

### Relevant reload keymap (already in config)
```lua
vim.keymap.set('n', '<Leader>rc', function()
  vim.cmd("source $MYVIMRC")
  print("Config reloaded!")
end, { desc = "Reload config" })
```

## Resolved: VimR `package.path` Bug

Fixed via the `package.path` workaround at the top of `init.lua` (VimR's embedded runtime wasn't reliably populating it from `stdpath('config')`); no further action needed.

## Possible Follow-Up Work (mentioned, not started)
- Dot-repeat (`.`) support for `dr` via `vim.o.operatorfunc` or `vim-repeat`
- Count support for `dr` (e.g., `3dr`)
- Verify all remaps and the `dr` function behave identically in both VimR and terminal Neovim (iTerm2) — no cross-environment testing has been done yet beyond the `package.path` diagnostic itself
