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

local nvim_hs = require("nvim_hs") -- 在hammerspoon下它還會找裡面的init.lua 即　~/.hammerspoon/nvim_hs/init.lua 對應於 ./nvim_hs/init.lua

-- Optional: expose a global for quick interactive testing from the HS console.
_G.nvim_hs = nvim_hs

print("[nvim_hs] framework loaded – actions: " .. table.concat(nvim_hs.registry.list(), ", "))
