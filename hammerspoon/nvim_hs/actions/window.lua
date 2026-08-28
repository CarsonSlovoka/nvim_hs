---@diagnostic disable: undefined-global
--- nvim_hs.actions.window
--- Window marks (slots 1-9 and a-z), similar to Age of Empires unit groups.
---
--- Hotkeys use a modal so slot keys are not globally captured:
---   Cmd + F2                 → enter Window Marks mode
---   then Cmd + 1..9|a..z     → mark focused window into that slot
---   then 1..9|a..z           → focus the window in that slot
---   Escape / Cmd+F2 / idle   → exit mode
---
--- Actions:
---   window.mark        { slot = "1".."9"|"a".."z" }  (number 1-9 also accepted)
---   window.focus_slot  { slot = ... }
---   window.list_marks
---   window.clear_slot  { slot = ... }
---   window.snapshot
---   window.apply_marks { items = { { slot = ..., id = ... }, ... } }

local registry = require("nvim_hs.registry")

local M = {}

-- Canonical slot ids, in display order: "1".."9" then "a".."z"
local SLOT_ORDER = {}
local SLOT_SET = {}

for i = 1, 9 do
  local id = tostring(i)
  SLOT_ORDER[#SLOT_ORDER + 1] = id
  SLOT_SET[id] = true
end
for c = string.byte("a"), string.byte("z") do
  local id = string.char(c)
  SLOT_ORDER[#SLOT_ORDER + 1] = id
  SLOT_SET[id] = true
end

-- slot id → { win = hs.window, id = number }
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

--- Normalize payload.slot to a canonical string id.
--- Accepts number 1-9 (backward compatible) or string "1"-"9" / "a"-"z" (case-insensitive).
local function get_slot(payload)
  local slot = payload and payload.slot
  if type(slot) == "number" then
    if slot >= 1 and slot <= 9 and slot == math.floor(slot) then
      return tostring(slot)
    end
  elseif type(slot) == "string" then
    local id = slot:lower()
    if SLOT_SET[id] then
      return id
    end
  end
  error("slot must be 1-9 or a-z")
end

local function json_safe_string(s)
  s = tostring(s or "")
  s = s:gsub("[\0-\8\11\12\14-\31]", " ")
  if hs and hs.utf8 and hs.utf8.fixUTF8 then
    local ok, fixed = pcall(hs.utf8.fixUTF8, s, "?")
    if ok and type(fixed) == "string" then
      s = fixed
    end
  end
  return s
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

  local title = ""
  pcall(function()
    title = win:title() or ""
  end)

  local app_name, bundle = "", ""
  pcall(function()
    local app = win:application()
    if app then
      app_name = app:name() or ""
      bundle = app:bundleID() or ""
    end
  end)

  return {
    id = id,
    title = json_safe_string(title),
    app = json_safe_string(app_name),
    bundle = json_safe_string(bundle),
  }
end

--- Mark the currently focused window into the given slot.
--- Shows a short alert on success.
--- @param payload table  { slot = "1".."9"|"a".."z"|1..9 }
--- @return table
function M.mark(payload)
  local slot = get_slot(payload)
  local win = hs.window.focusedWindow()
  local info = window_info(win)
  if not info then
    error("No focused window to mark")
  end

  marks[slot] = { win = win, id = info.id }

  hs.alert.show(string.format("Marked → slot %s\n%s", slot, info.title), 1.2)

  return {
    slot = slot,
    window = info,
  }
end

--- Restore a minimized / hidden window far enough that :focus() can work.
--- Official docs: hs.window:focus() does not unminimize.
local function reveal_and_focus(win)
  local app = win:application()
  if app then
    local hidden = false
    pcall(function()
      hidden = app:isHidden()
    end)
    if hidden then
      app:unhide()
    end
  end

  local minimized = false
  pcall(function()
    minimized = win:isMinimized()
  end)
  if minimized then
    win:unminimize()
  end

  pcall(function()
    win:becomeMain()
  end)
  pcall(function()
    win:raise()
  end)
  win:focus()
end

--- Re-resolve the stored window.  The userdata can go stale while the
--- window id is still valid (common after hide / minimize / Space change).
local function resolve_window(entry)
  if is_valid(entry) then
    return entry.win
  end
  if not entry or not entry.id or not hs.window or not hs.window.get then
    return nil
  end
  local win = hs.window.get(entry.id)
  if not win then
    return nil
  end
  local ok, id = pcall(function()
    return win:id()
  end)
  if not ok or id ~= entry.id then
    return nil
  end
  entry.win = win
  return win
end

--- Focus the window stored in the given slot.
--- Shows an alert only when the slot is empty.
--- Success is silent (per design).
--- Minimized windows are unminimized; hidden apps (Cmd+H) are unhidden first.
--- @param payload table  { slot = "1".."9"|"a".."z"|1..9 }
--- @return table
function M.focus_slot(payload)
  local slot = get_slot(payload)
  local entry = marks[slot]
  local win = resolve_window(entry)

  if not win then
    marks[slot] = nil
    hs.alert.show(string.format("Slot %s is empty", slot), 1.0)
    error("Slot " .. slot .. " is empty")
  end

  reveal_and_focus(win)

  return {
    slot = slot,
    window = window_info(win),
  }
end

--- Return a list of currently occupied slots (dead windows are cleaned).
--- @param _payload table
--- @return table[]
function M.list_marks(_payload)
  local result = {}
  for _, slot in ipairs(SLOT_ORDER) do
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
--- @param payload table  { slot = "1".."9"|"a".."z"|1..9 }
--- @return table
function M.clear_slot(payload)
  local slot = get_slot(payload)
  marks[slot] = nil
  return { slot = slot, cleared = true }
end

local function slot_for_window_id(win_id)
  for slot, entry in pairs(marks) do
    if entry and entry.id == win_id and is_valid(entry) then
      return slot
    end
  end
  return nil
end

local function each_window_source(add)
  if not (hs and hs.window) then
    return
  end

  local function add_list(ok, result)
    if not ok or result == nil then
      return
    end
    if type(result) ~= "table" then
      add(result)
      return
    end
    for _, win in ipairs(result) do
      add(win)
    end
  end

  add_list(pcall(function()
    return hs.window.focusedWindow()
  end))
  add_list(pcall(function()
    return hs.window.visibleWindows()
  end))
  add_list(pcall(function()
    return hs.window.minimizedWindows()
  end))
  add_list(pcall(function()
    return hs.window.allWindows()
  end))
end

local function collect_windows()
  local seen = {}
  local list = {}

  local function add(win)
    local ok, info = pcall(window_info, win)
    if not ok or not info or seen[info.id] then
      return
    end
    seen[info.id] = true
    -- Always emit `slot` as a string so JSON encode never sees nil values.
    list[#list + 1] = {
      id = info.id,
      slot = slot_for_window_id(info.id) or "",
      app = info.app or "",
      title = info.title or "",
      bundle = info.bundle or "",
    }
  end

  each_window_source(add)

  -- Keep marked windows even if the system enumerators missed them.
  for _, entry in pairs(marks) do
    local win = resolve_window(entry)
    if win then
      add(win)
    end
  end

  table.sort(list, function(a, b)
    local ia = (a.slot ~= "" and SLOT_SET[a.slot]) and a.slot or nil
    local ib = (b.slot ~= "" and SLOT_SET[b.slot]) and b.slot or nil
    if ia and not ib then
      return true
    end
    if ib and not ia then
      return false
    end
    if ia and ib then
      return ia < ib
    end
    local app_a, app_b = tostring(a.app or ""), tostring(b.app or "")
    if app_a ~= app_b then
      return app_a < app_b
    end
    return tostring(a.title or "") < tostring(b.title or "")
  end)

  return list
end

--- Snapshot every known window plus its current mark (if any).
--- Unmarked windows have slot = nil.  Other-Space windows may be missing.
--- @param _payload table
--- @return table
function M.snapshot(_payload)
  return { windows = collect_windows() }
end

local function normalize_window_id(id)
  if type(id) == "number" and id == math.floor(id) and id > 0 then
    return id
  end
  if type(id) == "string" and id:match("^%d+$") then
    return tonumber(id)
  end
  return nil
end

--- Replace the entire marks table with payload.items.
--- Duplicate slot or duplicate window id rejects the whole apply.
--- Missing windows are skipped; the rest are applied.
--- @param payload table  { items = { { slot = "a", id = 123 }, ... } }
--- @return table
function M.apply_marks(payload)
  local items = payload and payload.items
  if type(items) ~= "table" then
    error("items must be a list of { slot, id }")
  end

  local by_slot = {}
  local by_id = {}
  local planned = {}

  for i, item in ipairs(items) do
    if type(item) ~= "table" then
      error("items[" .. i .. "] must be a table")
    end
    local slot = get_slot(item)
    local id = normalize_window_id(item.id)
    if not id then
      error("items[" .. i .. "].id must be a window id")
    end
    if by_slot[slot] then
      error("DUPLICATE_SLOT: slot " .. slot .. " assigned more than once")
    end
    if by_id[id] then
      error("DUPLICATE_ID: window id " .. tostring(id) .. " assigned to more than one slot")
    end
    by_slot[slot] = true
    by_id[id] = true
    planned[#planned + 1] = { slot = slot, id = id }
  end

  local new_marks = {}
  local applied = {}
  local skipped = {}

  for _, p in ipairs(planned) do
    local win = hs.window and hs.window.get and hs.window.get(p.id) or nil
    local info = window_info(win)
    if not info or info.id ~= p.id then
      skipped[#skipped + 1] = {
        slot = p.slot,
        id = p.id,
        reason = "WINDOW_NOT_FOUND",
      }
    else
      new_marks[p.slot] = { win = win, id = p.id }
      applied[#applied + 1] = {
        slot = p.slot,
        window = info,
      }
    end
  end

  -- 以下這邊是真正的影響, marks是一個外層的變數, 當熱鍵觸發(focus_slot)時，是以marks的變數為準
  for slot in pairs(marks) do
    marks[slot] = nil
  end
  for slot, entry in pairs(new_marks) do
    marks[slot] = entry
  end

  return {
    applied = applied,
    skipped = skipped,
  }
end

--- Register all window actions into the registry.
function M.register()
  registry.register("window.mark", M.mark)
  registry.register("window.focus_slot", M.focus_slot)
  registry.register("window.list_marks", M.list_marks)
  registry.register("window.clear_slot", M.clear_slot)
  registry.register("window.snapshot", M.snapshot)
  registry.register("window.apply_marks", M.apply_marks)
end

-- Modal is only armed after Cmd+F2.  Inner chords therefore cannot collide
-- with other global Cmd+digit / Cmd+letter bindings while the mode is inactive.
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

local function bind_slot(slot)
  -- Mark: Cmd + slot (only while modal is active)
  marks_modal:bind({ "cmd" }, slot, function()
    run_and_exit(M.mark, { slot = slot }, function(msg)
      hs.alert.show(msg, 1.0)
    end)
  end)

  -- Focus: bare slot key (only while modal is active)
  marks_modal:bind({}, slot, function()
    run_and_exit(M.focus_slot, { slot = slot }, function(msg)
      -- focus_slot already shows "Slot X is empty"; only show other errors
      if not msg:match("empty") then
        hs.alert.show(msg, 1.0)
      end
    end)
  end)
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

  for _, slot in ipairs(SLOT_ORDER) do
    bind_slot(slot)
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
