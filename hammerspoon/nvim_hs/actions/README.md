在註冊函數的handler上，handler的回傳值最好只用一個，例如:

```lua
local M = {}

--- @param payload table
--- @return number
--- @return number
function M.good(payload)
  return {12, 34}
end

function M.bad(payload)
  return 12, 34
end

require("nvim_hs.registry").("system.test_good", M.good)
require("nvim_hs.registry").("system.test_bad",  M.bad)
```

這是因為在調用Hs時它是用:

```lua
vim.api.nvim_create_user_command("Hs", function(opts)
    -- ...
    local resp = nvim_hs.run(action, payload) -- 這邊只有收一個回傳值
    -- local resp, ret2 = nvim_hs.run(action, payload) -- 如果設計成這樣就能有兩個回傳值
    print_response(resp)
end)
```

```sh
git show -p 6d65aeb5:nvim/lua/nvim_hs/command.lua | bat -l lua -P -r 42:64 -r 68 -r 75:76 -r 77
```
