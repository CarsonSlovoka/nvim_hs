--- Minimal pure-Lua style tests for Neovim-side protocol.
--- Run inside Neovim:
---   :luafile tests/test_protocol_nvim.lua
--- or
---   nvim --headless -c 'luafile tests/test_protocol_nvim.lua' -c 'qa'

local protocol = require("nvim_hs.protocol")

local failures = 0

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    failures = failures + 1
    print(string.format("FAIL: %s\n  expected: %s\n  actual:   %s", msg, tostring(expected), tostring(actual)))
  else
    print("OK: " .. msg)
  end
end

local function assert_true(cond, msg)
  if not cond then
    failures = failures + 1
    print("FAIL: " .. msg)
  else
    print("OK: " .. msg)
  end
end

-- encode_request
local b64, err = protocol.encode_request("system.ping", {})
assert_true(b64 ~= nil and err == nil, "encode_request succeeds for system.ping")
assert_true(type(b64) == "string" and #b64 > 0, "encode_request returns non-empty string")

-- decode a known good response
local good = '{"ok":true,"data":"pong"}'
local resp, derr = protocol.decode_response(good)
assert_true(resp ~= nil and derr == nil, "decode_response succeeds")
assert_eq(resp.ok, true, "decoded ok == true")
assert_eq(resp.data, "pong", "decoded data == pong")

-- decode with trailing newline (CLI often adds it)
local resp2, _ = protocol.decode_response(good .. "\n")
assert_eq(resp2 and resp2.data, "pong", "decode tolerates trailing newline")

-- invalid JSON
local bad, berr = protocol.decode_response("{not json")
assert_true(bad == nil and berr ~= nil, "decode_response rejects invalid JSON")

-- error constructor
local e = protocol.err("TEST_CODE", "test message")
assert_eq(e.ok, false, "err().ok == false")
assert_eq(e.error.code, "TEST_CODE", "err().error.code")
assert_eq(e.error.message, "test message", "err().error.message")

print("\n----")
if failures == 0 then
  print("All protocol tests passed.")
else
  print(string.format("%d test(s) failed.", failures))
end
