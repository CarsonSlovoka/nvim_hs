---@diagnostic disable: undefined-global  -- 略過hs沒有定義

local M = {}

M.encode = hs and hs.json.encode or vim.json.encode -- 為了也能用nvim來測試
M.decode = hs and hs.json.decode or vim.json.decode

return M
