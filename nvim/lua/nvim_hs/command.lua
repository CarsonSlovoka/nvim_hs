--- nvim_hs.command
--- Defines the :Hs user command.  It is only a frontend to nvim_hs.run().

local nvim_hs = require("nvim_hs")

local M = {}

--- Parse the argument string of :Hs into action + optional JSON payload.
--- First token is the action name; the rest (if any) is treated as JSON payload.
--- @param args string
--- @return string|nil action
--- @return table|nil payload
--- @return string|nil err
local function parse_args(args)
  args = vim.trim(args or "")
  if args == "" then
    return nil, nil, "Usage: :Hs <action> [json-payload]"
  end

  -- Split on first whitespace
  local action, rest = args:match("^(%S+)%s*(.*)$")
  if not action then
    return nil, nil, "Invalid arguments"
  end

  local payload = nil
  if rest and rest ~= "" then
    local ok, decoded = pcall(vim.json.decode, rest)
    if not ok then
      return nil, nil, "Invalid JSON payload: " .. tostring(decoded)
    end
    if type(decoded) ~= "table" then
      return nil, nil, "Payload must be a JSON object"
    end
    payload = decoded
  end

  return action, payload, nil
end

--- Pretty-print a response to the user.
--- @param resp table
local function print_response(resp)
  if resp.ok then
    local data = resp.data
    if type(data) == "table" then
      -- Prefer inspect if available
      local ok, inspected = pcall(vim.inspect, data)
      if ok then
        print(inspected)
      else
        print(vim.json.encode(data))
      end
    else
      print(tostring(data))
    end
  else
    local err = resp.error or {}
    vim.notify(
      string.format("[nvim_hs] %s: %s", err.code or "ERROR", err.message or "unknown"),
      vim.log.levels.ERROR
    )
  end
end

--- Create the :Hs command.
function M.setup()
  vim.api.nvim_create_user_command("Hs", function(opts)
    local action, payload, err = parse_args(opts.args)
    if err then
      vim.notify("[nvim_hs] " .. err, vim.log.levels.ERROR)
      return
    end

    local resp = nvim_hs.run(action, payload)
    print_response(resp)
  end, {
    nargs = "+",
    desc = "Run a Hammerspoon action via nvim_hs (e.g. :Hs system.ping)",
    complete = function()
      -- Future: could call system.list for completion, but keep minimal for v1
      return { "system.ping", "system.list" }
    end,
  })
end

return M
