---@diagnostic disable: undefined-global  -- 略過hs沒有定義

local M = {}

M.encode = hs and hs.base64.encode or vim.base64.encode
M.decode = hs and hs.base64.decode or vim.base64.decode

return M
