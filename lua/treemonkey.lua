local M = {}

M.namepace = vim.api.nvim_create_namespace("treemonkey")

-- stylua: ignore
local labels_default = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"}

---@return string?
local function getcharstr()
	local ok, res = pcall(vim.fn.getcharstr)
	if ok then
		return res
	elseif res ~= nil then
		vim.notify(res, vim.log.levels.ERROR)
		return
	end
end

---@param opts { row: integer, col: integer, label: string, hi?: string, buf?: integer }
local function mark_label(opts)
	vim.api.nvim_buf_set_extmark(opts.buf or 0, M.namepace, opts.row, opts.col, {
		virt_text = { { opts.label, opts.hi or "@text.warning" } },
		virt_text_pos = "overlay",
	})
end

---@param node TSNode
---@param hi? string
local function mark_selection(node, hi)
	local srow, scol, erow, ecol = node:range()
	vim.api.nvim_buf_set_extmark(0, M.namepace, srow, scol, {
		end_row = erow,
		end_col = ecol,
		hl_group = hi or "Visual",
	})
end

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

	if not node or (#nodes > 0 and nodes[1]:id() == node:id()) then
		return nodes
	end

	while node do
		table.insert(nodes, node)
		node = node:parent()
	end

	return nodes
end

--- Get range of a TSNode
---
--- In some cases, TSNode:range() gives 0 as a column of the end position.
--- This may cause strange selection e.g., in a markdown code block with injection
--[[
``` lua
print("foo")
```
]]
local function range(node)
	local srow, scol, erow, ecol = node:range()
	if ecol == 0 and erow > srow then
		erow = erow - 1
		ecol = string.len(vim.api.nvim_buf_get_lines(0, erow, erow + 1, true)[1])
	end
	return srow, scol, erow, ecol
end

---@param opts { row: integer, col: integer, label: string, hi?: string, buf: integer, ctx: Range4[] }
local function mark_treesitter_context(opts)
	for i, v in ipairs(opts.ctx) do
		if v[1] == opts.row then
			mark_label(vim.tbl_extend("force", opts, { row = i - 1 }))
		end
	end
end

local function get_treesitter_context()
	for _, w in pairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.w[w].treesitter_context then
			return {
				buf = vim.api.nvim_win_get_buf(w),
				ranges = require("treesitter-context.context").get(
					vim.api.nvim_get_current_buf(),
					vim.api.nvim_get_current_win()
				),
			}
		end
	end
end

---@param nodes TSNode[]
---@param opts TreemonkeyOpts
---@return TSNode?
local function choose_node(nodes, opts)
	--[[ prep ]]
	---@type table<string, { [1]: integer, [2]: integer, [3]: TSNode }>
	local labelled = {}
	---@type table<integer, table<integer, {node: TSNode, label: string}[]>>
	local positions = {}
	local context = opts.experimental.treesitter_context and get_treesitter_context() or {}

	--[[ first choice ]]
	local psrow, pscol, perow, pecol ---@type integer?, integer?, integer?, integer?
	for cnt, node in ipairs(nodes) do
		-- stop labelling if no more labels are available
		if not opts.labels[cnt] then
			break
		end

		if not opts.include_root and #nodes == cnt and node.id == nodes[#nodes]:tree():root().id then
			break
		end

		-- let node be a choice if the range differs from the range of the previously marked node
		local srow, scol, erow, ecol = range(node)
		if psrow ~= srow or pscol ~= scol or perow ~= erow or pecol ~= ecol then
			psrow, pscol, perow, pecol = srow, scol, erow, ecol
			for _, v in pairs({
				{ row = srow, col = scol, label = opts.labels[cnt], hi = opts.highlight.label },
				{ row = erow, col = ecol, label = opts.labels[cnt]:upper(), hi = opts.highlight.label },
			}) do
				labelled[v.label] = { v.row, v.col, node }
				if not positions[v.row] then
					positions[v.row] = {}
				end

				if positions[v.row][v.col] then
					table.insert(positions[v.row][v.col], { node = node, label = v.label })
				else
					positions[v.row][v.col] = { { node = node, label = v.label } }
					local o = { row = v.row, col = v.col, label = v.label, hi = v.hi }
					mark_label(o)
					if context.buf then
						o.buf = context.buf
						o.ctx = context.ranges
						mark_treesitter_context(o)
					end
				end
			end
		end
	end

	vim.cmd.redraw()
	local first_label = getcharstr()
	if not first_label then
		return
	end

	local first_choice = labelled[first_label]

	if not first_choice then
		return nil
	end

	-- if choice is made by a label without upper case (e.g., 1, 2, 3, !, @, ...),
	if first_label:lower() == first_label:upper() then
		return first_choice[3]
	end

	local ambiguity = positions[first_choice[1]][first_choice[2]]
	if #ambiguity == 1 then
		return ambiguity[1].node
	end

	--[[ second choice ]]
	vim.api.nvim_buf_clear_namespace(0, M.namepace, 0, -1)
	mark_selection(first_choice[3])
	for _, v in pairs(ambiguity) do
		local srow, scol, erow, ecol = range(v.node)
		for _, o in pairs({
			{ row = srow, col = scol, label = v.label, hi = opts.highlight.label },
			{ row = erow, col = ecol - 1, label = v.label:upper(), hi = opts.highlight.label },
		}) do
			mark_label(o)
			if context.buf then
				o.buf = context.buf
				o.ctx = context.ranges
				mark_treesitter_context(o)
			end
		end
	end
	vim.cmd.redraw()

	local second_label = getcharstr()
	if not second_label then
		return
	end

	for _, v in pairs(ambiguity) do
		if v.label:lower() == second_label:lower() then
			return v.node
		end
	end
end

---@class TreemonkeyOpts
---@field highlight { label: string }
---@field ignore_injections? boolean
---@field include_root? boolean
---@field labels string[]
---@field experimental { treesitter_context: boolean }

---@param opts? TreemonkeyOpts
---@return TreemonkeyOpts
local function init_opts(opts)
	return vim.tbl_deep_extend("keep", opts or {}, {
		highlight = { label = "@text.warning" },
		labels = labels_default,
		experimental = {},
	})
end

---@param opts TreemonkeyOpts?
function M.get(opts)
	opts = init_opts(opts)
	local node = choose_node(gather_nodes(opts.ignore_injections), opts)
	vim.api.nvim_buf_clear_namespace(0, M.namepace, 0, -1)
	vim.cmd.redraw()
	return node
end

---@param opts TreemonkeyOpts?
function M.select(opts)
	local ok, result = pcall(M.get, opts)
	if ok then
		if result then
			require("nvim-treesitter.ts_utils").update_selection(0, result)
		end
	else
		vim.api.nvim_buf_clear_namespace(0, M.namepace, 0, -1)
		vim.cmd.redraw()
		---@diagnostic disable-next-line: param-type-mismatch
		vim.notify(result, vim.log.levels.ERROR)
	end
end

return M
