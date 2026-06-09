local M = {}

local treesitter = require("treemonkey.treesitter")

--- Node selection backend based on |vim.treesitter|.
M.treesitter = treesitter

M.namespace = treesitter.namespace

--- Alias of |treemonkey.treesitter.get| kept for backward compatibility.
M.get = treesitter.get

--- Alias of |treemonkey.treesitter.select| kept for backward compatibility.
M.select = treesitter.select

return M
