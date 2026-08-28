--- nvim -u NONE -l tests/test_marks_buffer.lua

local script_file = debug.getinfo(1, "S").source:sub(2)
script_file = assert(vim.uv.fs_realpath(script_file))
local git_root = vim.fn.fnamemodify(script_file, ":h:h:p")
local nvim_lua = vim.fs.joinpath(git_root, "nvim/lua")
package.path = nvim_lua .. "/?.lua;" .. nvim_lua .. "/?/init.lua;" .. package.path

local marks_buffer = require("nvim_hs.marks_buffer")

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

print("=== format_snapshot ===")
local lines = marks_buffer.format_snapshot({
  { slot = "a", id = 11, app = "Safari", title = "GitHub" },
  { id = 22, app = "Finder", title = "Downloads" },
})
local joined = table.concat(lines, "\n")
assert_true(joined:find("a\t11\tSafari\tGitHub", 1, true) ~= nil, "assigned row uses tabs")
assert_true(joined:find("-\t22\tFinder\tDownloads", 1, true) ~= nil, "unmarked row uses '-'")

print("=== format empty snapshot ===")
local empty_lines = marks_buffer.format_snapshot({
  { slot = "", id = 33, app = "WezTerm", title = "nvim" },
})
assert_true(table.concat(empty_lines, "\n"):find("-\t33\tWezTerm\tnvim", 1, true) ~= nil, "empty slot string is unmarked")
local header_only = marks_buffer.format_snapshot({})
local items_empty, err_empty = marks_buffer.parse_buffer_lines(header_only)
assert_true(err_empty == nil, "header-only snapshot parses")
assert_eq(#items_empty, 0, "header-only snapshot yields no items")

print("=== parse assigned + unmarked + comments ===")
local items, err = marks_buffer.parse_buffer_lines({
  "# comment",
  "a\t11\tSafari\tGitHub",
  "-\t22\tFinder\tDownloads",
  "3\t33\tCode\twindow.lua",
})
assert_true(err == nil, "parse succeeds")
assert_eq(#items, 2, "unmarked and comments omitted")
assert_eq(items[1].slot, "a", "first slot")
assert_eq(items[1].id, 11, "first id")
assert_eq(items[2].slot, "3", "second slot")
assert_eq(items[2].id, 33, "second id")

print("=== parse deleted line means unmarked ===")
items, err = marks_buffer.parse_buffer_lines({
  "a\t11\tSafari\tGitHub",
})
assert_true(err == nil and #items == 1, "only remaining assigned line is kept")

print("=== parse duplicate slot ===")
items, err = marks_buffer.parse_buffer_lines({
  "a\t11\tSafari\tA",
  "a\t22\tFinder\tB",
})
assert_true(items == nil, "duplicate slot rejected")
assert_true(tostring(err):find("DUPLICATE_SLOT", 1, true) ~= nil, "duplicate slot error")

print("=== parse duplicate id ===")
items, err = marks_buffer.parse_buffer_lines({
  "a\t11\tSafari\tA",
  "b\t11\tFinder\tB",
})
assert_true(items == nil, "duplicate id rejected")
assert_true(tostring(err):find("DUPLICATE_ID", 1, true) ~= nil, "duplicate id error")

print("=== parse invalid slot ===")
items, err = marks_buffer.parse_buffer_lines({ "foo\t11\tSafari\tA" })
assert_true(items == nil and tostring(err):find("slot", 1, true) ~= nil, "invalid slot rejected")

print("\n----")
if failures == 0 then
  print("✅ All marks_buffer tests passed.")
else
  io.stderr:write(string.format("\n%d test(s) failed.\n", failures))
  vim.cmd.cquit(1)
end
