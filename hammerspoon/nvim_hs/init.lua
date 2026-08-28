--- nvim_hs
--- Hammerspoon-side framework entry point.
--- Loads protocol, registry, dispatcher and built-in system actions.
--- Exposes a single public function that the CLI calls with a Base64 request.

-- hs.alert.show("init Hammerspoon nvim_hs", 3)

local protocol = require("nvim_hs.protocol")
local dispatcher = require("nvim_hs.dispatcher")
local system = require("nvim_hs.actions.system") -- 這邊註冊了自定義的事件

-- Register built-in actions once at load time.
system.register()
require("nvim_hs.actions.audiodevice").register()

local window = require("nvim_hs.actions.window")
window.register()
window.setup_hotkeys() -- Cmd+F2 modal: then Cmd+1-9|a-z mark, 1-9|a-z focus

local M = {}

local json_mod = require("nvim_hs.encoding.json")

--- Always return a JSON string.  hs.json.encode can return nil without throwing
--- when a value is not NSJSONSerialization-safe (bad UTF-8 in a window title).
--- If that nil reaches `hs -c`, stdout becomes "nil" and Neovim reports
--- "invalid number at character 1" (it tries to parse `nil` as `nan`).
local function encode_response(resp)
  local ok, json = pcall(json_mod.encode, resp)
  if ok and type(json) == "string" and json ~= "" then
    return json
  end
  local fallback = protocol.err("ENCODE_ERROR", "Failed to encode response: " .. tostring(json))
  local ok2, encoded = pcall(json_mod.encode, fallback)
  if ok2 and type(encoded) == "string" and encoded ~= "" then
    return encoded
  end
  return '{"ok":false,"error":{"code":"ENCODE_ERROR","message":"Failed to encode response"}}'
end

--- Handle a Base64-encoded request string coming from `hs -c`.
--- Always returns a JSON string (the response) so that the CLI stdout is clean.
--- @param b64 string  Base64(JSON(request))
--- @return string  JSON(response)
function M.handle(b64)
  local req, err = protocol.decode(b64)
  if not req then
    return encode_response(protocol.err("DECODE_ERROR", err or "Failed to decode request"))
  end

  -- decode => 從registry依decode的action找到所要執行的handler 代入payload後來執行
  return encode_response(dispatcher.dispatch(req))
end

-- Also expose for convenience / debugging.
M.protocol = protocol
M.registry = require("nvim_hs.registry")
M.dispatcher = dispatcher

return M
