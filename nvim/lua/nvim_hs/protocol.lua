--- nvim_hs.protocol
--- Request / response helpers for the Neovim side.
--- Uses vim.json and vim.base64 (Neovim 0.10+).

local M = {}

M.VERSION = 1

--- Encode a request table to Base64(JSON).
--- @param action string
--- @param payload table|nil
--- @return string|nil b64
--- @return string|nil err
function M.encode_request(action, payload)
  local req = {
    version = M.VERSION,
    action = action,
    payload = payload or {},
  }
  local ok, json = pcall(vim.json.encode, req)
  if not ok then
    return nil, "JSON encode failed: " .. tostring(json)
  end
  local b64 = vim.base64.encode(json)
  if not b64 or b64 == "" then
    return nil, "Base64 encode failed"
  end
  return b64, nil
end

--- Decode a JSON response string into a table.
--- @param json_str string
--- @return table|nil resp
--- @return string|nil err
function M.decode_response(json_str)
  if type(json_str) ~= "string" or json_str == "" then
    return nil, "Empty response"
  end
  -- Trim possible trailing newline from CLI output
  json_str = json_str:gsub("%s+$", "")
  local ok, tbl = pcall(vim.json.decode, json_str)
  if not ok then
    return nil, "JSON decode failed: " .. tostring(tbl)
  end
  if type(tbl) ~= "table" then
    return nil, "Decoded response is not a table"
  end
  return tbl, nil
end

--- Build a local error response (used when transport itself fails).
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

return M
