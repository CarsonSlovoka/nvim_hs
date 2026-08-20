--- nvim_hs.transport
--- Sole module that knows about the `hs` CLI.
--- Invokes `hs -c` with a Lua expression that calls the framework handler.

local protocol = require("nvim_hs.protocol")

local M = {}

--- Default timeout for the hs process (milliseconds).
M.timeout_ms = 5000

--- Build the Lua expression that will be passed to `hs -c`.
--- The expression must evaluate to the JSON response string.
--- @param b64 string  Base64-encoded request
--- @return string
local function build_expression(b64)
  -- We deliberately keep the expression simple and quote-safe.
  -- The Base64 alphabet does not contain single quotes, so embedding is safe.
  return string.format(
    [[return require("nvim_hs").handle(%q)]],
    b64
  )
end

--- Execute a Base64 request via `hs -c` and return the raw stdout.
--- @param b64 string
--- @return string|nil stdout
--- @return table|nil err_resp  protocol error table if transport failed
function M.execute(b64)
  local expr = build_expression(b64)

  local ok, result = pcall(function()
    return vim.system(
      { "hs", "-c", expr },
      {
        text = true,
        timeout = M.timeout_ms,
      }
    ):wait()
  end)

  if not ok then
    -- vim.system itself threw (e.g. executable not found)
    local msg = tostring(result)
    if msg:find("ENOENT") or msg:find("No such file") or msg:find("not found") then
      return nil, protocol.err("HS_NOT_FOUND", "hs executable not found in PATH. Is Hammerspoon CLI installed?")
    end
    return nil, protocol.err("TRANSPORT_ERROR", "Failed to spawn hs: " .. msg)
  end

  local completed = result  -- vim.SystemCompleted

  if completed.code ~= 0 then
    local stderr = (completed.stderr or ""):gsub("%s+$", "")
    local stdout = (completed.stdout or ""):gsub("%s+$", "")

    -- Common cases
    if stderr:find("Unable to connect") or stderr:find("not running") or completed.code == 69 then
      return nil, protocol.err("HS_NOT_RUNNING", "Hammerspoon is not running or IPC is unavailable. Start Hammerspoon and ensure require('hs.ipc') is loaded.")
    end

    local detail = stderr ~= "" and stderr or stdout
    if detail == "" then
      detail = "exit code " .. tostring(completed.code)
    end
    return nil, protocol.err("IPC_ERROR", "hs CLI failed: " .. detail)
  end

  local stdout = completed.stdout or ""
  stdout = stdout:gsub("%s+$", "")  -- strip trailing whitespace/newline

  if stdout == "" then
    return nil, protocol.err("EMPTY_RESPONSE", "hs returned empty stdout")
  end

  return stdout, nil
end

return M
