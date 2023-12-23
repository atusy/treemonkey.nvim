local ns = vim.api.nvim_create_namespace("treemonkey")

-- stylua: ignore
local labels = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"}

---@param row integer
---@param col integer
---@param txt string
---@param hi? string
local function mark_label(row, col, txt, hi)
	vim.api.nvim_buf_set_extmark(0, ns, row, col, {
		virt_text = { { txt, hi or "@text.warning" } },
		virt_text_pos = "overlay",
	})
end

---@param node TSNode
---@param hi? string
local function mark_selection(node, hi)
	local srow, scol, erow, ecol = node:range()
	vim.api.nvim_buf_set_extmark(0, ns, srow, scol, {
		end_row = erow,
		end_col = ecol,
		hl_group = hi or "Visual",
	})
end

---@param ignore_injections boolean
---@return TSNode[]
local function find_nodes(ignore_injections)
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

---@param nodes TSNode[]
---@return TSNode?
local function choose_node(nodes)
	---@type table<string, { [1]: integer, [2]: integer, [3]: TSNode }>
	local labelled = {}
	---@type table<integer, table<integer, {node: TSNode, label: string}[]>>
	local positions = {}

	local psrow, pscol, perow, pecol ---@type integer?, integer?, integer?, integer?
	for cnt, node in ipairs(nodes) do
		-- stop labelling if no more labels are available
		if not labels[cnt] then
			break
		end

		-- let node be a choice if the range differs from the range of the previously marked node
		local srow, scol, erow, ecol = node:range()
		if psrow ~= srow or pscol ~= scol or perow ~= erow or pecol ~= ecol then
			psrow, pscol, perow, pecol = srow, scol, erow, ecol
			for _, v in pairs({ { srow, scol, labels[cnt] }, { erow, ecol - 1, labels[cnt]:upper() } }) do
				local row, col, label = v[1], v[2], v[3]
				labelled[label] = { row, col, node }
				if not positions[row] then
					positions[row] = {}
				end

				--
				if positions[row][col] then
					table.insert(positions[row][col], { node = node, label = label })
				else
					positions[row][col] = { { node = node, label = label } }
					mark_label(row, col, label)
				end
			end
		end
	end

	vim.cmd.redraw()
	local first_label = vim.fn.getcharstr()

	local first_choice = labelled[first_label]

	if not first_choice then
		return
	end

	local ambiguity = positions[first_choice[1]][first_choice[2]]
	if #ambiguity == 1 then
		return ambiguity[1].node
	end

	vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
	mark_selection(first_choice[3])
	for _, v in pairs(ambiguity) do
		local srow, scol, erow, ecol = v.node:range()
		mark_label(srow, scol, v.label)
		mark_label(erow, ecol - 1, v.label:upper())
	end
	vim.cmd.redraw()

	local second_label = vim.fn.getcharstr()
	for _, v in pairs(ambiguity) do
		if v.label:lower() == second_label:lower() then
			return v.node
		end
	end
end

local function select(opts)
	opts = opts or {}
	local ok, result = pcall(choose_node, find_nodes(opts.ignore_injections))
	vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
	vim.cmd.redraw()
	if ok then
		if result then
			require("nvim-treesitter.ts_utils").update_selection(0, result)
		end
	else
		---@diagnostic disable-next-line: param-type-mismatch
		vim.notify(result, vim.log.levels.ERROR)
	end
end

return {
	select = select,
}
