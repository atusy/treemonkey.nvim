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

--- Build a |TreemonkeyNode| from a 0-indexed, end-exclusive byte range.
---@param srow integer
---@param scol integer
---@param erow integer
---@param ecol integer
---@param is_root boolean
---@return TreemonkeyNode
function M.make_node(srow, scol, erow, ecol, is_root)
	return {
		is_root = is_root,
		---@return integer, integer, integer, integer
		range = function()
			return srow, scol, erow, ecol
		end,
	}
end

return M
