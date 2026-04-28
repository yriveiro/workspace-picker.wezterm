local wezterm = require("wezterm") ---@type Wezterm

local M = {}

---@param text string
---@return string
local function decode_percent_encoded(text)
	return text:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end)
end

---@param cwd string|Url|nil
---@return string|nil
function M.cwd_to_path(cwd)
	if type(cwd) == "table" then
		if type(cwd.scheme) == "string" and cwd.scheme ~= "" and cwd.scheme ~= "file" then
			return nil
		end

		if type(cwd.file_path) == "string" and cwd.file_path ~= "" then
			return cwd.file_path
		end

		return nil
	end

	if type(cwd) ~= "string" or cwd == "" then
		return nil
	end

	if not cwd:match("^file://") then
		if cwd:match("^[%w+.-]+://") then
			return nil
		end

		return cwd
	end

	local path = cwd:match("^file://[^/]*(/.*)$")
	if not path or path == "" then
		return nil
	end

	path = decode_percent_encoded(path)

	if wezterm.target_triple:find("windows") then
		path = path:gsub("^/([A-Za-z]:[/\\])", "%1"):gsub("/", "\\")
	end

	return path
end

---@param pane Pane|nil
---@return string|nil
local function get_pane_path(pane)
	if not pane then
		return nil
	end

	local ok, cwd = pcall(function()
		return pane:get_current_working_dir()
	end)
	if not ok then
		return nil
	end

	return M.cwd_to_path(cwd)
end

---@param mux_window MuxWindow
---@return Pane|nil
local function get_active_pane_for_mux_window(mux_window)
	local ok, pane = pcall(function()
		return mux_window:active_pane()
	end)
	if ok and pane then
		return pane
	end

	local ok_tabs, tabs_with_info = pcall(function()
		return mux_window:tabs_with_info()
	end)
	if not ok_tabs or type(tabs_with_info) ~= "table" then
		return nil
	end

	for _, tab_info in ipairs(tabs_with_info) do
		if tab_info.is_active and tab_info.tab then
			local ok_panes, panes_with_info = pcall(function()
				return tab_info.tab:panes_with_info()
			end)
			if ok_panes and type(panes_with_info) == "table" then
				for _, pane_info in ipairs(panes_with_info) do
					if pane_info.is_active then
						return pane_info.pane
					end
				end
			end
		end
	end

	return nil
end

---@param workspace_name string
---@param preferred_pane Pane|nil
---@return string|nil
function M.get_workspace_path(workspace_name, preferred_pane)
	local preferred_path = get_pane_path(preferred_pane)
	if preferred_path then
		return preferred_path
	end

	for _, mux_window in ipairs(wezterm.mux.all_windows() or {}) do
		local ok, window_workspace_name = pcall(function()
			return mux_window:get_workspace()
		end)
		if ok and window_workspace_name == workspace_name then
			local path = get_pane_path(get_active_pane_for_mux_window(mux_window))
			if path then
				return path
			end
		end
	end

	return nil
end

return M
