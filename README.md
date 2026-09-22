# Quick reference

Personal Neovim config. Prose/Markdown/JSON-focused; leader = Space. Full
rationale for anything here: [CLAUDE.md](CLAUDE.md). Display-line history:
[docs/display-line-editing.md](docs/display-line-editing.md).

## Deviations from vanilla Vim

| Key(s) | Vanilla | Here |
|---|---|---|
| `j`/`k`/`0`/`$` (N, V) | logical line | **display** line. `gj`/`gk`/`g0`/`g$` = original logical-line behavior |
| `0`/`$`/`Home`/`End` (O, operator-pending) | logical line | display line (so `d$` only eats the visible row) |
| `j`/`k`/arrows (O) | — | **logical** line (unlike `0`/`$` above — `dj`/`d2k` act on real lines) |
| `dd` | delete logical line | unchanged. `dr` = delete display row (new, no dot-repeat/count) |
| `x` (N, V) | fills `""`/`"+` | never touches `""`/`"+`; always lands in `"-`, any size |
| `s`, `c` (any mode, any size) | fills `""`/`"+` | never touches `""`/`"+`; lands in `"-`/`"1` as Vim normally would |
| `d` (any mode, any size) | fills `""`/`"+` | **unchanged** — the one "real cut" key |
| `<CR>` (N) | — | split line at cursor, stay in Insert |
| `<BS>` (N) | — | delete char before cursor, stay in Normal (`X`) |
| `G` bare, no count (N, V) | last line, first non-blank | last line, **end of display line**. `{count}G` unchanged |
| `whichwrap` | `h`/`l` stop at line ends | `h`/`l`/arrows wrap to prev/next line |
| Insert `Cmd+C` | types literal chars | swallowed (`<Nop>`) — stops Superwhisper leaking text |
| `Ctrl+h/j/k/l` | — | mini.move: move line/selection (see below) |

## Leader keymaps

**General**
| Key | Action |
|---|---|
| `<Leader>rc` | Reload config *and* plugin specs (`lua/plugins/*.lua`) |
| `<Leader>cd` | `:cd` to current file's directory |
| `<Leader>w` | Toggle wrap |
| `<Leader>l` | Clear search highlight + redraw |
| `<Leader>d` / `<Leader>c` (N, V) | Delete / change without yanking |
| `<Leader>1` | Collapse blank-line breaks to one newline (V: selection, N: whole buffer) |
| `<leader>-` (V) | Spaces → dashes in selection |

**Files** ([snacks.nvim](lua/plugins/snacks.lua))
| Key | Action |
|---|---|
| `<Leader>ff` / `fr` / `fg` / `fb` / `fe` | Find files / recent / grep / buffers / explorer |
| `<Leader>fR` | Rename current file (LSP-aware). If name is a date-slug, offers the buffer's first line as default |
| `<Leader>fD` | Delete current file + close buffer (permanent) |

**Tables** ([vim-table-mode](lua/plugins/table-mode.lua), markdown/text only)
| Key | Action |
|---|---|
| `<Leader>tm` | Toggle table mode |
| `<Leader>tt` (V) | Tableize selection |
| `<Leader>tr` | Realign table |
| `<Leader>tc` / `tR` | Copy cell / replace cell contents |
| `<Leader>t'`, `⌘'` (N + I) | Fill cell from cell above |
| `Tab`/`S-Tab` (N + I, table mode on) | Next/previous cell |
| `Ctrl+l` (I, table mode on) | Realign |

**Lists** ([autolist.nvim](lua/plugins/autolist.lua), markdown/text only)
| Key | Action |
|---|---|
| `o` / `O` | New line, continue list |
| `<CR>`, `Tab`/`S-Tab` (I) | New bullet / indent+renumber |
| `<Leader>lr` | Force-recalculate numbering |
| `<Leader>ln` / `lp` | Cycle marker type forward/back |
| `<Leader>lb` / `lB` (V) | Bulletize selection / strip markers |
| `>>`, `<<`, `dd`, `d` (V) | Renumber after indent/delete (built-in keys, augmented) |

**Move lines/selections** ([mini.move](lua/plugins/mini-move.lua))
| Key | Action |
|---|---|
| `Ctrl+h/j/k/l` (N, I) | Move current line left/down/up/right |
| `Ctrl+h/l` (V) | Move selection left/right |
| `Ctrl+j/k` (V) | Move selection down/up — always whole logical lines |

**Text objects / editing**
| Key | Action |
|---|---|
| `gl{motion}`, `gll`, `gl` (V) | Titlecase operator (sibling to `gu`/`gU`/`g~`) |
| `sa`/`sd`/`sr`/`sf`/`sF`/`sh` | [mini.surround](lua/plugins/mini-surround.lua): add/delete/replace/find/highlight |
| `ip`/`ap`, `iq`/`aq`, `is`/`as`, etc. | [mini.ai](lua/plugins/mini-ai.lua) text objects. `s` = sentence, **newline always ends it** |

## Mac-style navigation (N, I, V)

Arrows, `Home`/`End`, `Option+←/→` (word), `Cmd+←/→` (display-line start/end);
`Shift+` variants extend a selection. All display-line-based, mirroring the
`j`/`k`/`0`/`$` swap above.

## Background behavior (no keys)

- Autosave: debounced 5s after edits, immediate on `InsertLeave`/focus-lost.
  New unnamed buffers auto-save to `OneDrive-UW/ag-buffer/` on first keystroke.
- aText (system text expansion) disabled during Insert mode.
- Auto `:lcd` to the current file's directory.
- A new tab opens the Snacks dashboard if left blank.

## Plugins

lazy.nvim-managed, `lua/plugins/*.lua`: **snacks.nvim** (dashboard/picker/
explorer/rename), **vim-table-mode**, **mini.move**, **autolist.nvim**,
**mini.surround**, **mini.ai**. Verify against `lua/plugins/` before trusting
this list — it drifts.
