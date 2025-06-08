local M = {} ---@type table<string, TreemonkeyFilter>

function M.linewise(nodes)
	local idx = {} ---@type table<number, table<number, {scol: number, idx: number}>>
	local res = {} ---@type TSNode[]
	for _, n in pairs(nodes) do
		local srow, scol, erow, ecol = n:range()
		if erow > (srow + (ecol == 0 and 1 or 0)) then
			if not idx[srow] then
				table.insert(res, n)
				idx[srow] = {}
				idx[srow][erow] = { scol = scol, idx = #res }
			elseif not idx[srow][erow] then
				table.insert(res, n)
				idx[srow][erow] = { scol = scol, idx = #res }
			elseif scol < idx[srow][erow].scol then
				res[idx[srow][erow].idx] = n
				idx[srow][erow].scol = scol
			end
		end
	end
	return res
end

return M
