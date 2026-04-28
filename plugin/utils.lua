local pairs = pairs
local type = type

local M = {}

---@param dest table
---@param src table
---@return table
function M.table_merge(dest, src)
	local function merge(left, right, depth)
		if depth > 100 then
			return left
		end

		for key, value in pairs(right) do
			if type(value) == "table" then
				left[key] = type(left[key]) == "table" and left[key] or {}
				merge(left[key], value, depth + 1)
			else
				left[key] = value
			end
		end

		return left
	end

	return merge(dest, src, 0)
end

---@param text string
---@return string
function M.escape_lua_pattern(text)
	return text:gsub("(%W)", "%%%1")
end

return M
