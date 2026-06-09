local core = require("treemonkey.core")

local M = {}

M.namespace = core.namespace

--- Convert an LSP character offset (in the client's `offset_encoding`) into a
--- 0-indexed byte column, so the range becomes compatible with |TSNode:range()|.
---@param row integer 0-indexed line
---@param character integer LSP character offset on the line
---@param encoding "utf-8"|"utf-16"|"utf-32"
---@return integer byte column (0-indexed)
local function to_byte(row, character, encoding)
	if character <= 0 then
		return 0
	end
	local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
	-- Neovim >= 0.11 signature: str_byteindex(s, encoding, index, strict?)
	local ok, byte = pcall(vim.str_byteindex, line, encoding, character, false)
	if ok then
		return byte
	end
	-- Fallback for older Neovim: str_byteindex(s, index, use_utf16)
	local ok2, byte2 = pcall(vim.str_byteindex, line, character, encoding == "utf-16")
	if ok2 then
		return byte2
	end
	return math.min(character, #line)
end

--- Wrap an LSP `Range` into a |TreemonkeyNode|.
---@param range table LSP Range ({ start = Position, ["end"] = Position })
---@param encoding "utf-8"|"utf-16"|"utf-32"
---@param is_root boolean
---@return TreemonkeyNode
local function make_node(range, encoding, is_root)
	local srow = range.start.line
	local scol = to_byte(srow, range.start.character, encoding)
	local erow = range["end"].line
	local ecol = to_byte(erow, range["end"].character, encoding)
	return {
		is_root = is_root,
		---@return integer, integer, integer, integer
		range = function()
			return srow, scol, erow, ecol
		end,
	}
end

--- Flatten an LSP SelectionRange linked list into candidate nodes ordered from
--- the innermost to the outermost (matching the treesitter parent chain order).
---@param selection_range table LSP SelectionRange ({ range = Range, parent? = SelectionRange })
---@param encoding "utf-8"|"utf-16"|"utf-32"
---@return TreemonkeyNode[]
local function flatten(selection_range, encoding)
	local nodes = {} ---@type TreemonkeyNode[]
	local sr = selection_range
	while sr do
		table.insert(nodes, make_node(sr.range, encoding, sr.parent == nil))
		sr = sr.parent
	end
	return nodes
end

---@return TreemonkeyNode[]
local function gather_nodes()
	local clients = vim.lsp.get_clients({ bufnr = 0, method = "textDocument/selectionRange" })
	if #clients == 0 then
		vim.notify("treemonkey: no LSP client supports textDocument/selectionRange", vim.log.levels.WARN)
		return {}
	end

	local client = clients[1]
	local position_params = vim.lsp.util.make_position_params(0, client.offset_encoding)
	local params = {
		textDocument = position_params.textDocument,
		positions = { position_params.position },
	}

	local response = client:request_sync("textDocument/selectionRange", params, 1000, 0)
	if not response or response.err or not response.result or not response.result[1] then
		return {}
	end

	return flatten(response.result[1], client.offset_encoding)
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
