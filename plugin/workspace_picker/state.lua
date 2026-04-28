local wezterm = require("wezterm") ---@type Wezterm

---@class WorkspacePickerLoadedChunk
---@return WorkspacePickerSavedState

local Cwd = require("workspace_picker.cwd")

local M = {}

---@return string
function M.get_data_dir()
	local xdg_data = os.getenv("XDG_DATA_HOME")
	if xdg_data and xdg_data ~= "" then
		return xdg_data .. "/workspace-picker"
	end

	return wezterm.home_dir .. "/.local/share/workspace-picker"
end

---@param workspace_name string
---@return string
local function workspace_state_path(workspace_name)
	return M.get_data_dir() .. "/" .. workspace_name .. ".lua"
end

---@return WorkspacePickerGlobalState
function M.get_global_state()
	wezterm.GLOBAL.workspace_picker = wezterm.GLOBAL.workspace_picker or {}
	---@type WorkspacePickerGlobalState
	return wezterm.GLOBAL.workspace_picker
end

---@param state WorkspacePickerSavedState|nil
---@return string
local function serialize_workspace_state(state)
	state = state or {}

	local lines = {
		"return {",
		string.format("  name = %q,", tostring(state.name or "")),
		string.format("  timestamp = %d,", tonumber(state.timestamp) or 0),
	}

	if type(state.path) == "string" and state.path ~= "" then
		table.insert(lines, string.format("  path = %q,", state.path))
	end

	table.insert(lines, "}")

	return table.concat(lines, "\n") .. "\n"
end

---@param file_path string
---@return string|nil
local function read_file_contents(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	if content == "" then
		return nil
	end

	return content
end

---@param content string
---@param file_path string
---@return WorkspacePickerSavedState|nil
local function load_lua_workspace_state(content, file_path)
	local chunk = load(content, "@" .. file_path, "t", {}) ---@type WorkspacePickerLoadedChunk|nil
	if not chunk then
		return nil
	end

	local ok, state = pcall(chunk)
	if not ok or type(state) ~= "table" then
		return nil
	end

	return state
end

---@return boolean
local function ensure_data_dir()
	local data_dir = M.get_data_dir()
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

---@param workspace_name string
---@param state WorkspacePickerSavedState|nil
---@return boolean
function M.save_workspace_state(workspace_name, state)
	if not ensure_data_dir() then
		return false
	end

	local file = io.open(workspace_state_path(workspace_name), "w")
	if not file then
		return false
	end

	local serialized = serialize_workspace_state(state)
	local ok = file:write(serialized)
	file:close()
	return ok ~= nil
end

---@param workspace_name string
---@return WorkspacePickerSavedState|nil
function M.load_workspace_state(workspace_name)
	local file_path = workspace_state_path(workspace_name)
	local content = read_file_contents(file_path)
	if not content then
		return nil
	end

	return load_lua_workspace_state(content, file_path)
end

---@param workspace_name string
---@return boolean
function M.delete_workspace_state(workspace_name)
	local ok, err = os.remove(workspace_state_path(workspace_name))
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

---@return string[]
function M.get_saved_workspaces()
	local data_dir = M.get_data_dir()
	if data_dir == "" then
		return {}
	end

	local workspaces = {}
	local seen = {}

	for _, file in ipairs(wezterm.glob(data_dir .. "/*.lua", data_dir) or {}) do
		local workspace_name = file:match("([^/\\]+)%.lua$")
		if workspace_name and not seen[workspace_name] then
			seen[workspace_name] = true
			table.insert(workspaces, workspace_name)
		end
	end

	return workspaces
end

---@return table<string, boolean>
function M.get_restored_workspaces()
	local restored = {}

	for _, mux_window in ipairs(wezterm.mux.all_windows() or {}) do
		local ok, workspace_name = pcall(function()
			return mux_window:get_workspace()
		end)
		if ok and type(workspace_name) == "string" and workspace_name ~= "" then
			restored[workspace_name] = true
		end
	end

	return restored
end

---@param spawn_args WorkspacePickerSpawnWindowArgs
---@param cmd SpawnCommand|nil
---@return WorkspacePickerSpawnWindowArgs
local function merge_spawn_command(spawn_args, cmd)
	if not cmd then
		return spawn_args
	end

	if cmd.args then
		spawn_args.args = cmd.args
	end

	if not spawn_args.cwd and cmd.cwd then
		spawn_args.cwd = Cwd.cwd_to_path(cmd.cwd) or cmd.cwd
	end

	if cmd.set_environment_variables then
		spawn_args.set_environment_variables = cmd.set_environment_variables
	end

	if cmd.domain then
		spawn_args.domain = cmd.domain
	end

	if cmd.position then
		spawn_args.position = cmd.position
	end

	if cmd.width and cmd.height then
		spawn_args.width = cmd.width
		spawn_args.height = cmd.height
	end

	return spawn_args
end

---@param opts WorkspacePickerRestoreOptions|nil
---@return WorkspacePickerRestoreResult
function M.restore_saved_workspaces(opts)
	opts = opts or {}

	local saved = M.get_saved_workspaces()
	if #saved == 0 then
		return {
			found = 0,
			restored = 0,
			skipped = 0,
			failed = {},
			first_restored_workspace = nil,
		}
	end

	local existing = M.get_restored_workspaces()

	table.sort(saved)

	local restored = 0
	local skipped = 0
	local failed = {}
	local first_restored_workspace
	local startup_cmd_consumed = false

	for _, saved_name in ipairs(saved) do
		local state = M.load_workspace_state(saved_name) or {}
		local workspace_name = saved_name

		if existing[workspace_name] then
			skipped = skipped + 1
		else
			---@type WorkspacePickerSpawnWindowArgs
			local spawn_args = {
				workspace = workspace_name,
			}

			if type(state.path) == "string" and state.path ~= "" then
				spawn_args.cwd = state.path
			end

			if opts.cmd and not startup_cmd_consumed then
				merge_spawn_command(spawn_args, opts.cmd)
			end

			local ok, result = pcall(wezterm.mux.spawn_window, spawn_args)
			if ok then
				restored = restored + 1
				existing[workspace_name] = true
				startup_cmd_consumed = startup_cmd_consumed or opts.cmd ~= nil

				if not first_restored_workspace then
					first_restored_workspace = workspace_name
				end
			else
				table.insert(failed, workspace_name)
				wezterm.log_warn(
					"workspace-picker: Failed to restore workspace '" .. workspace_name .. "': " .. tostring(result)
				)
			end
		end
	end

	if first_restored_workspace then
		pcall(wezterm.mux.set_active_workspace, first_restored_workspace)
	end

	return {
		found = #saved,
		restored = restored,
		skipped = skipped,
		failed = failed,
		first_restored_workspace = first_restored_workspace,
	}
end

return M
