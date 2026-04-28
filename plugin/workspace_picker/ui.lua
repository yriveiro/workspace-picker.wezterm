local wezterm = require("wezterm") ---@type Wezterm
local act = wezterm.action

local M = {}

local selector_alphabet = "srce1234567890abdfghilmnoptuvwxyz"

---@param window Window
---@param title string
---@param body string
function M.notify(window, title, body)
	window:toast_notification(title, body)
end

---@param window Window
---@param pane Pane
---@param opts WorkspacePickerInputSelectorOpts
function M.show_input_selector(window, pane, opts)
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

---@param saved_name string
---@param state WorkspacePickerSavedState|nil
---@return string
function M.format_saved_workspace_label(saved_name, state)
	local details = {}

	if type(state) == "table" and type(state.timestamp) == "number" and state.timestamp > 0 then
		table.insert(details, os.date("%Y-%m-%d %H:%M", state.timestamp))
	end

	if type(state) == "table" and type(state.cwd) == "string" and state.cwd ~= "" then
		table.insert(details, state.cwd)
	end

	local label = {
		{ Text = string.format(" %s ", saved_name) },
	}

	if #details > 0 then
		table.insert(label, { Foreground = { Color = "#565f89" } })
		table.insert(label, { Text = "(" .. table.concat(details, " | ") .. ")" })
	end

	return wezterm.format(label)
end

return M
