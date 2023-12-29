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

return M
