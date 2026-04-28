local wezterm = require("wezterm") ---@type Wezterm

local Utils = require("utils")

local M = {}

---@type WorkspacePickerResolvedConfig
local default_config = {
	-- Path to zoxide command
	zoxide_path = "/opt/homebrew/bin/zoxide",
	-- Restore saved workspaces automatically when WezTerm starts
	restore_on_gui_startup = true,
	-- Color settings
	colors = {
		workspace_prefix = "#9ece6a", -- Green
		zoxide_prefix = "#f7768e", -- Red
		current_indicator = "#9ece6a", -- Green
		text = "#c8d0e0", -- Light gray
		path = "#565f89", -- Dark gray
	},
	-- Label settings
	labels = {
		workspace = "[Workspace]",
		zoxide = "[Zoxide]",
		current = "<- current",
	},
	-- Keybind to open the workspace picker (set to false to disable)
	activate_keytable = { mods = "LEADER", key = "w" },
}

---@type WorkspacePickerResolvedConfig|nil
local user_config
local gui_startup_restore_registered = false

---@param handler fun(cmd?: SpawnCommand)
local function register_gui_startup(handler)
	if gui_startup_restore_registered then
		return
	end

	gui_startup_restore_registered = true
	wezterm.on("gui-startup", handler)
end

---@param opts? WorkspacePickerConfig
---@return WorkspacePickerResolvedConfig
function M.merge(opts)
	local merged = Utils.table_merge({}, default_config)
	return Utils.table_merge(merged, opts or {})
end

---@return WorkspacePickerResolvedConfig
function M.get()
	return user_config or default_config
end

---@param handler fun(cmd?: SpawnCommand)
---@param opts? WorkspacePickerConfig
---@return WorkspacePickerResolvedConfig
function M.setup(handler, opts)
	user_config = M.merge(opts)

	if user_config.restore_on_gui_startup then
		register_gui_startup(handler)
	end

	return user_config
end

---@param handler fun(cmd?: SpawnCommand)
---@param opts? WorkspacePickerConfig
---@return WorkspacePickerResolvedConfig
function M.apply(handler, opts)
	if opts then
		return M.setup(handler, opts)
	end

	local config = M.get()
	if config.restore_on_gui_startup then
		register_gui_startup(handler)
	end

	return config
end

---@param opts? WorkspacePickerConfig
---@return WorkspacePickerResolvedConfig
function M.resolve(opts)
	if opts then
		return M.merge(opts)
	end

	return M.get()
end

---@param handler fun(cmd?: SpawnCommand)
---@param cfg WorkspacePickerResolvedConfig
function M.register_gui_startup_if_needed(handler, cfg)
	if cfg.restore_on_gui_startup then
		register_gui_startup(handler)
	end
end

return M
