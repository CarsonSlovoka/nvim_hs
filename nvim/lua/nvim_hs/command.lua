--- nvim_hs.command
--- Defines the :Hs user command.  It is only a frontend to nvim_hs.run().
---
--- Completion is dynamic: it calls system.list from Hammerspoon (the single
--- source of truth) and caches the result according to config.

local nvim_hs = require("nvim_hs") -- ../nvim_hs.lua

local M = {}

--- @class nvim_hs.command.Config
--- @field completion_cache_ttl integer|nil cache time to live
---   nil  → fetch once, then cache forever (until Neovim restart or refresh)
---   N    → re-fetch after N seconds (no upper limit)

--- Default config
local default_config = {
  completion_cache_ttl = nil, -- forever after first fetch
}

--- Current config (set by setup)
M.config = vim.deepcopy(default_config)

-- Cache for action list
local cache = {
  list = nil, ---@type string[]|nil
  fetched_at = 0, ---@type integer  os.time()
}

--- Force the next completion to re-fetch from Hammerspoon.
function M.refresh_completions()
  cache.list = nil
  cache.fetched_at = 0
end

--- Get the list of actions, using cache according to config.
--- 動態呼叫registry.list()取得所有可用的action: `git show -p d632304b:hammerspoon/nvim_hs/actions/system.lua | bat -l lua -P -r 16:23`
---
--- @return string[]
local function get_action_list()
  local ttl = M.config.completion_cache_ttl
  local now = os.time()

  if cache.list then
    if ttl == nil then
      -- forever
      return cache.list
    end
    if (now - cache.fetched_at) < ttl then
      return cache.list
    end
  end

  -- Fetch from Hammerspoon (source of truth)
  local resp = nvim_hs.run("system.list")
  if resp.ok and type(resp.data) == "table" then
    cache.list = resp.data
    cache.fetched_at = now
    return cache.list
  end

  -- Fetch failed: keep old cache if present, otherwise empty
  return cache.list or {}
end

--- Parse the argument string of :Hs into action + optional JSON payload.
--- First token is the action name; the rest (if any) is treated as JSON payload.
--- @param args string
--- @return string|nil action
--- @return table|nil payload
--- @return string|nil err
local function parse_args(args)
  args = vim.trim(args or "")
  if args == "" then
    return nil, nil, "Usage: :Hs <action> [json-payload]"
  end

  -- Split on first whitespace
  local action, rest = args:match("^(%S+)%s*(.*)$")
  if not action then
    return nil, nil, "Invalid arguments"
  end

  local payload = nil
  if rest and rest ~= "" then
    local ok, decoded = pcall(vim.json.decode, rest)
    if not ok then
      return nil, nil, "Invalid JSON payload: " .. tostring(decoded)
    end
    if type(decoded) ~= "table" then
      return nil, nil, "Payload must be a JSON object"
    end
    payload = decoded
  end

  return action, payload, nil
end

--- Pretty-print a response to the user.
--- @param resp table
local function print_response(resp)
  if resp.ok then
    local data = resp.data
    if type(data) == "table" then
      -- Prefer inspect if available
      local ok, inspected = pcall(vim.inspect, data)
      if ok then
        print(inspected)
      else
        print(vim.json.encode(data))
      end
    else
      print(tostring(data))
    end
  else
    local err = resp.error or {}
    vim.notify(
      string.format("[nvim_hs] %s: %s", err.code or "ERROR", err.message or "unknown"),
      vim.log.levels.ERROR
    )
  end
end

--- Create the :Hs command.
--- @param opts nvim_hs.command.Config|nil
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", default_config, opts)

  require("nvim_hs.marks_buffer").setup()

  vim.api.nvim_create_user_command("Hs", function(cmd_opts)
    local action, payload, err = parse_args(cmd_opts.args)
    if err then
      vim.notify("[nvim_hs] " .. err, vim.log.levels.ERROR)
      return
    end

    local resp = nvim_hs.run(action, payload)
    print_response(resp)
  end, {
    nargs = "+",
    desc = "Run a Hammerspoon action via nvim_hs (e.g. :Hs system.ping)",
    complete = function(arg_lead, cmd_line, _)
      -- Only complete the action name (first token).
      -- If the user has already typed a space after the action, do not offer
      -- action names again (they are typing the JSON payload).
      local after = cmd_line:match("^%s*Hs%s+(.*)$") or ""
      if after:find("%s") then
        return {}
      end

      local list = get_action_list()
      if #arg_lead == 0 then
        return list
      end
      return vim.fn.matchfuzzy(list, arg_lead)
    end,
  })
end

return M
