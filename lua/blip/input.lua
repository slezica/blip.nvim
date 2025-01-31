local M = {}

--- Opts parameter for `.input(opts)`
--- @class InputOpts
---
--- @field prompt? string Title to display next to the input.
--- @field text? string Initial (editable) content of the input.
--- @field on_change? fun(text: string) Called when the input contents are modified.
---
local InputOpts = {}


--- Show an interactive text input UI.
---
--- Returns `text`, `ok`: the final text content and a boolean indicating whether the input was
--- confirmed (`true`) or cancelled (`false`).
---
--- Callers can optionally set a `prompt`, an initial `text` and an `on_change(text)` listener
--- that will be called after each modification.
---
--- @param opts InputOpts -- Options (see `InputOpts`)
---
--- @return boolean ok -- Whether the input was confirmed (`true`) or cancelled (`false`)
--- @return string text -- The final text content of the input
---
function M.input(opts)
  local text = opts.text or ""
  local ok = false

  local on_cmd_line_changed = function()
    text = vim.fn.getcmdline()
    if opts.on_change then opts.on_change(text) end
  end

  local au = vim.api.nvim_create_autocmd('CmdLineChanged', { callback = on_cmd_line_changed })

  ok, text = pcall(vim.fn.input, {
    prompt = opts.prompt,
    default = text,
    cancelreturn = '\x18' -- the ascii cancel character we all know and use
  })

  ok = ok and text ~= '\x18' -- merge errors (frequently SIGINT) and cancellations

  vim.api.nvim_del_autocmd(au)

  return ok, text
end


return M

