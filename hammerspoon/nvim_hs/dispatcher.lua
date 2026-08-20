--- nvim_hs.dispatcher
--- Receives a decoded request table, looks up the action in the registry,
--- calls the handler, and returns a structured response table.
--- Never raises; always returns a protocol response table.

local protocol = require("nvim_hs.protocol")
local registry = require("nvim_hs.registry")

local M = {}

--- Dispatch a request table.
--- @param req table  { version, action, payload }
--- @return table  response  { ok = true, data = ... } | { ok = false, error = { code, message } }
function M.dispatch(req)
  local valid, err_msg = protocol.validate_request(req)
  if not valid then
    return protocol.err("INVALID_REQUEST", err_msg)
  end

  local action = req.action
  local payload = req.payload or {}

  local handler = registry.get(action)
  if not handler then
    return protocol.err("ACTION_NOT_FOUND", "Unknown action: " .. action)
  end

  local ok, result = pcall(handler, payload)
  if not ok then
    return protocol.err("HANDLER_ERROR", "Action handler error: " .. tostring(result))
  end

  return protocol.ok(result)
end

return M
