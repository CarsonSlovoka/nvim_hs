--- Hammerspoon-side unit tests for registry / dispatcher / protocol / system actions.
--- Load inside the Hammerspoon console (after the framework is required):
---
---   hs.dofile("/path/to/repo/tests/test_hs_framework.lua")
---
--- or evaluate the file contents.
---
--- nvim -u NONE -l test_hs_framework.lua
--- nvim         -l test_hs_framework.lua

local script_file = debug.getinfo(1, "S").source:sub(2)
script_file = assert(vim.uv.fs_realpath(script_file))
local git_root = vim.fn.fnamemodify(script_file, ":h:h:p")
local hammerspoon_dir = vim.fs.joinpath(git_root, "hammerspoon")
local module_paths = {
  hammerspoon_dir .. "/?.lua",
  hammerspoon_dir .. "/?/init.lua", -- require("nvim_hs") 時，只要前面package.path抓不到此nvim_hs.lua就會找nvim_hs/init.lua
}
-- vim.opt.runtimepath:prepend(hammerspoon_dir .. "/nvim_hs") -- runtimepath 會優先於package.path -- 但是這樣加也沒用因為底下目錄的結構不是lua/*
package.path = table.concat(module_paths, ";") .. ";" .. package.path
-- print(package.path)
-- print(vim.inspect(vim.opt.runtimepath))


local protocol = require("nvim_hs.protocol")
-- print(vim.inspect(vim.loader.find("nvim_hs.protocol", { all = true }))) -- 如果載入的module找不到，或者懷疑找錯路徑，可以這樣來查
-- print(vim.loader.find("nvim_hs.protocol", { all = true })[1].modpath)
local registry = require("nvim_hs.registry") -- ../hammerspoon/nvim_hs/registry.lua
local dispatcher = require("nvim_hs.dispatcher")

local failures = 0

local function assert_eq(a, b, msg)
  if a ~= b then
    failures = failures + 1
    print(string.format("FAIL: %s (expected %s, got %s)", msg, tostring(b), tostring(a)))
  else
    print("OK: " .. msg)
  end
end

local function assert_true(c, msg)
  if not c then
    failures = failures + 1
    print("FAIL: " .. msg)
  else
    print("OK: " .. msg)
  end
end


-- require("nvim_hs.actions.system").register() -- ../hammerspoon/nvim_hs/actions/system.lua -- 註冊自定義的pint, list事件
local nvim_hs = require("nvim_hs") -- 可以直接找 ../hammerspoon/nvim_hs/init.lua 來初始化. 包含了事件的定義

print("=== registry ===")
local names = registry.list() -- 由於: require("nvim_hs.actions.system").register() 的關係，此時至少有2個項目
assert_true(#names >= 2, "at least two actions registered")
assert_true(registry.has("system.ping"), "system.ping is registered")
assert_true(registry.has("system.list"), "system.list is registered")
assert_true(not registry.has("foo.bar"), "unknown action is not registered")

print("=== protocol encode/decode ===")
local req = { version = 1, action = "system.ping", payload = {} }
local b64, enc_err = protocol.encode(req)
assert_true(b64 ~= nil and enc_err == nil, "protocol.encode succeeds")
local decoded, dec_err = protocol.decode(b64)
assert_true(decoded ~= nil and dec_err == nil, "protocol.decode succeeds")
assert_eq(decoded.action, "system.ping", "round-trip action")

print("=== dispatcher success ===")
local resp = dispatcher.dispatch({ version = 1, action = "system.ping", payload = {} })
assert_eq(resp.ok, true, "ping ok")
assert_eq(resp.data, "pong", "ping data")

print("=== dispatcher unknown action ===")
local resp2 = dispatcher.dispatch({ version = 1, action = "foo.bar", payload = {} })
assert_eq(resp2.ok, false, "unknown action → not ok")
assert_eq(resp2.error.code, "ACTION_NOT_FOUND", "error code ACTION_NOT_FOUND")

print("=== dispatcher invalid request ===")
local resp3 = dispatcher.dispatch({ version = 99, action = "system.ping" })
assert_eq(resp3.ok, false, "bad version → not ok")
assert_eq(resp3.error.code, "INVALID_REQUEST", "error code INVALID_REQUEST")

print("=== system.list ===")
local resp4 = dispatcher.dispatch({ version = 1, action = "system.list", payload = {} })
assert_eq(resp4.ok, true, "list ok")
assert_true(type(resp4.data) == "table", "list data is table")
local found_ping, found_list = false, false
for _, n in ipairs(resp4.data) do
  if n == "system.ping" then found_ping = true end
  if n == "system.list" then found_list = true end
end
assert_true(found_ping and found_list, "list contains system.ping and system.list")

print("=== full handle path ===")
local b64req = protocol.encode({ version = 1, action = "system.ping", payload = {} })
local json_out = nvim_hs.handle(b64req)
local final = require("nvim_hs.encoding.json").decode(json_out)
assert_eq(final.ok, true, "handle() returns ok response")
assert_eq(final.data, "pong", "handle() data is pong")

print("\n----")
if failures == 0 then
  print("✅ All Hammerspoon framework tests passed.")
else
  io.stderr:write(string.format("\n%d test(s) failed.\n", failures))
  vim.cmd.cquit(1)
end
