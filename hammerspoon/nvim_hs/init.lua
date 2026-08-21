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
window.setup_hotkeys() -- Cmd+Option+1-9 mark, Cmd+1-9 focus

local M = {}

--- Handle a Base64-encoded request string coming from `hs -c`.
--- Always returns a JSON string (the response) so that the CLI stdout is clean.
--- @param b64 string  Base64(JSON(request))
--- @return string  JSON(response)
function M.handle(b64)
  local req, err = protocol.decode(b64)
  if not req then
    local resp = protocol.err("DECODE_ERROR", err or "Failed to decode request")
    return require("nvim_hs.encoding.json").encode(resp)
  end

  -- decode => 從registry依decode的action找到所要執行的handler 代入payload後來執行
  local resp = dispatcher.dispatch(req)
  local ok, json = pcall(require("nvim_hs.encoding.json").encode, resp)
  if not ok then
    local fallback = protocol.err("ENCODE_ERROR", "Failed to encode response: " .. tostring(json))
    return require("nvim_hs.encoding.json").encode(fallback)
  end
  return json
end

-- Also expose for convenience / debugging.
M.protocol = protocol
M.registry = require("nvim_hs.registry")
M.dispatcher = dispatcher

return M
