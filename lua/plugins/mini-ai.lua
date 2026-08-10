-- ~/.config/nvim/lua/plugins/mini-ai.lua
--
-- mini.ai (echasnovski/mini.ai): extended/improved "around"/"inner" text
-- objects (ip, ap, iq, aq, etc.) plus support for custom ones. Installed
-- standalone (not the full echasnovski/mini.nvim suite), same reasoning as
-- mini-move.lua/mini-surround.lua: only pull in the one module actually
-- wanted.
--
-- The only reason this was added: to replace mini.ai's own built-in `s`
-- (sentence) text object with AG-newline-sentence-textobject.lua, which
-- treats a bare newline as a hard sentence boundary (native Vim/mini.ai
-- sentence detection lets a sentence run across a line break if the line
-- has no terminal punctuation before the newline — wrong for this config's
-- wrapped-prose editing, where a display row/logical line typically holds
-- a complete thought). See that module's header comment for the fix
-- history and known limitations (inherits Vim's own "abbreviation before
-- whitespace still counts as a boundary" quirk, e.g. "Dr. Smith" — not
-- something this can distinguish either, same as upstream).
--
-- Using mini.ai's own upstream defaults for everything else (gen_spec.*
-- built-ins for brackets/quotes/etc., default search_method) — no reason
-- to touch those, only `custom_textobjects.s` is overridden.
return {
  "echasnovski/mini.ai",
  version = false,
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    custom_textobjects = {
      s = require("config.AG-newline-sentence-textobject").sentence,
    },
  },
}
