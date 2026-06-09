local M = {}

--- Node selection backend based on the LSP `textDocument/selectionRange`
--- request.
M.selection_range = require("treemonkey.lsp.selection_range")

return M
