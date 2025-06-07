local M = {}

M.namespace = vim.api.nvim_create_namespace("treemonkey")

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

---@param buf integer
---@param opts { row: integer, col: integer, label: string, hi: string }
local function mark_label(buf, opts)
	return vim.api.nvim_buf_set_extmark(buf, M.namespace, opts.row, opts.col, {
		virt_text = { { opts.label, opts.hi or "@text.warning" } },
		virt_text_pos = "overlay",
	})
end

---@param node TSNode
---@param hi? string
local function mark_node(node, hi)
	if not hi then
		return
	end
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

	if not node or (#nodes > 0 and node:equal(nodes[1])) then
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
---@param node TSNode
---@return integer, integer, integer, integer
local function range(node)
	local srow, scol, erow, ecol = node:range()
	if ecol == 0 and erow > srow then
		erow = erow - 1
		ecol = string.len(vim.api.nvim_buf_get_lines(0, erow, erow + 1, true)[1])
	end
	return srow, scol, erow, ecol == 0 and 0 or (ecol - 1)
end

---@param ctx { buf: integer, ranges: Range4[] }?
---@param opts { row: integer, col: integer, label: string, hi?: string, buf: integer, ctx: Range4[] }
---@return integer[]
local function mark_treesitter_context(ctx, opts)
	if not ctx then
		return {}
	end
	local marks = {}
	for i, v in ipairs(ctx.ranges) do
		if v[1] == opts.row then
			table.insert(marks, mark_label(ctx.buf, vim.tbl_extend("force", opts, { row = i - 1 })))
		end
	end
	return marks
end

---@return { buf: integer, ranges: Range4[] }?
local function get_treesitter_context()
	for _, w in pairs(vim.api.nvim_tabpage_list_wins(0)) do
		if vim.w[w].treesitter_context then
			return {
				buf = vim.api.nvim_win_get_buf(w),
				ranges = require("treesitter-context.context").get(vim.api.nvim_get_current_win()),
			}
		end
	end
end

---@param nodes TSNode
---@return integer, integer
local function iterate(nodes, include_root)
	local N = #nodes

	local start = 1
	if N > 1 then
		local range1 = { range(nodes[1]) }
		if range1[1] == range1[3] and range1[2] == range1[4] then
			start = 2
		end
	end

	local nodeN = nodes[N]
	local end_ = (not include_root and nodeN:equal(nodeN:tree():root())) and (N - 1) or N

	return start, end_ > start and end_ or start
end

---@param nodes TSNode[]
---@param opts TreemonkeyOpts
---@return TreemonkeyItem?
local function choose_node(nodes, opts)
	if #nodes == 0 then
		return
	end

	--[[ prep ]]
	local labelled = {} ---@type table<string, TreemonkeyItem>
	local positions = {} ---@type table<integer, table<integer, TreemonkeyItem[]>>
	local context = opts.experimental.treesitter_context and get_treesitter_context() or nil

	--[[ first choice ]]
	local cnt, psrow, pscol, perow, pecol = 1, -1, -1, -1, -1
	local start, end_ = iterate(nodes, opts.include_root)
	mark_node(nodes[end_], opts.highlight.backdrop)
	for idx = start, end_, 1 do
		-- stop labelling if no more labels are available
		if cnt > #opts.labels then
			break
		end

		-- let node be a choice if the range differs from the range of the previously marked node
		local node = nodes[idx]
		local label = opts.labels[cnt]
		local srow, scol, erow, ecol = range(node)
		if (psrow ~= srow or pscol ~= scol or perow ~= erow or pecol ~= ecol) and (srow ~= erow or scol ~= ecol) then
			for _, v in pairs({
				{ row = srow, col = scol, label = label, hi = opts.highlight.label },
				{ row = erow, col = ecol, label = label:upper(), hi = opts.highlight.label },
			}) do
				local item = { row = v.row, col = v.col, node = node, label = v.label }

				labelled[v.label] = item

				if not positions[v.row] then
					positions[v.row] = {}
				end
				if not positions[v.row][v.col] then
					positions[v.row][v.col] = {}
				end
				table.insert(positions[v.row][v.col], item)

				if #positions[v.row][v.col] == 1 then
					mark_label(0, v)
					mark_treesitter_context(context, v)
				end
			end

			-- update state
			cnt, psrow, pscol, perow, pecol = cnt + 1, srow, scol, erow, ecol
		end
	end

	vim.cmd.redraw()
	local first_label = getcharstr()
	if not first_label then
		return
	end

	local first_choice = labelled[first_label]

	if not first_choice then
		return
	end

	local ambiguity = positions[first_choice.row][first_choice.col]
	if
		opts.steps == 1 -- user wants to explicitly stop at here
		or first_label:lower() == first_label:upper() -- choice is made by a label without upper case (e.g, 1, !, ...)
		or (opts.steps == nil and #ambiguity == 1) -- second step is not required
	then
		return first_choice
	end

	--[[ second choice ]]
	vim.api.nvim_buf_clear_namespace(0, M.namespace, 0, -1)
	if context then
		vim.api.nvim_buf_clear_namespace(context.buf, M.namespace, 0, -1)
	end

	-- highlight backdrop and first choice
	mark_node(ambiguity[#ambiguity].node, opts.highlight.backdrop)
	mark_node(first_choice.node, opts.highlight.first_selected_node)
	local opts_first_label = vim.tbl_extend("force", first_choice, { hi = opts.highlight.first_selected_label })
	mark_label(0, opts_first_label)
	mark_treesitter_context(context, opts_first_label)

	-- prepare labels for the second choice
	for _, v in pairs(ambiguity) do
		local srow, scol, erow, ecol = range(v.node)
		local o = { row = srow, col = scol, label = v.label:lower(), hi = opts.highlight.label }
		if srow == first_choice.row and scol == first_choice.col then
			o = { row = erow, col = ecol, label = v.label:upper(), hi = opts.highlight.label }
		end
		mark_label(0, o)
		mark_treesitter_context(context, o)
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
	local o = vim.tbl_deep_extend("keep", opts or {}, {
		highlight = { label = "@text.warning", first_selected_label = "@text.danger" },
		labels = labels_default,
		experimental = {},
	})

	if o.highlight.first_node then
		vim.deprecate(
			"TreemonkeyOpts.highlight.first_node",
			"TreemonkeyOpts.highlight.first_selected_node",
			"0.1",
			"treemonkey"
		)
		if not o.highlight.first_selected_node then
			o.highlight.first_selected_node = o.highlight.first_node
		end
	end

	if o.steps ~= nil and o.steps ~= 1 and o.steps ~= 2 then
		error("TreemonkeyOpts.steps should be one of nil, 1 or 2")
	end

	return o
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
