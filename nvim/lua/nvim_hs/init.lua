--- nvim_hs
--- Public Neovim API for the Hammerspoon command framework.
---
--- Usage:
---   local hs = require("nvim_hs")
---   local resp = hs.run("system.ping")
---   -- resp = { ok = true, data = "pong" }  or  { ok = false, error = { code, message } }

local protocol = require("nvim_hs.protocol")
local transport = require("nvim_hs.transport")

local M = {}

--- Run a named action on the Hammerspoon side.
--- @param action string  e.g. "system.ping"
--- @param payload table|nil  optional payload table
--- @return table  structured response
function M.run(action, payload)
  if type(action) ~= "string" or action == "" then
    return protocol.err("INVALID_ARGUMENT", "action must be a non-empty string")
  end
  if payload ~= nil and type(payload) ~= "table" then
    return protocol.err("INVALID_ARGUMENT", "payload must be a table or nil")
  end

  local b64, enc_err = protocol.encode_request(action, payload)
  if not b64 then
    return protocol.err("ENCODE_ERROR", enc_err or "Failed to encode request")
  end

  local stdout, transport_err = transport.execute(b64)
  if not stdout then
    return transport_err -- already a protocol error table
  end

  local resp, dec_err = protocol.decode_response(stdout)
  if not resp then
    return protocol.err("DECODE_ERROR", dec_err or "Failed to decode response from hs")
  end

  -- Basic shape validation
  if type(resp.ok) ~= "boolean" then
    return protocol.err("INVALID_RESPONSE", "Response missing boolean 'ok' field")
  end
  if resp.ok == false and (type(resp.error) ~= "table" or type(resp.error.message) ~= "string") then
    return protocol.err("INVALID_RESPONSE", "Error response has invalid 'error' shape")
  end

  return resp
end

-- Expose sub-modules for advanced use / testing
M.protocol = protocol
M.transport = transport


return M
