--- 這只是一個範例，應該要把這些東西加入到: ~/.hammerspoon/init.lua 之中
---
--- Example Hammerspoon root init.lua for the nvim_hs framework.
---
--- Usage options:
---   1. Copy the whole `hammerspoon/` tree into ~/.hammerspoon/
---      then simply require this file (or the modules).
---   2. Keep the repo elsewhere and add its path to package.path
---      (see README).
---
--- This file stays minimal: it only bootstraps IPC and the framework.

-- Required for the `hs` CLI tool.
require("hs.ipc")
-- hs.ipc.cliInstall() -- 這也行, 同: require("hs.ipc")

-- Load the framework.  Adjust package.path if the modules live outside
-- the default Hammerspoon search path.
-- Example (uncomment and edit if needed):
-- package.path = package.path
--   .. ";/path/to/this/repo/hammerspoon/?.lua"
--   .. ";/path/to/this/repo/hammerspoon/?/init.lua"


-- hammerspoon 它有加入 package.path = ~/.hammerspoon/?/init.lua .. package.path 所以當 reqire("nvim_hs")時，會找 ~/.hammerspoon/nvim_hs/init.lua 也就是此檔案: ./nvim_hs/init.lua
local nvim_hs = require("nvim_hs") -- 載入: ./nvim_hs/init.lua

-- require("nvim_hs.registry").register(name, handler) -- Tip: 也能自己再新增想要的事件處理

-- Optional: expose a global for quick interactive testing from the HS console.
_G.nvim_hs = nvim_hs

print("[nvim_hs] framework loaded – actions: " .. table.concat(nvim_hs.registry.list(), ", "))
