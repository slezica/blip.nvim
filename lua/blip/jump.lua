local input = require('blip.input').input
local scan = require('blip.scan').scan

local Jump, Target, PreJumpState, Strategy


--- Start an interactive jump in the current window.
---
--- Opens the input UI and begins highlighting and assigning labels as the user types. When the
--- end of the entered text matches a valid label (see `Strategy`), the input auto-closes and the 
--- jump is executed.
---
--- Pressing <Enter> will jump to the first match, regardless of the label, while pressing <Esc> 
--- will cancel the jump without moving the cursor.
--- 
--- @param opts JumpOpts -- Options for this jump.
--- 
local function jump(opts)
  local j = Jump:new(opts or {})

  local on_input_change = function(text)
    Strategy.UpperCaseLabel(j, text)

    vim.cmd('')
    vim.fn.setreg('/', j.pattern)

    if j.complete then
      vim.fn.feedkeys(vim.api.nvim_replace_termcodes('<Enter>', true, false, true))
    else
      j:update(j.pattern:len() > 1 and scan(j.pattern, j.direction) or {})
    end

    vim.cmd('redraw')
  end

  j:setup()

  local ok, _ = input({ prompt = ">> ", on_change = on_input_change })

  if ok and not j.complete then
    j:execute(j.targets[1].label) -- jump to the first label
  end

  j:teardown()

  return j
end


Strategy = {
  SpaceThenLabel = function(j, text)
    if text:find('%s%S$') then -- TODO collapse double spaces
      j:execute(text:sub(-1, -1)) -- character after space, try to jump

    elseif text:find('%s%s$') then
      j.pattern = text:gsub('%s+$', text) -- multiple spaces, only use one TODO not cool

    elseif text:find('%s$') then
      return -- a single space, ignore and wait for the next character

    else
      j.pattern = text -- a non-space character, use it verbatim for the pattern
    end
  end,

  UpperCaseLabel = function(j, text)
    if text:find('%u$') then
      j:execute(text:sub(-1, -1))
    else
      j.pattern = text
    end
  end
}


--- A jump operation. TODO describe
--- @class Jump
---
--- @field labels Label[]
--- @field direction Direction
--- @field targets Target[]
--- @field assignments table<string, Target>
--- @field complete boolean
--- @field pattern string
--- @field namespace number
--- @field pre_state PreJumpState
--- @field private _is_visible boolean
---
Jump = {}
Jump.__index = Jump


--- Options for `Jump:new(opts)`.
--- @class JumpOpts
--- @field labels Label[] -- Assignable labels, in order of priority
--- @field direction Direction -- Jump direction, from cursor

local default_labels = {
  'A', 'S', 'D', 'F',
  'J', 'K', 'L', 'H',
  'W', 'E', 'R',
  'U', 'I', 'O',
  'Q', 'P', 'T', 'Y', 'X',
  'C', 'V', 'B', 'N',
  'G', 'M', 'Z',
}

--- Create a new `Jump`.
---
--- @param opts JumpOpts -- Options for this `Jump` (merged with `JumpOpts.defaults`).
--- @return Jump
---
function Jump:new(opts)
  return setmetatable({
    labels = opts.labels or default_labels,
    direction = opts.direction or 'both',
    targets = {},
    namespace = nil,
    assignments = {},
    complete = false,
    pattern = "",
    _is_visible = false
  }, self)
end

function Jump:setup()
  self.namespace = vim.api.nvim_create_namespace('jump_label_marks') -- actually get-or-create
  self.pre_state = PreJumpState:capture()
  self.complete = false
  self:set_visible(true)
end

function Jump:teardown()
  self.pre_state:restore(self.complete)
  self:set_visible(false)
end

--- Replace the target position list for this `Jump`, assigning labels in order of priority while
--- preserving labels on already existing targets.
---
--- @param positions Target[] -- The new list of `{ line, offset }` positions
--- @return nil
---
function Jump:update(positions)
  -- Use positions to build a `Target` list and a map indexed by positional `.key()`:
  local new_targets = {}
  local new_targets_by_key = {}

  for i, position in ipairs(positions) do
    local target = Target:new(position)

    new_targets[i] = target
    new_targets_by_key[target:key()] = target
  end

  -- Manage labels for targets that had them, and were updated or removed:
  for _, target in ipairs(self.targets) do
    if target.label then
      local replacement = new_targets_by_key[target:key()]

      if replacement then
        -- Preserve the label:
        replacement.label = target.label
        self.assignments[target.label] = replacement
      else
        -- Free the label for reuse:
        self.assignments[target.label] = nil
      end
    end
  end

  self.targets = new_targets

  -- Assign to unlabeled targets, until we run out of labels:
  local li = 0 -- `self.labels` iterator

  for _, target in ipairs(self.targets) do
    if not target.label then
      -- Locate the next unassigned label:
      repeat li = li + 1 until not self.assignments[self.labels[li]]

      -- Did we actually find one?
      if li >= #self.labels then break end

      -- Yes we did!
      target.label = self.labels[li]
      self.assignments[self.labels[li]] = target
    end
  end

  if self._is_visible then
    self:set_visible(true) -- force redraw
  end
end

--- Set the visibility of jump marks for this `Jump`.
---
--- @param is_visible boolean -- True to show marks, false to to hide them
--- @return nil
---
function Jump:set_visible(is_visible)
  self:_del_marks()
  if is_visible then self:_set_marks() end
  self._is_visible = is_visible
end

--- Return whether jump marks are visible for this `Jump`.
--- @return boolean
---
function Jump:is_visible()
  return self._is_visible
end

--- Jump to the target marked by `label` (if any).
---
--- @param label string -- The target label
--- @return boolean ok -- True if the jump was successful, false otherwise
---
function Jump:execute(label)
  if not self.assignments[label] then
    return false
  end

  vim.cmd("normal! m'")
  vim.api.nvim_win_set_cursor(0, self.assignments[label].position)
  self.complete = true
  self:set_visible(false)

  return true
end

--- @private
function Jump:_set_marks()
  -- Set marks for currently labeled targets:
  for i, target in pairs(self.targets) do
    if target.label then
      local color = (i == 1) and "MiniSurround" or "WildMenu" 
      local mark = {
        virt_text = { { target.label, color } },
        virt_text_pos = "overlay",
      }

      vim.api.nvim_buf_set_extmark(0, self.namespace, target.position[1] - 1, target.position[2], mark)
    end
  end
end

--- @private
function Jump:_del_marks()
  -- Destroy the marks (recreate them later, easier, there's just a few of them :D):
  vim.api.nvim_buf_clear_namespace(0, self.namespace, 0, -1)
end


--- The character displayed on a match position.
--- @alias Label string


--- The direction of a jump, relative to the cursor
--- @alias Direction 'forward' | 'backward' | 'both'


--- Editor state saved before starting a jump, available to be restored after the jump is done.
--- @class PreJumpState
---
--- @field cursor number[] -- The `{line, offset}` cursor position
--- @field reg_slash string -- The value of the `/` register
--- @field v_hlsearch boolean -- The value of `vim.v.hlsearch`
---
PreJumpState = {}
PreJumpState.__index = PreJumpState

--- Fill a `PreJumpState` for the current window.
--- @return PreJumpState
---
function PreJumpState:capture()
  local values = {
    cursor = vim.api.nvim_win_get_cursor(0),
    reg_slash = vim.fn.getreg('/'),
    v_hlsearch = vim.v.hlsearch,
  }

  return setmetatable(values, PreJumpState)
end

--- Restore the state from `capture()` on the current window.
---
function PreJumpState:restore(ok)
  vim.fn.setreg('/', self.reg_slash)
  vim.cmd(self.v_hlsearch == 1 and '/' or 'noh')

  if not ok then
    vim.api.nvim_win_set_cursor(0, self.cursor)
  end
end


--- An on-screen position to jump to.
--- @class Target
---
--- @field label? string -- The key to enter in order to jump.
--- @field position number[] -- The line number to jump to.
---
Target = {}
Target.__index = Target


--- Create a `Target` for a position.
---
--- @param position number[] -- A `{line, offset}` position pair
--- @return Target
---
function Target:new(position)
  return setmetatable({
    position = position,
    label = nil,
  }, self)
end

--- Get a suitable index key for this target, based on its position.
--- @return string
---
function Target:key()
  return self.position[1] .. ':' .. self.position[2]
end


return {
  jump = jump,
  Jump = Jump,
  Strategy = Strategy,
  Target = Target,
}
