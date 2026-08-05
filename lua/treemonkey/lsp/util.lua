local M = {}

--- Convert an LSP character offset (in the client's `offset_encoding`) into a
--- 0-indexed byte column, so the range becomes compatible with |TSNode:range()|.
---@param row integer 0-indexed line
---@param character integer LSP character offset on the line
---@param encoding "utf-8"|"utf-16"|"utf-32"
---@return integer byte column (0-indexed)
function M.to_byte(row, character, encoding)
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

--- Pull a 0-indexed (row, byte column) position back onto real text.
---
--- A language server may answer with positions beyond the end of the buffer,
--- typically because it still holds a stale copy of the document. Such
--- positions are not addressable by |nvim_buf_set_extmark()| nor by the range
--- handling in `treemonkey.core`, hence the clamp on the way in.
---@param row integer 0-indexed line
---@param col integer 0-indexed byte column
---@return integer, integer
local function clamp(row, col)
	if row < 0 then
		row, col = 0, 0
	else
		local last = vim.api.nvim_buf_line_count(0) - 1
		if row > last then
			-- The line is gone, so the column it referred to is meaningless.
			row, col = last, math.huge
		end
	end
	local len = #(vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or "")
	return row, math.max(0, math.min(col, len))
end

--- Build a |TreemonkeyLspNode| from a 0-indexed, end-exclusive byte range.
---@param srow integer
---@param scol integer
---@param erow integer
---@param ecol integer
---@param is_root boolean
---@return TreemonkeyLspNode
function M.make_node(srow, scol, erow, ecol, is_root)
	srow, scol = clamp(srow, scol)
	erow, ecol = clamp(erow, ecol)
	return {
		is_root = is_root,
		---@return integer, integer, integer, integer
		range = function()
			return srow, scol, erow, ecol
		end,
	}
end

return M
