--- Hammerspoon-side unit tests for registry / dispatcher / protocol / system actions.
--- Load inside the Hammerspoon console (after the framework is required):
---
---   hs.dofile("/path/to/repo/tests/test_hs_framework.lua")
---
--- or evaluate the file contents.

local protocol = require("nvim_hs.protocol")
local registry = require("nvim_hs.registry")
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

print("=== registry ===")
local names = registry.list()
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
local nvim_hs = require("nvim_hs")
local b64req = protocol.encode({ version = 1, action = "system.ping", payload = {} })
local json_out = nvim_hs.handle(b64req)
local final = hs.json.decode(json_out)
assert_eq(final.ok, true, "handle() returns ok response")
assert_eq(final.data, "pong", "handle() data is pong")

print("\n----")
if failures == 0 then
  print("All Hammerspoon framework tests passed.")
else
  print(string.format("%d test(s) failed.", failures))
end
