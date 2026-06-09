local core = require("treemonkey.core")
local util = require("treemonkey.lsp.util")

local M = {}

M.namespace = core.namespace

--- Wrap an LSP `FoldingRange` into a |TreemonkeyNode|.
---
--- Folding ranges are line-oriented: `startCharacter`/`endCharacter` are
--- optional and, when absent, the range covers whole lines. In that case the
--- end column falls back to the byte length of the end line.
---@param fr table LSP FoldingRange ({ startLine, startCharacter?, endLine, endCharacter? })
---@param encoding "utf-8"|"utf-16"|"utf-32"
---@return TreemonkeyNode
local function make_node(fr, encoding)
	local srow = fr.startLine
	local scol = fr.startCharacter and util.to_byte(srow, fr.startCharacter, encoding) or 0

	local erow = fr.endLine
	local ecol
	if fr.endCharacter then
		ecol = util.to_byte(erow, fr.endCharacter, encoding)
	else
		ecol = #(vim.api.nvim_buf_get_lines(0, erow, erow + 1, false)[1] or "")
	end

	-- Every fold is a meaningful choice, so none is treated as the excludable
	-- root (is_root = false). Otherwise a lone fold around the cursor would be
	-- dropped by the default `include_root = false`.
	return util.make_node(srow, scol, erow, ecol, false)
end

---@return TreemonkeyNode[]
local function gather_nodes()
	local clients = vim.lsp.get_clients({ bufnr = 0, method = "textDocument/foldingRange" })
	if #clients == 0 then
		vim.notify("treemonkey: no LSP client supports textDocument/foldingRange", vim.log.levels.WARN)
		return {}
	end

	local client = clients[1]
	local params = { textDocument = vim.lsp.util.make_text_document_params(0) }

	local response = client:request_sync("textDocument/foldingRange", params, 1000, 0)
	if not response or response.err or not response.result then
		return {}
	end

	-- foldingRange returns every fold in the document. Keep only the folds that
	-- contain the cursor line, reconstructing a nesting chain comparable to the
	-- selectionRange backend.
	local crow = vim.api.nvim_win_get_cursor(0)[1] - 1
	local containing = {} ---@type table[]
	for _, fr in ipairs(response.result) do
		if fr.startLine <= crow and crow <= fr.endLine then
			table.insert(containing, fr)
		end
	end

	-- Order from the innermost (smallest span) to the outermost (largest span).
	table.sort(containing, function(a, b)
		local span_a = a.endLine - a.startLine
		local span_b = b.endLine - b.startLine
		if span_a ~= span_b then
			return span_a < span_b
		end
		-- Same number of lines: the one starting later is more deeply nested.
		return a.startLine > b.startLine
	end)

	local nodes = {} ---@type TreemonkeyNode[]
	for _, fr in ipairs(containing) do
		table.insert(nodes, make_node(fr, client.offset_encoding))
	end
	return nodes
end

---@param node TreemonkeyNode
---@return boolean
local function is_root(node)
	return node.is_root == true
end

---@param opts TreemonkeyOpts?
---@return TreemonkeyItem?
function M.get(opts)
	return core.get(function()
		return gather_nodes()
	end, is_root, opts)
end

---@param opts TreemonkeyOpts?
---@return nil
function M.select(opts)
	return core.select(M.get, opts)
end

return M
