local M = {} ---@type table<string, TreemonkeyAction>

local function set_mode()
	local mode = vim.api.nvim_get_mode().mode
	if mode == "n" then
		vim.cmd("normal! v")
		return "v"
	end
	if mode:sub(1, 2) == "no" then
		if mode == "no" then
			mode = "nov"
		end
		vim.cmd("normal!" .. mode:sub(3))
		return mode
	end
	for _, expected in pairs({ "v", "V", "" }) do
		if mode == expected then
			return mode
		end
	end
	error("Invalid mode for TreemonkeyAction: " .. mode)
end

local function range(node)
	local srow, scol, erow, ecol = node:range()
	if ecol == 0 and erow > srow then
		erow = erow - 1
		ecol = string.len(vim.api.nvim_buf_get_lines(0, erow, erow + 1, true)[1])
	end
	return srow, scol, erow, ecol == 0 and 0 or (ecol - 1)
end

---@type TreemonkeyAction
local function _update_selection(item)
	set_mode()
	local srow, scol, erow, ecol = range(item.node)
	vim.api.nvim_win_set_cursor(0, { srow + 1, scol })
	vim.cmd("normal! o")
	vim.api.nvim_win_set_cursor(0, { erow + 1, ecol })
end

---@type TreemonkeyAction
function M.update_selection(item)
	set_mode()
	_update_selection(item)
end

---@type TreemonkeyAction
function M.unite_selection(item)
	set_mode()
	local o1 = vim.api.nvim_win_get_cursor(0)
	vim.cmd("normal! o")
	local o2 = vim.api.nvim_win_get_cursor(0)
	vim.cmd("normal! o")
	if o1[1] == o2[1] and o1[2] == o2[2] then
		return M.update_selection(item)
	end

	local on = "start"
	local vtop, vbot = o1, o2
	if o1[1] > o2[1] or ((o1[1] == o2[1]) and (o1[2] < o2[2])) then
		on = "end"
		vtop, vbot = o2, o1
	end

	local vsrow, vscol, verow, vecol = vtop[1] - 1, vtop[2], vbot[1] - 1, vbot[2]
	local nsrow, nscol, nerow, necol = range(item.node)

	if nsrow < vsrow or (nsrow == vsrow and nscol < vscol) then
		if nerow > verow or (nerow == verow and necol > vecol) then
			return _update_selection(item)
		end
		if on == "end" then
			vim.cmd("normal! o")
		end
		vim.api.nvim_win_set_cursor(0, { nsrow + 1, nscol })
		return
	elseif nerow > verow or (nerow == verow and necol > necol) then
		if on == "start" then
			vim.cmd("normal! o")
		end
		vim.api.nvim_win_set_cursor(0, { nerow + 1, necol })
		return
	end
end

---@type TreemonkeyAction
function M.jump(item)
	vim.api.nvim_win_set_cursor(0, { item.row + 1, item.col })
end

return M
