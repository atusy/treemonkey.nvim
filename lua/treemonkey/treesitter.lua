local core = require("treemonkey.core")

local M = {}

M.namespace = core.namespace

---@param ignore_injections boolean
---@return TSNode[]
local function gather_nodes(ignore_injections)
	local nodes = {} ---@type TSNode[]

	if not ignore_injections then
		local node = vim.treesitter.get_node({ ignore_injections = false })
		while node do
			table.insert(nodes, node)
			node = node:parent()
		end
	end

	local node = vim.treesitter.get_node({ ignore_injections = true })

	if not node or (#nodes > 0 and node:equal(nodes[1])) then
		return nodes
	end

	while node do
		table.insert(nodes, node)
		node = node:parent()
	end

	return nodes
end

---@param node TSNode
---@return boolean
local function is_root(node)
	return node:equal(node:tree():root())
end

---@param opts TreemonkeyOpts?
---@return TreemonkeyItem?
function M.get(opts)
	return core.get(function(o)
		return gather_nodes(o.ignore_injections)
	end, is_root, opts)
end

---@param opts TreemonkeyOpts?
---@return nil
function M.select(opts)
	return core.select(M.get, opts)
end

return M
