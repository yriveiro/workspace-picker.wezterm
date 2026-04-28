local wezterm = require("wezterm") ---@type Wezterm
local act = wezterm.action

require("types")

local Utils = require("utils")
local Config = require("workspace_picker.config")
local Cwd = require("workspace_picker.cwd")
local State = require("workspace_picker.state")
local UI = require("workspace_picker.ui")

---@type WorkspacePicker
local M = {}

---@return string[]
local function get_zoxide_directories()
	local config = Config.get()
	local success, stdout, stderr = wezterm.run_child_process({ config.zoxide_path, "query", "-l" })
	if not success then
		wezterm.log_warn("workspace-picker: Failed to execute zoxide command")
		if stderr and stderr ~= "" then
			wezterm.log_warn(stderr)
		end
		return {}
	end

	local directories = {}
	for directory in stdout:gmatch("[^\r\n]+") do
		local home = wezterm.home_dir
		local normalized_directory = directory
		if home and home ~= "" then
			normalized_directory = directory:gsub("^" .. Utils.escape_lua_pattern(home), "~")
		end
		table.insert(directories, normalized_directory)
	end

	return directories
end

---@param cmd? SpawnCommand
function M.restore_workspaces_on_gui_startup(cmd)
	local state = State.get_global_state()
	if state.restore_attempted_on_gui_startup then
		return
	end

	state.restore_attempted_on_gui_startup = true

	local result = State.restore_saved_workspaces({ cmd = cmd })
	if result.found == 0 then
		wezterm.log_info("workspace-picker: No saved workspaces found for startup restore")
		return
	end

	if #result.failed == 0 then
		wezterm.log_info(
			"workspace-picker: Startup restore created "
				.. result.restored
				.. " workspaces"
				.. (result.skipped > 0 and " (" .. result.skipped .. " already existed)" or "")
		)
		return
	end

	wezterm.log_warn(
		"workspace-picker: Startup restore created "
			.. result.restored
			.. " workspaces, failed for: "
			.. table.concat(result.failed, ", ")
	)
end

---@param opts? WorkspacePickerConfig
---@return WorkspacePicker
function M.setup(opts)
	Config.setup(M.restore_workspaces_on_gui_startup, opts)
	return M
end

---@param window Window
---@param pane Pane
function M.show_workspace_selector(window, pane)
	local config = Config.get()
	local colors = config.colors
	local labels = config.labels
	local current = wezterm.mux.get_active_workspace()

	---@type WorkspacePickerChoice[]
	local choices = {
		{
			id = "save-all",
			label = "s  Save all workspaces",
		},
		{
			id = "delete-saved-workspace",
			label = "d  Delete saved workspace",
		},
		{
			id = "create-workspace",
			label = "c  Create new workspace",
		},
		{
			id = "rename-workspace",
			label = "e  Rename current workspace",
		},
	}

	local workspace_choices = {}
	local default_workspace_choice

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

		local choice = {
			id = "ws:" .. name,
			label = label,
		}

		if name == "default" then
			default_workspace_choice = choice
		else
			table.insert(workspace_choices, choice)
		end
	end

	if default_workspace_choice then
		table.insert(workspace_choices, 1, default_workspace_choice)
	end

	for _, choice in ipairs(workspace_choices) do
		table.insert(choices, choice)
	end

	local zoxide_dirs = get_zoxide_directories()
	if #zoxide_dirs > 0 then
		table.insert(choices, {
			id = "separator",
			label = "─────────────────────────────────────────────────────────",
		})

		for _, directory in ipairs(zoxide_dirs) do
			local dir_name = directory:match("([^/]+)$")
			local label = wezterm.format({
				{ Foreground = { Color = colors.zoxide_prefix } },
				{ Text = labels.zoxide },
				{ Foreground = { Color = colors.text } },
				{ Text = " " .. dir_name .. " " },
				{ Foreground = { Color = colors.path } },
				{ Text = "(" .. directory .. ")" },
			})
			table.insert(choices, {
				id = "zoxide:" .. directory,
				label = label,
			})
		end
	end

	UI.show_input_selector(window, pane, {
		title = "(wezterm) Select workspace",
		choices = choices,
		description = "(wezterm) Select workspace or directory: ['/': search]",
		fuzzy_description = "(wezterm) Select workspace or directory: ",
		on_select = function(win, current_pane, id)
			if not id then
				return
			end

			if id == "save-all" then
				win:perform_action(M.save_all_workspaces(), current_pane)
				return
			end

			if id == "delete-saved-workspace" then
				M.show_delete_menu(win, current_pane)
				return
			end

			if id == "create-workspace" then
				win:perform_action(M.create_workspace_manually(), current_pane)
				return
			end

			if id == "rename-workspace" then
				win:perform_action(M.rename_workspace(), current_pane)
				return
			end

			if id == "separator" then
				wezterm.log_info("Selection canceled or separator clicked")
				return
			end

			if id:match("^ws:") then
				local workspace_name = id:gsub("^ws:", "")
				win:perform_action(act.SwitchToWorkspace({ name = workspace_name }), current_pane)
			elseif id:match("^zoxide:") then
				local directory = id:gsub("^zoxide:", "")
				local home = wezterm.home_dir
				if home and home ~= "" then
					directory = directory:gsub("^~", home)
				end

				local workspace_name = directory:match("([^/]+)$")
				win:perform_action(
					act.SwitchToWorkspace({
						name = workspace_name,
						spawn = {
							cwd = directory,
						},
					}),
					current_pane
				)
			end
		end,
	})
end

---@return Action
function M.rename_workspace()
	return act.PromptInputLine({
		description = "(wezterm) Rename workspace title: ",
		action = wezterm.action_callback(function(_, _, line)
			if line then
				wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
			end
		end),
	})
end

---@return Action
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

---@return Action
function M.save_workspace()
	return act.PromptInputLine({
		description = "(wezterm) Save workspace as: ",
		action = wezterm.action_callback(function(window, pane, line)
			if line then
				local active_workspace = wezterm.mux.get_active_workspace()
				local save_state = {
					name = active_workspace,
					path = Cwd.get_workspace_path(active_workspace, pane),
					timestamp = os.time(),
				}
				local ok = State.save_workspace_state(line, save_state)
				if ok then
					wezterm.log_info("workspace-picker: Saved workspace as '" .. line .. "'")
					UI.notify(window, "Workspace Saved", "Saved workspace as '" .. line .. "'.")
				else
					wezterm.log_warn("workspace-picker: Failed to save workspace '" .. line .. "'")
					UI.notify(window, "Workspace Save Failed", "Failed to save workspace as '" .. line .. "'.")
				end
			end
		end),
	})
end

---@return Action
function M.save_all_workspaces()
	return wezterm.action_callback(function(window, pane)
		local workspace_names = wezterm.mux.get_workspace_names()
		local active_workspace = wezterm.mux.get_active_workspace()
		table.sort(workspace_names)

		local saved = 0
		local failed = {}
		local timestamp = os.time()

		for _, workspace_name in ipairs(workspace_names) do
			local save_state = {
				name = workspace_name,
				path = Cwd.get_workspace_path(workspace_name, workspace_name == active_workspace and pane or nil),
				timestamp = timestamp,
			}

			if State.save_workspace_state(workspace_name, save_state) then
				saved = saved + 1
			else
				table.insert(failed, workspace_name)
			end
		end

		if #failed == 0 then
			wezterm.log_info("workspace-picker: Saved " .. saved .. " workspaces")
			UI.notify(window, "Workspaces Saved", "Saved " .. saved .. " workspaces successfully.")
		else
			wezterm.log_warn(
				"workspace-picker: Saved " .. saved .. " workspaces, failed for: " .. table.concat(failed, ", ")
			)
			UI.notify(
				window,
				"Workspace Save Completed With Errors",
				"Saved " .. saved .. " workspaces, failed for: " .. table.concat(failed, ", ")
			)
		end
	end)
end

---@return Action
function M.restore_all_workspaces()
	return wezterm.action_callback(function(window, _)
		local result = State.restore_saved_workspaces()
		if result.found == 0 then
			UI.notify(window, "No Saved Workspaces", "No saved workspaces found. Open the picker, then press s.")
			return
		end

		if #result.failed == 0 then
			wezterm.log_info(
				"workspace-picker: Restored "
					.. result.restored
					.. " workspaces"
					.. (result.skipped > 0 and " (" .. result.skipped .. " already existed)" or "")
			)
			UI.notify(
				window,
				"Workspaces Restored",
				"Restored "
					.. result.restored
					.. " workspaces"
					.. (result.skipped > 0 and " (" .. result.skipped .. " already existed)" or "")
					.. "."
			)
		else
			wezterm.log_warn(
				"workspace-picker: Restored "
					.. result.restored
					.. " workspaces, failed for: "
					.. table.concat(result.failed, ", ")
			)
			UI.notify(
				window,
				"Workspace Restore Completed With Errors",
				"Restored " .. result.restored .. " workspaces, failed for: " .. table.concat(result.failed, ", ")
			)
		end
	end)
end

---@param window Window
---@param pane Pane
function M.show_restore_menu(window, pane)
	local saved = State.get_saved_workspaces()
	table.sort(saved)

	if #saved == 0 then
		UI.notify(window, "No Saved Workspaces", "No saved workspaces found. Open the picker, then press s.")
		return
	end

	---@type WorkspacePickerChoice[]
	local choices = {}

	for _, name in ipairs(saved) do
		table.insert(choices, {
			id = "restore:" .. name,
			label = UI.format_saved_workspace_label(name, State.load_workspace_state(name)),
		})
	end

	UI.show_input_selector(window, pane, {
		title = "(wezterm) Restore workspace",
		choices = choices,
		description = "(wezterm) Restore a saved workspace: ",
		fuzzy_description = "(wezterm) Restore workspace: ",
		on_select = function(win, current_pane, id)
			if not id then
				return
			end

			local saved_name = id:gsub("^restore:", "")
			local saved_state = State.load_workspace_state(saved_name)
			local workspace_name = saved_name

			if saved_state then
				local existing = State.get_restored_workspaces()
				local switch_args = {
					name = workspace_name,
				}

				if not existing[workspace_name] and type(saved_state.path) == "string" and saved_state.path ~= "" then
					switch_args.spawn = {
						cwd = saved_state.path,
					}
				end

				win:perform_action(act.SwitchToWorkspace(switch_args), current_pane)
				wezterm.log_info("workspace-picker: Restored workspace '" .. workspace_name .. "'")
				UI.notify(win, "Workspace Restored", "Restored workspace '" .. workspace_name .. "'.")
			else
				wezterm.log_warn("workspace-picker: Failed to load workspace state for '" .. workspace_name .. "'")
				UI.notify(
					win,
					"Workspace Restore Failed",
					"Failed to load workspace state for '" .. workspace_name .. "'."
				)
			end
		end,
	})
end

---@param window Window
---@param pane Pane
function M.show_delete_menu(window, pane)
	local saved = State.get_saved_workspaces()
	table.sort(saved)

	if #saved == 0 then
		UI.notify(window, "No Saved Workspaces", "No saved workspaces found. Open the picker, then press s.")
		return
	end

	---@type WorkspacePickerChoice[]
	local choices = {}

	for _, name in ipairs(saved) do
		table.insert(choices, {
			id = "delete:" .. name,
			label = UI.format_saved_workspace_label(name, State.load_workspace_state(name)),
		})
	end

	UI.show_input_selector(window, pane, {
		title = "(wezterm) Delete saved workspace",
		choices = choices,
		description = "(wezterm) Delete a saved workspace: ",
		fuzzy_description = "(wezterm) Delete saved workspace: ",
		on_select = function(win, _, id)
			if not id then
				return
			end

			local saved_name = id:gsub("^delete:", "")
			if State.delete_workspace_state(saved_name) then
				wezterm.log_info("workspace-picker: Deleted saved workspace '" .. saved_name .. "'")
				UI.notify(win, "Workspace Deleted", "Deleted saved workspace '" .. saved_name .. "'.")
			else
				wezterm.log_warn("workspace-picker: Failed to delete saved workspace '" .. saved_name .. "'")
				UI.notify(win, "Workspace Delete Failed", "Failed to delete saved workspace '" .. saved_name .. "'.")
			end
		end,
	})
end

---@param config Config
---@param opts? WorkspacePickerConfig
---@return Config
function M.apply_to_config(config, opts)
	local cfg = Config.apply(M.restore_workspaces_on_gui_startup, opts)

	if not config.keys then
		config.keys = {}
	end

	if cfg.activate_keytable then
		local filtered_keys = {}
		for _, binding in ipairs(config.keys) do
			if binding.mods ~= cfg.activate_keytable.mods or binding.key ~= cfg.activate_keytable.key then
				table.insert(filtered_keys, binding)
			end
		end
		config.keys = filtered_keys

		table.insert(config.keys, {
			mods = cfg.activate_keytable.mods,
			key = cfg.activate_keytable.key,
			action = wezterm.action_callback(function(window, pane)
				M.show_workspace_selector(window, pane)
			end),
		})
	end

	return config
end

function M.get_data_dir()
	return State.get_data_dir()
end

return M
