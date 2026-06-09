local M = {}

--- Node selection backend based on the LSP `textDocument/selectionRange`
--- request.
M.selection_range = require("treemonkey.lsp.selection_range")

--- Node selection backend based on the LSP `textDocument/foldingRange`
--- request.
M.folding_range = require("treemonkey.lsp.folding_range")

return M
