--- nvim_hs.protocol
--- Shared request / response protocol helpers for the Neovim ↔ Hammerspoon framework.
--- Uses hs.json and hs.base64.

---@diagnostic disable: undefined-global

local M = {}

M.VERSION = 1


--- Encode a Lua table to a Base64 string of its JSON representation.
--- @param tbl table
--- @return string|nil b64
--- @return string|nil err
function M.encode(tbl)
  local ok, json = pcall(require("nvim_hs.encoding.json").encode, tbl)
  if not ok then
    return nil, "JSON encode failed: " .. tostring(json)
  end
  local b64 = require("nvim_hs.encoding.base64").encode(json)
  if not b64 then
    return nil, "Base64 encode failed"
  end
  return b64, nil
end

--- Decode a Base64 string into a Lua table (JSON).
--- @param b64 string
--- @return table|nil tbl
--- @return string|nil err
function M.decode(b64)
  if type(b64) ~= "string" or b64 == "" then
    return nil, "Empty or non-string Base64 input"
  end
  local json = require("nvim_hs.encoding.base64").decode(b64)
  if not json then
    return nil, "Base64 decode failed"
  end
  local ok, tbl = pcall(require("nvim_hs.encoding.json").decode, json)
  if not ok then
    return nil, "JSON decode failed: " .. tostring(tbl)
  end
  if type(tbl) ~= "table" then
    return nil, "Decoded value is not a table"
  end
  return tbl, nil
end

--- Build a successful response table.
--- @param data any
--- @return table
function M.ok(data)
  return {
    ok = true,
    data = data,
  }
end

--- Build an error response table.
--- @param code string
--- @param message string
--- @return table
function M.err(code, message)
  return {
    ok = false,
    error = {
      code = code or "UNKNOWN",
      message = message or "Unknown error",
    },
  }
end

--- Validate a request table.
--- @param req table
--- @return boolean ok
--- @return string|nil err_msg
function M.validate_request(req)
  if type(req) ~= "table" then
    return false, "Request is not a table"
  end
  if req.version ~= M.VERSION then
    return false, "Unsupported protocol version: " .. tostring(req.version)
  end
  if type(req.action) ~= "string" or req.action == "" then
    return false, "Missing or invalid action"
  end
  if req.payload ~= nil and type(req.payload) ~= "table" then
    return false, "payload must be a table when present"
  end
  return true, nil
end

return M
