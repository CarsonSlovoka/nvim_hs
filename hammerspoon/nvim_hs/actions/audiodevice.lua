---@diagnostic disable: undefined-global

local registry = require("nvim_hs.registry")

local M = {}

--- @param payload table
--- @return table
function M.set_volume(payload)
  local old_val = hs.audiodevice.defaultOutputDevice():volume()
  local new_val = payload.value
  if new_val then
    hs.audiodevice.defaultOutputDevice():setVolume(new_val)
  end
  return {
    cur = new_val,
    old_val = old_val,
  }
end

function M.register()
  registry.register("audiodevice.set_volume", M.set_volume)
end

return M
