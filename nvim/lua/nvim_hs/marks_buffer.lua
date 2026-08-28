--- nvim_hs.marks_buffer
--- Scratch buffer frontend for window.snapshot / window.apply_marks.
--- Parsing happens here; Hammerspoon only receives structured { items = ... }.

local nvim_hs = require("nvim_hs")

local M = {}

local BUF_NAME = "nvim_hs://marks"

local HEADER = {
  "# slot<TAB>id<TAB>app<TAB>title",
  "# slot = 1-9 / a-z to assign,  -  to leave unmarked.",
  "# Delete a line to unmark.  Duplicate slot or id is rejected.",
  "# :w applies the whole buffer.  :HsMarks refreshes the snapshot.",
  "#",
}

--- @param text string
--- @return string
local function sanitize_field(text)
  text = tostring(text or ""):gsub("[\t\r\n]", " ")
  return text
end

--- Format snapshot windows into buffer lines.
--- @param windows table[]
--- @return string[]
function M.format_snapshot(windows)
  local lines = vim.deepcopy(HEADER)
  for _, win in ipairs(windows or {}) do
    local slot = win.slot
    if slot == vim.NIL or type(slot) ~= "string" or slot == "" then
      slot = "-"
    end
    lines[#lines + 1] = table.concat({
      slot,
      tostring(win.id or ""),
      sanitize_field(win.app),
      sanitize_field(win.title),
    }, "\t")
  end
  return lines
end

--- Parse buffer lines into apply payload items.
--- Lines with slot "-" / "." are omitted (unmarked).
--- Duplicate slot or id → err (reject whole apply).
--- @param lines string[]
--- @return table|nil items
--- @return string|nil err
function M.parse_buffer_lines(lines)
  local items = {}
  local by_slot = {}
  local by_id = {}

  for i, line in ipairs(lines or {}) do
    if line:match("^%s*$") or line:match("^%s*#") then
      goto continue
    end

    local slot, id_s, rest = line:match("^([^\t]+)\t([^\t]+)\t(.*)$")
    if not slot then
      slot, id_s = line:match("^(%S+)%s+(%S+)")
    end
    if not slot or not id_s then
      return nil, string.format("line %d: expected 'slot<TAB>id<TAB>app<TAB>title'", i)
    end

    slot = vim.trim(slot):lower()
    id_s = vim.trim(id_s)
    if slot == "-" or slot == "." then
      goto continue
    end
    if not slot:match("^[1-9]$") and not slot:match("^[a-z]$") then
      return nil, string.format("line %d: slot must be 1-9 or a-z (got %q)", i, slot)
    end
    if not id_s:match("^%d+$") then
      return nil, string.format("line %d: id must be a number (got %q)", i, id_s)
    end

    local id = tonumber(id_s)
    if by_slot[slot] then
      return nil, "DUPLICATE_SLOT: slot " .. slot .. " assigned more than once"
    end
    if by_id[id] then
      return nil, "DUPLICATE_ID: window id " .. tostring(id) .. " assigned to more than one slot"
    end
    by_slot[slot] = i
    by_id[id] = i
    items[#items + 1] = { slot = slot, id = id }

    ::continue::
  end

  return items, nil
end

local function find_buf()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == BUF_NAME then
      return buf
    end
  end
  return nil
end

local function notify_resp(resp)
  if resp.ok then
    local data = resp.data or {}
    local applied = data.applied or {}
    local skipped = data.skipped or {}
    local msg = string.format("applied %d mark(s)", #applied)
    if #skipped > 0 then
      msg = msg .. string.format(", skipped %d", #skipped)
    end
    vim.notify("[nvim_hs] " .. msg, vim.log.levels.INFO)
    if #skipped > 0 then
      local details = {}
      for _, s in ipairs(skipped) do
        details[#details + 1] = string.format("slot %s id %s (%s)", tostring(s.slot), tostring(s.id), s.reason or "?")
      end
      vim.notify("[nvim_hs] skipped: " .. table.concat(details, "; "), vim.log.levels.WARN)
    end
  else
    local err = resp.error or {}
    vim.notify(
      string.format("[nvim_hs] %s: %s", err.code or "ERROR", err.message or "unknown"),
      vim.log.levels.ERROR
    )
  end
end

--- Apply the given buffer's text via window.apply_marks.
--- @param buf integer
--- @return boolean ok
function M.apply_buf(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local items, err = M.parse_buffer_lines(lines)
  if not items then
    vim.notify("[nvim_hs] " .. err, vim.log.levels.ERROR)
    return false
  end

  local resp = nvim_hs.run("window.apply_marks", { items = items })
  notify_resp(resp)
  return resp.ok == true
end

local function windows_from_snapshot(data)
  if type(data) ~= "table" then
    return {}
  end
  local raw = data.windows
  if type(raw) ~= "table" then
    -- Tolerate a bare list in case an older handler shape comes back.
    if data[1] ~= nil then
      raw = data
    else
      return {}
    end
  end
  if raw[1] ~= nil then
    return raw
  end
  local list = {}
  for _, win in pairs(raw) do
    if type(win) == "table" and win.id ~= nil then
      list[#list + 1] = win
    end
  end
  return list
end

local function write_snapshot(buf)
  local resp = nvim_hs.run("window.snapshot") -- 呼叫hs來通知其要做snapshot
  local lines
  if not resp.ok then
    local err = resp.error or {}
    local code = err.code or "ERROR"
    local message = err.message or "snapshot failed"
    vim.notify(string.format("[nvim_hs] %s: %s", code, message), vim.log.levels.ERROR)
    lines = vim.deepcopy(HEADER)
    lines[#lines + 1] = string.format("# snapshot failed: %s: %s", code, message)
    if code == "ACTION_NOT_FOUND" then
      lines[#lines + 1] = "# Reload Hammerspoon so window.snapshot is registered, then run :HsMarks again."
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modified = false
    return false
  end

  -- 將從hs得到的結果，寫回到buffer之中
  local windows = windows_from_snapshot(resp.data)
  lines = M.format_snapshot(windows)
  if #windows == 0 then
    lines[#lines + 1] = "# No windows returned. Marks are optional; you can still assign slots after a refresh."
    lines[#lines + 1] = "# If this keeps happening: Reload Hammerspoon and grant Accessibility to Hammerspoon."
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false
  return true
end

local function configure_buf(buf)
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "nvim_hs_marks"
  vim.bo[buf].modifiable = true

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    desc = "Apply nvim_hs window marks from buffer",
    callback = function()
      if M.apply_buf(buf) then
        vim.bo[buf].modified = false
      end
    end,
  })
end

--- Open (or refresh) the marks scratch buffer.
function M.open()
  local buf = find_buf()
  if not buf then
    buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(buf, BUF_NAME)
    configure_buf(buf) -- 定義了 acwrite 事件, 使得 :w 時可以再做給 hs 通知它要更新. 執行 window.apply_marks
  end

  if not write_snapshot(buf) then
    return
  end

  vim.api.nvim_set_current_buf(buf)
end

--- Create :HsMarks
function M.setup()
  vim.api.nvim_create_user_command("HsMarks", function()
    M.open()
  end, {
    desc = "Edit Hammerspoon window marks in a scratch buffer",
  })
end

return M
