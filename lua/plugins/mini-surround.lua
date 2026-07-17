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
  event = { "BufReadPost", "BufNewFile" },
  opts = {},
}
