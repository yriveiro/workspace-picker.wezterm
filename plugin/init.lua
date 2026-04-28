---@class WorkspacePickerColors
---@field workspace_prefix string
---@field zoxide_prefix string
---@field current_indicator string
---@field text string
---@field path string

---@class WorkspacePickerKeybind
---@field mods string
---@field key string

---@class WorkspacePickerConfig
---@field zoxide_path string
---@field colors WorkspacePickerColors
---@field labels WorkspacePickerLabels
---@field activate_keytable WorkspacePickerKeybind?

local wezterm = require("wezterm")
local act = wezterm.action
local json_state = require("json")

local M = {}

local selector_alphabet = "q1234567890abcdefghilmnoprstuvwxyz"

local function escape_lua_pattern(text)
	return text:gsub("(%W)", "%%%1")
end

wezterm.on("workspace-picker-open", function(win, pane)
	M.show_workspace_selector(win, pane)
end)

-- Get the data directory path following XDG spec
---@return string
local function get_data_dir()
	local xdg_data = os.getenv("XDG_DATA_HOME")
	if xdg_data and xdg_data ~= "" then
		return xdg_data .. "/workspace-picker"
	end

	return wezterm.home_dir .. "/.local/share/workspace-picker"
end

---@param workspace_name string
---@return string
local function workspace_state_path(workspace_name)
	return get_data_dir() .. "/" .. workspace_name .. ".json"
end

-- Ensure data directory exists
---@return boolean
local function ensure_data_dir()
	local data_dir = get_data_dir()
	if data_dir == "" then
		return false
	end

	if wezterm.target_triple:find("windows") then
		local command = string.format(
			"New-Item -ItemType Directory -Force -LiteralPath '%s' | Out-Null",
			data_dir:gsub("'", "''")
		)
		local ok = wezterm.run_child_process({ "powershell.exe", "-NoProfile", "-Command", command })
		return ok
	end

	local ok = wezterm.run_child_process({ "mkdir", "-p", data_dir })
	return ok
end

-- Save workspace state to file
---@param workspace_name string
---@param state table|nil
---@return boolean
local function save_workspace_state(workspace_name, state)
	if not ensure_data_dir() then
		return false
	end

	local file_path = workspace_state_path(workspace_name)

	local file = io.open(file_path, "w")
	if not file then
		return false
	end

	local ok, json_str = pcall(json_state.encode, state or {})
	if not ok then
		file:close()
		return false
	end

	file:write(json_str)
	file:close()
	return true
end

-- Load workspace state from file
---@param workspace_name string
---@return table|nil
local function load_workspace_state(workspace_name)
	local file_path = workspace_state_path(workspace_name)
	local file = io.open(file_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	if content == "" then
		return nil
	end

	local ok, state = pcall(json_state.decode, content)
	if not ok then
		return nil
	end

	return state
end

-- Delete workspace state file
---@param workspace_name string
---@return boolean
local function delete_workspace_state(workspace_name)
	local file_path = workspace_state_path(workspace_name)
	local ok, err = os.remove(file_path)
	if ok then
		return true
	end

	if type(err) == "string" then
		local lowered = err:lower()
		if lowered:find("no such file", 1, true) or lowered:find("cannot find", 1, true) then
			return true
		end
	end

	return false
end

-- Get list of saved workspaces
---@return string[]
local function get_saved_workspaces()
	local data_dir = get_data_dir()
	if data_dir == "" then
		return {}
	end

	local workspaces = {}
	for _, file in ipairs(wezterm.glob(data_dir .. "/*.json", data_dir) or {}) do
		local ws_name = file:gsub("%.json$", "")
		if ws_name then
			table.insert(workspaces, ws_name)
		end
	end

	return workspaces
end

-- Show a user-facing notification
---@param window any
---@param title string
---@param body string
local function notify(window, title, body)
	window:toast_notification(title, body)
end

local function close_picker(window, pane)
	window:perform_action(act.PopKeyTable, pane)
end

local function make_quit_choice()
	return {
		id = "quit",
		label = "q  Close picker",
	}
end

local function show_input_selector(window, pane, opts)
	window:perform_action(
		act.InputSelector({
			action = wezterm.action_callback(opts.on_select),
			title = opts.title,
			choices = opts.choices,
			alphabet = selector_alphabet,
			description = opts.description,
			fuzzy_description = opts.fuzzy_description,
		}),
		pane
	)
end

-- Default configuration
---@type WorkspacePickerConfig
local default_config = {
	-- Path to zoxide command
	zoxide_path = "/opt/homebrew/bin/zoxide",
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
	-- Keybind to activate workspace keytable (set to false to disable)
	activate_keytable = { mods = "LEADER", key = "w" },
}

-- Store user configuration
---@type WorkspacePickerConfig|nil
local user_config

-- Merge configuration
---@param user_opts WorkspacePickerConfig|nil
---@return WorkspacePickerConfig
local function merge_config(user_opts)
	---@type WorkspacePickerConfig
	local config = {}
	for k, v in pairs(default_config) do
		if type(v) == "table" then
			config[k] = {}
			for tk, tv in pairs(v) do
				config[k][tk] = tv
			end
			if user_opts and user_opts[k] then
				for tk, tv in pairs(user_opts[k]) do
					config[k][tk] = tv
				end
			end
		else
			config[k] = v
		end
	end
	if user_opts then
		for k, v in pairs(user_opts) do
			if type(v) == "table" then
				for tk, tv in pairs(v) do
					config[k][tk] = tv
				end
			else
				config[k] = v
			end
		end
	end
	return config
end

-- Initialize configuration
---@param opts WorkspacePickerConfig|nil
---@return table
function M.setup(opts)
	user_config = merge_config(opts)
	return M
end

-- Get directory list from zoxide
---@return string[]
local function get_zoxide_directories()
	local config = user_config or default_config
	local success, stdout, stderr = wezterm.run_child_process({ config.zoxide_path, "query", "-l" })
	if not success then
		wezterm.log_warn("workspace-picker: Failed to execute zoxide command")
		if stderr and stderr ~= "" then
			wezterm.log_warn(stderr)
		end
		return {}
	end

	local directories = {}
	for d in stdout:gmatch("[^\r\n]+") do
		-- Replace home directory with ~
		local home = wezterm.home_dir
		local normalized_d = d
		if home and home ~= "" then
			normalized_d = d:gsub("^" .. escape_lua_pattern(home), "~")
		end
		table.insert(directories, normalized_d)
	end

	return directories
end

-- Display workspace selector
---@param window any -- wezterm.Window
---@param pane any   -- wezterm.Pane
---@return nil
function M.show_workspace_selector(window, pane)
	local config = user_config or default_config
	local colors = config.colors
	local labels = config.labels
	local current = wezterm.mux.get_active_workspace()

	---@class WorkspacePickerChoice
	---@field id string
	---@field label string

	---@type WorkspacePickerChoice[]
	local choices = {}
	table.insert(choices, make_quit_choice())

	-- Add existing workspace list
	for _, name in ipairs(wezterm.mux.get_workspace_names()) do
		local label
		if current == name then
			label = wezterm.format({
				{ Foreground = { Color = colors.workspace_prefix } },
				{ Text = labels.workspace },
				{ Foreground = { Color = colors.text } },
				{ Text = string.format(" %-30s ", name) },
				{ Foreground = { Color = colors.current_indicator } },
				{ Text = labels.current },
			})
		else
			label = wezterm.format({
				{ Foreground = { Color = colors.workspace_prefix } },
				{ Text = labels.workspace },
				{ Foreground = { Color = colors.text } },
				{ Text = string.format(" %s ", name) },
			})
		end

		if name == "default" then
			-- Display default workspace at the top
			table.insert(choices, 1, {
				id = "ws:" .. name,
				label = label,
			})
		else
			table.insert(choices, {
				id = "ws:" .. name,
				label = label,
			})
		end
	end

	-- Get and add zoxide directory list
	local zoxide_dirs = get_zoxide_directories()
	if #zoxide_dirs > 0 then
		-- Add separator (only if zoxide directories exist)
		table.insert(choices, {
			id = "separator",
			label = "─────────────────────────────────────────────────────────",
		})

		for _, dir in ipairs(zoxide_dirs) do
			-- Get directory name (last path element)
			local dir_name = dir:match("([^/]+)$")
			local label = wezterm.format({
				{ Foreground = { Color = colors.zoxide_prefix } },
				{ Text = labels.zoxide },
				{ Foreground = { Color = colors.text } },
				{ Text = " " .. dir_name .. " " },
				{ Foreground = { Color = colors.path } },
				{ Text = "(" .. dir .. ")" },
			})
			table.insert(choices, {
				id = "zoxide:" .. dir,
				label = label,
			})
		end
	end

	show_input_selector(window, pane, {
		title = "(wezterm) Select workspace",
		choices = choices,
		description = "(wezterm) Select workspace or directory: ['/': search]",
		fuzzy_description = "(wezterm) Select workspace or directory: ",
		on_select = function(win, p, id)
			if not id then
				close_picker(win, p)
				return
			end

			if id == "quit" then
				close_picker(win, p)
				return
			end

			if id == "separator" then
				wezterm.log_info("Selection canceled or separator clicked")
				return
			end

			if id:match("^ws:") then
				local workspace_name = id:gsub("^ws:", "")
				close_picker(win, p)
				win:perform_action(act.SwitchToWorkspace({ name = workspace_name }), p)
			elseif id:match("^zoxide:") then
				local dir = id:gsub("^zoxide:", "")
				local home = wezterm.home_dir
				if home and home ~= "" then
					dir = dir:gsub("^~", home)
				end

				local workspace_name = dir:match("([^/]+)$")
				close_picker(win, p)
				win:perform_action(
					act.SwitchToWorkspace({
						name = workspace_name,
						spawn = {
							cwd = dir,
						},
					}),
					p
				)
			end
		end,
	})
end

-- Rename workspace
---@return any -- wezterm.Action
function M.rename_workspace()
	return act.PromptInputLine({
		description = "(wezterm) Rename workspace title: ",
		action = wezterm.action_callback(function(win, pane, line)
			if line then
				wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
			end
		end),
	})
end

-- Create new workspace manually
---@return any -- wezterm.Action
function M.create_workspace_manually()
	return act.PromptInputLine({
		description = "(wezterm) Create new workspace: ",
		action = wezterm.action_callback(function(window, pane, line)
			if line then
				window:perform_action(
					act.SwitchToWorkspace({
						name = line,
					}),
					pane
				)
			end
		end),
	})
end

-- Save current workspace state
---@return any -- wezterm.Action
function M.save_workspace()
	return act.PromptInputLine({
		description = "(wezterm) Save workspace as: ",
		action = wezterm.action_callback(function(win, pane, line)
			if line then
				local state = {
					name = wezterm.mux.get_active_workspace(),
					timestamp = os.time(),
				}
				local ok = save_workspace_state(line, state)
				if ok then
					wezterm.log_info("workspace-picker: Saved workspace as '" .. line .. "'")
					notify(win, "Workspace Saved", "Saved workspace as '" .. line .. "'.")
				else
					wezterm.log_warn("workspace-picker: Failed to save workspace '" .. line .. "'")
					notify(win, "Workspace Save Failed", "Failed to save workspace as '" .. line .. "'.")
				end
			end
		end),
	})
end

-- Save all current workspaces
---@return any -- wezterm.Action
function M.save_all_workspaces()
	return wezterm.action_callback(function(win, pane)
		local workspace_names = wezterm.mux.get_workspace_names()
		table.sort(workspace_names)

		local saved = 0
		local failed = {}
		local timestamp = os.time()

		for _, workspace_name in ipairs(workspace_names) do
			local state = {
				name = workspace_name,
				timestamp = timestamp,
			}

			if save_workspace_state(workspace_name, state) then
				saved = saved + 1
			else
				table.insert(failed, workspace_name)
			end
		end

		if #failed == 0 then
			wezterm.log_info("workspace-picker: Saved " .. saved .. " workspaces")
			notify(win, "Workspaces Saved", "Saved " .. saved .. " workspaces successfully.")
		else
			wezterm.log_warn(
				"workspace-picker: Saved " .. saved .. " workspaces, failed for: " .. table.concat(failed, ", ")
			)
			notify(win, "Workspace Save Completed With Errors", "Saved " .. saved .. " workspaces, failed for: " .. table.concat(failed, ", "))
		end

		close_picker(win, pane)
	end)
end

-- Restore all saved workspaces
---@return any -- wezterm.Action
function M.restore_all_workspaces()
	return wezterm.action_callback(function(win, pane)
		local saved = get_saved_workspaces()
		if #saved == 0 then
			close_picker(win, pane)
			notify(win, "No Saved Workspaces", "No saved workspaces found. Open the picker, then press s.")
			return
		end

		local existing = {}
		for _, workspace_name in ipairs(wezterm.mux.get_workspace_names()) do
			existing[workspace_name] = true
		end

		table.sort(saved)

		local restored = 0
		local skipped = 0
		local failed = {}

		for _, workspace_name in ipairs(saved) do
			if existing[workspace_name] then
				skipped = skipped + 1
			else
				local ok = pcall(wezterm.mux.spawn_window, { workspace = workspace_name })
				if ok then
					restored = restored + 1
				else
					table.insert(failed, workspace_name)
				end
			end
		end

		close_picker(win, pane)

		if #failed == 0 then
			wezterm.log_info(
				"workspace-picker: Restored " .. restored .. " workspaces" .. (skipped > 0 and " (" .. skipped .. " already existed)" or "")
			)
			notify(win, "Workspaces Restored", "Restored " .. restored .. " workspaces" .. (skipped > 0 and " (" .. skipped .. " already existed)" or "") .. ".")
		else
			wezterm.log_warn(
				"workspace-picker: Restored "
					.. restored
					.. " workspaces, failed for: "
					.. table.concat(failed, ", ")
			)
			notify(win, "Workspace Restore Completed With Errors", "Restored " .. restored .. " workspaces, failed for: " .. table.concat(failed, ", "))
		end
	end)
end

-- Show restore workspace menu
---@param window any -- wezterm.Window
---@param pane any   -- wezterm.Pane
---@return nil
function M.show_restore_menu(window, pane)
	local saved = get_saved_workspaces()
	table.sort(saved)

	if #saved == 0 then
		notify(window, "No Saved Workspaces", "No saved workspaces found. Open the picker, then press s.")
		return
	end

	---@class WorkspacePickerRestoreChoice
	---@field id string
	---@field label string

	---@type WorkspacePickerRestoreChoice[]
	local choices = {}
	table.insert(choices, make_quit_choice())

	for _, name in ipairs(saved) do
		local state = load_workspace_state(name)
		local timestamp = state and state.timestamp or 0
		local date = os.date("%Y-%m-%d %H:%M", timestamp)

		local label = wezterm.format({
			{ Text = string.format(" %s ", name) },
			{ Foreground = { Color = "#565f89" } },
			{ Text = "(" .. date .. ")" },
		})

		table.insert(choices, {
			id = "restore:" .. name,
			label = label,
		})
	end

	show_input_selector(window, pane, {
		title = "(wezterm) Restore workspace",
		choices = choices,
		description = "(wezterm) Restore a saved workspace: ",
		fuzzy_description = "(wezterm) Restore workspace: ",
		on_select = function(win, p, id)
			if not id or id == "quit" then
				close_picker(win, p)
				return
			end

			local workspace_name = id:gsub("^restore:", "")
			local state = load_workspace_state(workspace_name)

			if state then
				close_picker(win, p)
				win:perform_action(
					act.SwitchToWorkspace({
						name = workspace_name,
					}),
					p
				)
				wezterm.log_info("workspace-picker: Restored workspace '" .. workspace_name .. "'")
				notify(win, "Workspace Restored", "Restored workspace '" .. workspace_name .. "'.")
			else
				wezterm.log_warn("workspace-picker: Failed to load workspace state for '" .. workspace_name .. "'")
				notify(win, "Workspace Restore Failed", "Failed to load workspace state for '" .. workspace_name .. "'.")
			end
		end,
	})
end

-- Add keybindings to config
---@param config table
---@param opts WorkspacePickerConfig|nil
---@return table
function M.apply_to_config(config, opts)
	-- Merge config (use opts if provided)
	local cfg = opts and merge_config(opts) or (user_config or default_config)

	-- Use existing keys table if available, otherwise create new one
	if not config.keys then
		config.keys = {}
	end

	-- Define the workspace keytable
	config.key_tables = config.key_tables or {}
	config.key_tables["workspace_picker"] = {
		-- Show workspace selector
		{ key = "w", action = wezterm.action_callback(function(win, pane)
			M.show_workspace_selector(win, pane)
		end) },

		-- Create workspace
		{ key = "c", action = M.create_workspace_manually() },

		-- Rename workspace
		{ key = "e", action = M.rename_workspace() },

		-- Save all workspaces
		{ key = "s", action = M.save_all_workspaces() },

		-- Restore all workspaces
		{ key = "r", action = M.restore_all_workspaces() },

		-- Quit keytable
		{ key = "Escape", action = act.PopKeyTable },
	}

	-- Activate keytable
	if cfg.activate_keytable then
		table.insert(config.keys, {
			mods = cfg.activate_keytable.mods,
			key = cfg.activate_keytable.key,
			action = act.Multiple {
				act.ActivateKeyTable({
					name = "workspace_picker",
					one_shot = false,
				}),
				act.EmitEvent("workspace-picker-open"),
			},
		})
	end

	return config
end

-- Get data directory (for external use)
function M.get_data_dir()
	return get_data_dir()
end

return M
