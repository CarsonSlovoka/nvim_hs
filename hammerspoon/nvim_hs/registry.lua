--- nvim_hs.registry
--- Central registry of action name → handler function.
--- Source of truth for system.list.

local M = {}

--- @type table<string, function>
local actions = {}

--- Register an action handler.
--- @param name string  e.g. "system.ping"
--- @param handler function  function(payload) -> data  (or raises error)
function M.register(name, handler)
  if type(name) ~= "string" or name == "" then
    error("action name must be a non-empty string")
  end
  if type(handler) ~= "function" then
    error("handler must be a function")
  end
  actions[name] = handler
end

--- Look up a handler by name.
--- @param name string
--- @return function|nil
function M.get(name)
  return actions[name]
end

--- Return a sorted list of all registered action names.
--- @return string[]
function M.list()
  local names = {}
  for name, _ in pairs(actions) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

--- Check whether an action exists.
--- @param name string
--- @return boolean
function M.has(name)
  return actions[name] ~= nil
end

return M
