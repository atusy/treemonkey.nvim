local core = require("treemonkey.core")
local util = require("treemonkey.lsp.util")

local M = {}

M.namespace = core.namespace

--- Wrap an LSP `Range` into a |TreemonkeyNode|.
---@param range table LSP Range ({ start = Position, ["end"] = Position })
---@param encoding "utf-8"|"utf-16"|"utf-32"
---@param is_root boolean
---@return TreemonkeyNode
local function make_node(range, encoding, is_root)
	local srow = range.start.line
	local scol = util.to_byte(srow, range.start.character, encoding)
	local erow = range["end"].line
	local ecol = util.to_byte(erow, range["end"].character, encoding)
	return util.make_node(srow, scol, erow, ecol, is_root)
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
