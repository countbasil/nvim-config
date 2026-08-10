-- ~/.config/nvim/lua/config/AG-newline-sentence-textobject.lua
--
-- Newline-aware sentence text object for mini.ai. Registered as the `s`
-- custom text object in lua/plugins/mini-ai.lua, replacing mini.ai's
-- built-in sentence object outright (not a separate key) so `is`/`as`
-- never cross a line boundary — a bare newline is treated the same way
-- Vim treats a blank line: as a hard sentence boundary.
--
-- Started from a draft produced in a separate chat session (2026-08-09)
-- to fix a repro where `dis` on a line with no terminal punctuation
-- before the newline deleted into the following line too. Reviewed and
-- fixed here before wiring in — see git history for what changed from
-- the original draft:
--   - Original had no check for whitespace/EOL after `.`/`!`/`?`, so it
--     was MORE aggressive than native Vim's own sentence rule: "e.g.",
--     "Dr.", "3.14", "example.com", and "..." all falsely split.
--     Confirmed via direct testing against find_sentence_ranges before
--     the fix. Vim's actual rule requires the punctuation (plus any
--     trailing closers) to be followed by whitespace or end-of-line —
--     restored that check below.
--   - Original hardcoded the first range's start at column 1, so `as`
--     on an indented line's first sentence pulled in the leading
--     whitespace/indentation along with it (confirmed on the actual
--     repro line, which has 2 leading spaces). Fixed by skipping
--     leading whitespace before the first range too, same as every
--     later range already did after its predecessor's punctuation.
--     Simpler than Vim's real rule (which includes leading whitespace
--     only when there's no trailing whitespace to grab instead) —
--     deliberately not replicating that nuance, since for this config's
--     prose/Markdown use case indentation should never be swept into a
--     sentence deletion either way.
--   - Original's blank-line guard only checked `line == ''`, missing an
--     all-whitespace line (e.g. a line of just spaces/tabs), which could
--     let `as` return a purely-whitespace region with no equivalent
--     guard to mini.ai's own `is`-returns-nil handling. Broadened to
--     match any all-whitespace line.
--
-- Extended 2026-08-09: a leading Markdown list/blockquote marker (any
-- amount of leading whitespace, then one of `*`/`-`/`>`, then required
-- whitespace — e.g. "- ", "* ", "> ", "  - ") is now skipped the same way
-- leading indentation already was, so `is`/`as` on a list item or
-- blockquote's first sentence doesn't swallow the marker. Anchored to
-- `^` (true start of line) and requires whitespace right after the
-- marker character, so it can't misfire on a marker char used mid-prose
-- (a dash used as a clause separator, a literal `*`/`>` in running text)
-- or on Markdown emphasis/bold (`*word*` has no space after the opening
-- `*`, so it doesn't match). Deliberately only `*`/`-`/`>` per what was
-- asked — not numbered-list markers (`1.`, `2)`, etc.) — and only a
-- single marker, not nested ones (e.g. a list item inside a blockquote,
-- "> - item"); revisit if that's ever needed.

local M = {}

-- Column right after a leading list/blockquote marker ("- ", "* ", "> ",
-- optionally preceded by whitespace), or right after plain leading
-- whitespace if there's no marker. Only meaningful at the true start of
-- a line, so this is only ever called once per line (see `start` in
-- find_sentence_ranges below), never for a later sentence's start
-- mid-line.
local function skip_leading_marker_or_space(line, n)
  local _, marker_end = line:find('^%s*[%*%-%>]%s+')
  if marker_end then
    return marker_end + 1
  end
  local start = 1
  while start <= n and line:sub(start, start):match('%s') do
    start = start + 1
  end
  return start
end

-- Find sentence [start_col, end_col] (1-indexed, inclusive, byte cols)
-- pairs for a single line. `ends` = column right after each
-- terminal-punctuation run (., !, ? + trailing closers), but only when
-- that run is followed by whitespace or end-of-line — matching Vim's own
-- sentence rule (:help sentence) rather than treating every `.`/`!`/`?`
-- as a boundary regardless of context.
local function find_sentence_ranges(line)
  local ends = {}
  local i = 1
  local n = #line
  while i <= n do
    local c = line:sub(i, i)
    if c == '.' or c == '!' or c == '?' then
      local j = i + 1
      -- absorb trailing closing quotes/brackets, e.g.  ."  .)  .')
      while j <= n and line:sub(j, j):match("[\"'%)%]]") do
        j = j + 1
      end
      -- only a real boundary if followed by whitespace or EOL, e.g. NOT
      -- "e.g." or "3.14" or "example.com", where the next byte is a
      -- regular word character.
      if j > n or line:sub(j, j):match('%s') then
        table.insert(ends, j - 1) -- last byte of the punctuation run
        i = j
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end

  -- Build [start, stop] pairs. A sentence starts right after the
  -- previous end (skipping whitespace), or at the first non-whitespace
  -- byte of the line. It stops at the next terminal-punctuation end, or
  -- at end-of-line if there is none.
  local ranges = {}
  local start = skip_leading_marker_or_space(line, n)
  for _, e in ipairs(ends) do
    if e >= start then
      table.insert(ranges, { start, e })
      -- advance start past this end, skipping whitespace, ready for
      -- the next sentence
      local s = e + 1
      while s <= n and line:sub(s, s):match('%s') do
        s = s + 1
      end
      start = s
    end
  end
  -- trailing chunk with no terminal punctuation (e.g. "If we instead do")
  if start <= n then
    table.insert(ranges, { start, n })
  end

  return ranges
end

-- Trim a [start, stop] byte range to exclude surrounding whitespace,
-- used for the "inner" (is) variant.
local function trim_range(line, start, stop)
  while start <= stop and line:sub(start, start):match('%s') do
    start = start + 1
  end
  while stop >= start and line:sub(stop, stop):match('%s') do
    stop = stop - 1
  end
  return start, stop
end

-- ai_type: 'i' (inner) or 'a' (around)
-- id: the key this was registered under (here, always 's')
-- opts: mini.ai call opts; opts.search_method / cursor position matter
function M.sentence(ai_type, id, opts)
  local line_num = vim.fn.line('.')
  local line = vim.fn.getline(line_num)
  if line:match('^%s*$') then
    return nil
  end

  local cursor_col = vim.fn.col('.')
  local ranges = find_sentence_ranges(line)
  if #ranges == 0 then
    return nil
  end

  -- Pick the range containing the cursor; if the cursor sits in
  -- inter-sentence whitespace, fall back to the next range forward
  -- (mirrors native Vim's "jump forward to next sentence" fallback).
  local chosen
  for idx, r in ipairs(ranges) do
    local s, e = r[1], r[2]
    if cursor_col >= s and cursor_col <= e then
      chosen = idx
      break
    elseif cursor_col < s then
      chosen = idx
      break
    end
  end
  chosen = chosen or #ranges

  local s, e = ranges[chosen][1], ranges[chosen][2]

  if ai_type == 'i' then
    s, e = trim_range(line, s, e)
    if s > e then
      return nil
    end
    return {
      from = { line = line_num, col = s },
      to = { line = line_num, col = e },
    }
  else
    -- 'around': extend to include trailing whitespace up to the next
    -- sentence's start, capped at end of line (never crosses newline).
    if s > e then
      return nil
    end
    local trail_end = e
    local next_range = ranges[chosen + 1]
    local cap = next_range and (next_range[1] - 1) or #line
    local j = e + 1
    while j <= cap and line:sub(j, j):match('%s') do
      j = j + 1
    end
    trail_end = j - 1
    if trail_end < e then
      trail_end = e
    end
    return {
      from = { line = line_num, col = s },
      to = { line = line_num, col = trail_end },
    }
  end
end

return M
