---@diagnostic disable: undefined-global
--- nvim_hs.actions.window
--- Window marks (slots 1-9), similar to Age of Empires unit groups.
---
--- Hotkeys (bound by setup_hotkeys):
---   Cmd + Option + 1..9  → mark focused window into that slot
---   Cmd + 1..9          → focus the window in that slot
---
--- Actions:
---   window.mark        { slot = N }
---   window.focus_slot  { slot = N }
---   window.list_marks
---   window.clear_slot  { slot = N }

local registry = require("nvim_hs.registry")

local M = {}

-- slot (1-9) → { win = hs.window, id = number }
local marks = {}

local function is_valid(entry)
  if not entry or not entry.win then
    return false
  end
  local ok, id = pcall(function()
    return entry.win:id()
  end)
  return ok and id ~= nil and id == entry.id
end

local function get_slot(payload)
  local slot = payload and payload.slot
  if type(slot) ~= "number" or slot < 1 or slot > 9 or slot ~= math.floor(slot) then
    error("slot must be an integer from 1 to 9")
  end
  return slot
end

local function window_info(win)
  if not win then
    return nil
  end
  local ok, id = pcall(function()
    return win:id()
  end)
  if not ok or id == nil then
    return nil
  end
  local app = win:application()
  return {
    id = id,
    title = win:title() or "",
    app = app and app:name() or "",
    bundle = app and app:bundleID() or "",
  }
end

--- Mark the currently focused window into the given slot.
--- Shows a short alert on success.
--- @param payload table  { slot = 1..9 }
--- @return table
function M.mark(payload)
  local slot = get_slot(payload)
  local win = hs.window.focusedWindow()
  local info = window_info(win)
  if not info then
    error("No focused window to mark")
  end

  marks[slot] = { win = win, id = info.id }

  hs.alert.show(string.format("Marked → slot %d\n%s", slot, info.title), 1.2)

  return {
    slot = slot,
    window = info,
  }
end

--- Focus the window stored in the given slot.
--- Shows an alert only when the slot is empty.
--- Success is silent (per design).
--- @param payload table  { slot = 1..9 }
--- @return table
function M.focus_slot(payload)
  local slot = get_slot(payload)
  local entry = marks[slot]

  if not is_valid(entry) then
    marks[slot] = nil
    hs.alert.show(string.format("Slot %d is empty", slot), 1.0)
    error("Slot " .. slot .. " is empty")
  end

  entry.win:focus()

  return {
    slot = slot,
    window = window_info(entry.win),
  }
end

--- Return a list of currently occupied slots (dead windows are cleaned).
--- @param _payload table
--- @return table[]
function M.list_marks(_payload)
  local result = {}
  for slot = 1, 9 do
    local entry = marks[slot]
    if is_valid(entry) then
      table.insert(result, {
        slot = slot,
        window = window_info(entry.win),
      })
    else
      marks[slot] = nil
    end
  end
  return result
end

--- Clear a specific slot.
--- @param payload table  { slot = 1..9 }
--- @return table
function M.clear_slot(payload)
  local slot = get_slot(payload)
  marks[slot] = nil
  return { slot = slot, cleared = true }
end

--- Register all window actions into the registry.
function M.register()
  registry.register("window.mark", M.mark)
  registry.register("window.focus_slot", M.focus_slot)
  registry.register("window.list_marks", M.list_marks)
  registry.register("window.clear_slot", M.clear_slot)
end

--- Bind global hotkeys for mark / focus.
--- Call once after the framework is loaded.
function M.setup_hotkeys()
  for i = 1, 9 do
    local slot = i

    -- Mark: Cmd + Option + number
    hs.hotkey.bind({ "cmd", "option" }, tostring(slot), function()
      local ok, err = pcall(M.mark, { slot = slot })
      if not ok then
        -- strip the "filename:line: " prefix that Lua adds
        local msg = tostring(err):gsub("^.-:%d+:%s*", "")
        hs.alert.show(msg, 1.0)
      end
    end)

    -- Focus: Cmd + number
    hs.hotkey.bind({ "cmd" }, tostring(slot), function()
      local ok, err = pcall(M.focus_slot, { slot = slot })
      if not ok then
        local msg = tostring(err):gsub("^.-:%d+:%s*", "")
        -- focus_slot already shows "Slot N is empty"; only show other errors
        if not msg:match("empty") then
          hs.alert.show(msg, 1.0)
        end
      end
    end)
  end
end

-- Proactively clear a slot when its window is destroyed.
local wf = hs.window.filter.new(nil)
wf:subscribe(hs.window.filter.windowDestroyed, function(destroyed)
  local destroyed_id = destroyed:id()
  if not destroyed_id then
    return
  end
  for slot, entry in pairs(marks) do
    if entry and entry.id == destroyed_id then
      marks[slot] = nil
    end
  end
end)

return M
