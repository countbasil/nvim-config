-- ~/.config/nvim/lua/config/titlecase.lua
--
-- Adds `gl` as a title-case operator, sibling to the built-in gu / gU / g~.
-- ("l" as in the tail end of "titLe" — z stays free for other use.)
-- Works with any motion or text object: gliw, glap, gl$, glj, visual `gl`, etc.
--
-- Mechanism: identical to how gu/gU work internally. We set vim.o.operatorfunc
-- to point at a Lua function, then invoke `g@` which asks Neovim to grab a
-- motion from the user and, once it has the resulting range, call our
-- function with that range available via the '[ and '] marks.

local M = {}

-- Title-cases a string: uppercases the first letter of every "word",
-- where a word boundary is any run of non-alphanumeric characters.
-- Mirrors the logic of `:s/\<./\u&/g` but as a plain Lua string op so it
-- works line-by-line inside the operatorfunc without touching the : command line.
local function titlecase_str(s)
  return (s:gsub("(%a)([%w']*)", function(first, rest)
    return first:upper() .. rest:lower()
  end))
end

-- The operatorfunc. `motion_type` is "char", "line", or "block" — passed in
-- by Neovim based on what motion/text-object the user combined `gz` with.
function M.titlecase_opfunc(motion_type)
  local start_pos = vim.api.nvim_buf_get_mark(0, "[")
  local end_pos = vim.api.nvim_buf_get_mark(0, "]")

  if motion_type == "line" then
    local start_line, end_line = start_pos[1], end_pos[1]
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    for i, line in ipairs(lines) do
      lines[i] = titlecase_str(line)
    end
    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
  elseif motion_type == "char" then
    local start_line, start_col = start_pos[1], start_pos[2]
    local end_line, end_col = end_pos[1], end_pos[2]

    if start_line == end_line then
      local line = vim.api.nvim_buf_get_lines(0, start_line - 1, start_line, false)[1]
      local before = line:sub(1, start_col)
      local middle = line:sub(start_col + 1, end_col + 1)
      local after = line:sub(end_col + 2)
      vim.api.nvim_buf_set_lines(0, start_line - 1, start_line, false, { before .. titlecase_str(middle) .. after })
    else
      local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
      -- First line: from start_col to end
      local first = lines[1]
      lines[1] = first:sub(1, start_col) .. titlecase_str(first:sub(start_col + 1))
      -- Middle lines: fully title-cased
      for i = 2, #lines - 1 do
        lines[i] = titlecase_str(lines[i])
      end
      -- Last line: from start to end_col
      local last = lines[#lines]
      lines[#lines] = titlecase_str(last:sub(1, end_col + 1)) .. last:sub(end_col + 2)
      vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
    end
  elseif motion_type == "block" then
    -- Visual-block support: title-case only the columns spanned by the block.
    local start_line, start_col = start_pos[1], start_pos[2]
    local end_line, end_col = end_pos[1], end_pos[2]
    local lo_col, hi_col = math.min(start_col, end_col), math.max(start_col, end_col)
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    for i, line in ipairs(lines) do
      local before = line:sub(1, lo_col)
      local middle = line:sub(lo_col + 1, hi_col + 1)
      local after = line:sub(hi_col + 2)
      lines[i] = before .. titlecase_str(middle) .. after
    end
    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
  end
end

function M.setup()
  -- Normal mode: `gl` + motion/text-object, e.g. gliw, glap, gl$, glj
  vim.keymap.set("n", "gl", function()
    vim.o.operatorfunc = "v:lua.require'config.titlecase'.titlecase_opfunc"
    return "g@"
  end, { expr = true, desc = "Title-case operator" })

  -- Doubled form for whole line, e.g. gll, matching guu / gUU / g~~ convention
  vim.keymap.set("n", "gll", function()
    vim.o.operatorfunc = "v:lua.require'config.titlecase'.titlecase_opfunc"
    return "g@_"
  end, { expr = true, desc = "Title-case current line" })

  -- Visual mode: select text, hit gl
  vim.keymap.set("v", "gl", function()
    vim.o.operatorfunc = "v:lua.require'config.titlecase'.titlecase_opfunc"
    return "g@"
  end, { expr = true, desc = "Title-case selection" })
end

return M
