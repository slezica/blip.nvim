local M = {}
local scan_bidirectional, scan_unidirectional

--- Search visible lines in the current window for a `pattern`, matching between the cursor position
--- and the beginning/end of the window (depending on the `forward` argument).
---
--- Returns an array of `{line, offset}` pairs, indicating the beginning of each `pattern` match.
---
--- @param pattern string -- The search pattern
--- @param direction 'forward' | 'backward' | 'both'
---
--- @return number[][] positions -- An array of `{line, offset}` pairs
---
function M.scan(pattern, direction)
  local origin = vim.api.nvim_win_get_cursor(0)
  local results = {}

  if direction == 'forward' then
    scan_unidirectional(origin, pattern, true, results)

  elseif direction == 'backward' then
    scan_unidirectional(origin, pattern, false, results)

  elseif direction == 'both' then
    scan_bidirectional(origin, pattern, results)
  end

  return results
 end


scan_unidirectional = function(origin, pattern, forward, results)
  local flags, stopline

  if forward then
    flags = 'Wz' -- no wrap, start at cursor col
    stopline = vim.fn.line('w$')
  else
    flags = 'Wb' -- no wrap, start at cursor col, backwards
    stopline = vim.fn.line('w0')
  end

  while true do
    local result = vim.fn.searchpos(pattern, flags, stopline)
    if result[1] == 0 then break end -- signals no matches

    table.insert(results, { result[1], result[2] - 1 }) -- oh my
  end

  vim.api.nvim_win_set_cursor(0, origin)
end


scan_bidirectional = function(origin, pattern, results)
  scan_unidirectional(origin, pattern, true, results)
  scan_unidirectional(origin, pattern, false, results)

  table.sort(results, function(a, b)
    local da = { math.abs(a[1] - origin[1]), math.abs(a[2] - origin[2]) }
    local db = { math.abs(b[1] - origin[1]), math.abs(b[2] - origin[2]) }
    print(vim.inspect(da), vim.inspect(db))
    if da[1] ~= db[1] then
      return da[1] < db[1]
    else
      return da[2] < db[2]
    end
  end)
end



return M
