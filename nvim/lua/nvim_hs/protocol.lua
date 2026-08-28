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
  -- Trim BOM / surrounding whitespace from CLI output
  json_str = json_str:gsub("^\239\187\191", ""):gsub("^%s+", ""):gsub("%s+$", "")

  -- hs.json.encode can return nil; CLI then prints the literal "nil".
  if json_str == "nil" then
    return nil, "JSON decode failed: hs returned nil (response encode failed)"
  end

  -- If print() leaked onto stdout, keep the first JSON object/array.
  local start_at = json_str:find("[{[]", 1)
  if start_at and start_at > 1 then
    json_str = json_str:sub(start_at)
  end

  local ok, tbl = pcall(vim.json.decode, json_str)
  if not ok then
    local preview = json_str:sub(1, 80):gsub("%s+", " ")
    return nil, "JSON decode failed: " .. tostring(tbl) .. " | preview: " .. preview
  end
  if type(tbl) == "string" then
    -- hs -c sometimes wraps the JSON string as a JSON string.
    ok, tbl = pcall(vim.json.decode, tbl)
    if not ok or type(tbl) ~= "table" then
      return nil, "Decoded response is not a table"
    end
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
