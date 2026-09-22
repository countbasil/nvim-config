-- ~/.config/nvim/lua/plugins/mini-surround.lua
--
-- mini.surround (echasnovski/mini.surround): add/delete/replace surrounding
-- pairs — quotes, brackets, tags, or any custom character. Installed
-- standalone (not the full echasnovski/mini.nvim suite), same reasoning as
-- mini-move.lua: only pull in the one module actually wanted.
--
-- Using the plugin's own upstream defaults below (checked against the
-- actually-installed source this time, not memory — mini-move.lua and
-- autolist.lua both got their defaults right from memory, but autolist's
-- `dd`/`d` API turned out to have changed upstream and crashed on first
-- use, caught only via headless testing; not worth risking twice).
-- Confirmed no collision with anything else in this config: nothing here
-- maps any `s`-prefixed key already.
--
--   sa{motion/textobject}{char}  add surrounding, e.g. saiw) -> (word)
--   sd{char}                     delete surrounding, e.g. sd) removes ()
--   sr{char}{new_char}           replace surrounding, e.g. sr)] -> []
--   sf{char} / sF{char}          find surrounding to the right/left
--   sh{char}                     briefly highlight the surrounding
--
-- In Visual mode, select text first, then `sa{char}` wraps the selection.
-- `{char}` can be a literal punctuation character (), [], {}, "", '', or a
-- letter for tag/function-call surroundings (t = tag, f = function call).
--
-- To customize: any `mappings` entry can be changed or set to `""` to
-- disable it (e.g. if `s` ever gets reused for something else in this
-- config). Full option list: `:help MiniSurround.config`.
return {
  "echasnovski/mini.surround",
  version = false,
  -- Eager (not event-lazy-loaded): a brand-new UNNAMED buffer fires
  -- neither BufReadPost nor BufNewFile (see mini-move.lua's identical
  -- fix, 2026-09-22, for the full mechanism), so `event = {
  -- "BufReadPost", "BufNewFile" }` left every sa/sd/sr/sf/sF/sh mapping
  -- unbound there — confirmed via headless test 2026-09-23: `saiw)` in a
  -- fresh unnamed buffer silently ran as plain `s` (substitute char)
  -- instead, typing "aiw)" as literal replacement text. `s` being a real
  -- Vim command on its own is what made this look like "s doesn't do
  -- anything" rather than an obvious error.
  lazy = false,
  opts = {},
}
