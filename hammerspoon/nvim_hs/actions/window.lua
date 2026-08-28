---@diagnostic disable: undefined-global
--- nvim_hs.actions.window
--- Window marks (slots 1-9), similar to Age of Empires unit groups.
---
--- Hotkeys use a modal so Cmd+1..9 are not globally captured:
---   Cmd + F2                 → enter Window Marks mode
---   then Cmd + Option + 1..9 → mark focused window into that slot
---   then Cmd + 1..9          → focus the window in that slot
---   Escape / Cmd+F2 / idle   → exit mode
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

-- Modal is only armed after Cmd+F2.  Inner chords therefore cannot collide
-- with other global Cmd+digit bindings while the mode is inactive.
local marks_modal = nil
local marks_timeout = nil
local MARKS_TIMEOUT_SEC = 5

local function strip_lua_error(err)
  return tostring(err):gsub("^.-:%d+:%s*", "")
end

local function cancel_marks_timeout()
  if marks_timeout then
    marks_timeout:stop()
    marks_timeout = nil
  end
end

local function run_and_exit(fn, payload, on_err)
  local ok, err = pcall(fn, payload)
  if not ok then
    on_err(strip_lua_error(err))
  end
  if marks_modal then
    marks_modal:exit()
  end
end

--- Bind modal hotkeys for mark / focus.
--- Call once after the framework is loaded.  Safe to call again (replaces the previous modal).
--- No-op when `hs` is unavailable (e.g. Neovim-side unit tests).
function M.setup_hotkeys()
  if not (hs and hs.hotkey and hs.hotkey.modal and hs.timer) then
    return
  end

  if marks_modal then
    cancel_marks_timeout()
    marks_modal:delete()
    marks_modal = nil
  end

  -- Trigger chord is the only globally reserved hotkey.
  marks_modal = hs.hotkey.modal.new({ "cmd" }, "f2")

  function marks_modal:entered()
    hs.alert.show("Window Marks", 0.8)
    cancel_marks_timeout()
    marks_timeout = hs.timer.doAfter(MARKS_TIMEOUT_SEC, function()
      if marks_modal then
        marks_modal:exit()
      end
    end)
  end

  function marks_modal:exited()
    cancel_marks_timeout()
  end

  -- Official enter() disables the trigger chord, so re-bind it inside the modal as toggle-off.
  marks_modal:bind({ "cmd" }, "f2", function()
    marks_modal:exit()
  end)
  marks_modal:bind({}, "escape", function()
    marks_modal:exit()
  end)

  for i = 1, 9 do
    local slot = i

    -- Mark: Cmd + Option + number (only while modal is active)
    marks_modal:bind({ "cmd", "option" }, tostring(slot), function()
      run_and_exit(M.mark, { slot = slot }, function(msg)
        hs.alert.show(msg, 1.0)
      end)
    end)

    -- Focus: Cmd + number (only while modal is active)
    marks_modal:bind({ "cmd" }, tostring(slot), function()
      run_and_exit(M.focus_slot, { slot = slot }, function(msg)
        -- focus_slot already shows "Slot N is empty"; only show other errors
        if not msg:match("empty") then
          hs.alert.show(msg, 1.0)
        end
      end)
    end)
  end
end

-- Proactively clear a slot when its window is destroyed.
if hs and hs.window and hs.window.filter then
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
end

return M
