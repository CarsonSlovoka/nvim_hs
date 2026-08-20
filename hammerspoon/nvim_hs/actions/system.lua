--- nvim_hs.actions.system
--- Built-in system actions: system.ping, system.list

local registry = require("nvim_hs.registry")

local M = {}

--- system.ping
--- Returns the string "pong". No payload used.
--- @param _payload table
--- @return string
function M.ping(_payload)
  return "pong"
end

--- system.list
--- Returns the list of currently registered action names.
--- Source of truth is the registry.
--- @param _payload table
--- @return string[]
function M.list(_payload)
  return registry.list()
end

--- Register all system actions into the registry.
function M.register()
  registry.register("system.ping", M.ping)
  registry.register("system.list", M.list)
end

return M
