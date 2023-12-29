local M = {}

M.namespace = vim.api.nvim_create_namespace("treemonkey")

local function clear(bufs)
	for _, b in pairs(bufs) do
		vim.api.nvim_buf_clear_namespace(b, M.namespace, 0, -1)
	end
end

local function clear_tabpage()
	for _, w in pairs(vim.api.nvim_tabpage_list_wins(0)) do
		vim.api.nvim_buf_clear_namespace(vim.api.nvim_win_get_buf(w), M.namespace, 0, -1)
	end
end

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
	return vim.api.nvim_buf_set_extmark(opts.buf or 0, M.namespace, opts.row, opts.col, {
		virt_text = { { opts.label, opts.hi or "@text.warning" } },
		virt_text_pos = "overlay",
	})
end

---@param node TSNode
---@param hi? string
local function mark_node(node, hi)
	local srow, scol, erow, ecol = node:range()
	return vim.api.nvim_buf_set_extmark(0, M.namespace, srow, scol, {
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
	return srow, scol, erow, ecol == 0 and 0 or (ecol - 1)
end

---@param opts { row: integer, col: integer, label: string, hi?: string, buf: integer, ctx: Range4[] }
local function mark_treesitter_context(opts)
	local marks = {}
	for i, v in ipairs(opts.ctx) do
		if v[1] == opts.row then
			table.insert(marks, mark_label(vim.tbl_extend("force", opts, { row = i - 1 })))
		end
	end
	return marks
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
---@return TreemonkeyItem?
local function choose_node(nodes, opts)
	--[[ prep ]]
	local labelled = {} ---@type table<string, TreemonkeyItem>
	local positions = {} ---@type table<integer, table<integer, TreemonkeyItem[]>>
	local context = opts.experimental.treesitter_context and get_treesitter_context() or {}
	local first_marks = { [0] = {} } ---@type table<integer, integer[]>

	if opts.highlight.backdrop then
		table.insert(first_marks[0], mark_node(nodes[#nodes], opts.highlight.backdrop))
	end

	--[[ first choice ]]
	local psrow, pscol, perow, pecol ---@type integer?, integer?, integer?, integer?
	local cnt = 1
	for _, node in ipairs(nodes) do
		-- stop labelling if no more labels are available
		if not opts.labels[cnt] then
			break
		end

		if not opts.include_root and #nodes == cnt and node.id == nodes[#nodes]:tree():root().id then
			break
		end

		-- let node be a choice if the range differs from the range of the previously marked node
		local srow, scol, erow, ecol = range(node)
		if (psrow ~= srow or pscol ~= scol or perow ~= erow or pecol ~= ecol) and (srow ~= erow or scol ~= ecol) then
			psrow, pscol, perow, pecol = srow, scol, erow, ecol
			for _, v in pairs({
				{ row = srow, col = scol, label = opts.labels[cnt], hi = opts.highlight.label },
				{ row = erow, col = ecol, label = opts.labels[cnt]:upper(), hi = opts.highlight.label },
			}) do
				local item = { row = v.row, col = v.col, node = node, label = v.label }
				labelled[v.label] = item
				if not positions[v.row] then
					positions[v.row] = {}
				end

				if positions[v.row][v.col] then
					table.insert(positions[v.row][v.col], item)
				else
					positions[v.row][v.col] = { item }
					local o = { row = v.row, col = v.col, label = v.label, hi = v.hi }
					table.insert(first_marks[0], mark_label(o))
					if context.buf then
						o.buf = context.buf
						o.ctx = context.ranges
						first_marks[o.buf] = mark_treesitter_context(o)
					end
				end
			end
			cnt = cnt + 1
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
	if opts.steps == 1 or first_label:lower() == first_label:upper() then
		return first_choice
	end

	local ambiguity = positions[first_choice.row][first_choice.col]
	if opts.steps == nil and #ambiguity == 1 then
		return ambiguity[1]
	end

	if opts.steps ~= nil and opts.steps ~= 2 then
		error("TreemonkeyOpts.steps should be one of nil, 1 or 2")
	end

	--[[ second choice ]]
	-- clean up the extmarks from the first choice
	for buf, marks in pairs(first_marks) do
		for _, m in pairs(marks) do
			vim.api.nvim_buf_del_extmark(buf, M.namespace, m)
		end
	end

	-- highlight first choice
	if opts.highlight.first_node then
		mark_node(first_choice.node, opts.highlight.first_node)
	end

	-- add new backdrop
	if opts.highlight.backdrop then
		mark_node(ambiguity[#ambiguity].node, opts.highlight.backdrop)
	end

	-- prepare labels for the second choice
	for _, v in pairs(ambiguity) do
		local srow, scol, erow, ecol = range(v.node)
		for _, o in pairs({
			{ row = srow, col = scol, label = v.label, hi = opts.highlight.label },
			{ row = erow, col = ecol, label = v.label:upper(), hi = opts.highlight.label },
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

	-- determine the choice
	for _, v in pairs(ambiguity) do
		if v.label:lower() == second_label:lower() then
			return labelled[second_label]
		end
	end
end

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
---@return TreemonkeyItem?
function M.get(opts)
	opts = init_opts(opts)
	local nodes = gather_nodes(opts.ignore_injections)
	local item = choose_node(opts.filter and opts.filter(nodes) or nodes, opts)
	clear_tabpage()
	vim.cmd.redraw()
	return item
end

---@param opts TreemonkeyOpts?
---@return nil
function M.select(opts)
	local ok, result = pcall(M.get, opts)
	if ok then
		if result then
			(opts and opts.action or require("treemonkey.actions").update_selection)(result)
		end
	else
		clear_tabpage()
		vim.cmd.redraw()
		---@diagnostic disable-next-line: param-type-mismatch
		vim.notify(result, vim.log.levels.ERROR)
	end
end

return M
