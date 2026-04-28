# Configuration Guide

Detailed configuration options and API reference for workspace-picker.wezterm.

## Table of Contents

- [Quick Reference](#quick-reference)
- [API Reference](#api-reference)
- [Configuration Options](#configuration-options)
- [Advanced Examples](#advanced-examples)

> [!TIP]
> Start with [`README.md`](../README.md) for installation and workflow overview, then use this guide for the full API and option reference.

## Quick Reference

### API Summary

| Function | Returns | Purpose |
| --- | --- | --- |
| `setup(opts)` | plugin module | Set the active plugin configuration |
| `apply_to_config(config, opts)` | config table | Apply config and add the default picker keybinding |
| `show_workspace_selector(window, pane)` | `nil` | Open the main picker UI |
| `save_workspace()` | WezTerm action | Save the active workspace under a chosen name |
| `save_all_workspaces()` | WezTerm action | Save every live workspace |
| `show_restore_menu(window, pane)` | `nil` | Open the saved-workspace restore picker |
| `show_delete_menu(window, pane)` | `nil` | Delete saved workspace entries from disk |
| `restore_all_workspaces()` | WezTerm action | Restore all saved workspaces immediately |
| `restore_workspaces_on_gui_startup(cmd)` | `nil` | Startup restore handler for `gui-startup` |
| `get_data_dir()` | `string` | Return the saved state directory |

### Config Summary

| Option | Type | Default |
| --- | --- | --- |
| `zoxide_path` | `string` | `"/opt/homebrew/bin/zoxide"` |
| `colors` | `table` | Built-in Tokyo Night-inspired palette |
| `labels` | `table` | `workspace`, `zoxide`, and `current` labels |
| `activate_keytable` | `table` or `false` | `{ mods = "LEADER", key = "w" }` |
| `restore_on_gui_startup` | `boolean` | `true` |

## API Reference

### `setup(opts)`

Initialize the plugin with custom configuration.

**Parameters:**
- `opts` (table, optional): Configuration options

**Returns:** Plugin module (for chaining)

**Example:**
```lua
workspace_picker.setup({
	zoxide_path = "/usr/local/bin/zoxide",
	colors = { workspace_prefix = "#a6e3a1" },
})
```

---

### `show_workspace_selector(window, pane)`

Display the workspace picker UI.

**Parameters:**
- `window` (object): WezTerm window object
- `pane` (object): WezTerm pane object

**Usage:**
```lua
config.keys = {
	{
		key = "w",
		mods = "LEADER",
		action = wezterm.action_callback(function(win, pane)
			workspace_picker.show_workspace_selector(win, pane)
		end),
	},
}
```

---

### `rename_workspace()`

Returns an action to rename the current workspace.

**Returns:** WezTerm action

**Usage:**
```lua
config.keys = {
	{
		key = "r",
		mods = "LEADER",
		action = workspace_picker.rename_workspace(),
	},
}
```

---

### `create_workspace_manually()`

Returns an action to create a new workspace with a custom name.

**Returns:** WezTerm action

**Usage:**
```lua
config.keys = {
	{
		key = "n",
		mods = "LEADER",
		action = workspace_picker.create_workspace_manually(),
	},
}
```

---

### `save_workspace()`

Returns an action that prompts for a saved workspace name and persists the current workspace state.

The saved state includes the working directory used when restoring that workspace later.

**Returns:** WezTerm action

**Usage:**
```lua
config.keys = {
	{
		key = "s",
		mods = "LEADER",
		action = workspace_picker.save_workspace(),
	},
}
```

---

### `save_all_workspaces()`

Returns an action that saves every live workspace.

**Returns:** WezTerm action

**Usage:**
```lua
config.keys = {
	{
		key = "S",
		mods = "LEADER|SHIFT",
		action = workspace_picker.save_all_workspaces(),
	},
}
```

---

### `show_restore_menu(window, pane)`

Display the saved-workspace restore UI.

**Parameters:**
- `window` (object): WezTerm window object
- `pane` (object): WezTerm pane object

**Usage:**
```lua
config.keys = {
	{
		key = "R",
		mods = "LEADER|SHIFT",
		action = wezterm.action_callback(function(win, pane)
			workspace_picker.show_restore_menu(win, pane)
		end),
	},
}
```

---

### `show_delete_menu(window, pane)`

Display the saved-workspace delete UI.

> [!IMPORTANT]
> This deletes saved workspace entries from disk. It does not close or delete live WezTerm workspaces.

**Parameters:**
- `window` (object): WezTerm window object
- `pane` (object): WezTerm pane object

**Usage:**
```lua
config.keys = {
	{
		key = "D",
		mods = "LEADER|SHIFT",
		action = wezterm.action_callback(function(win, pane)
			workspace_picker.show_delete_menu(win, pane)
		end),
	},
}
```

---

### `restore_all_workspaces()`

Returns an action that restores every saved workspace immediately.

This is mainly useful for manual restore flows. If `restore_on_gui_startup = true`, startup restore is handled automatically.

**Returns:** WezTerm action

**Usage:**
```lua
config.keys = {
	{
		key = "A",
		mods = "LEADER|SHIFT",
		action = workspace_picker.restore_all_workspaces(),
	},
}
```

---

### `restore_workspaces_on_gui_startup(cmd)`

Restore saved workspaces during the `gui-startup` event.

> [!NOTE]
> You usually do not call this directly. It is registered automatically when `restore_on_gui_startup = true`.

**Parameters:**
- `cmd` (table, optional): The `SpawnCommand` passed by WezTerm's `gui-startup` event

---

### `apply_to_config(config, opts)`

Apply plugin configuration and the default picker keybinding to a WezTerm config.

> [!TIP]
> Use either `setup(opts)` followed by `apply_to_config(config)`, or pass `opts` directly to `apply_to_config(config, opts)` if you prefer a single entrypoint.

If `opts` is provided here, those options become the active plugin configuration.

**Parameters:**
- `config` (table): WezTerm config object
- `opts` (table, optional): Configuration overrides (uses `setup()` config if not provided)

**Returns:** Modified config object

**Usage:**
```lua
-- Using setup() config
workspace_picker.setup({ ... })
workspace_picker.apply_to_config(config)

-- Or apply config directly here
workspace_picker.apply_to_config(config, {
	activate_keytable = { mods = "CMD", key = "p" },
	restore_on_gui_startup = false,
})
```

---

### `get_data_dir()`

Return the directory where saved workspace state files are stored.

**Returns:** string

**Usage:**
```lua
local data_dir = workspace_picker.get_data_dir()
wezterm.log_info("workspace-picker data dir: " .. data_dir)
```

## Configuration Options

### `zoxide_path`

**Type:** string
**Default:** `"/opt/homebrew/bin/zoxide"`

Path to the zoxide executable. Adjust based on your installation:

```lua
-- macOS Homebrew (Apple Silicon)
zoxide_path = "/opt/homebrew/bin/zoxide"

-- macOS Homebrew (Intel)
zoxide_path = "/usr/local/bin/zoxide"

-- Linux (system install)
zoxide_path = "/usr/bin/zoxide"

-- Linux (user install)
zoxide_path = os.getenv("HOME") .. "/.local/bin/zoxide"
```

---

### `colors`

**Type:** table
**Default:**
```lua
{
	workspace_prefix = "#9ece6a",
	zoxide_prefix = "#f7768e",
	current_indicator = "#9ece6a",
	text = "#c8d0e0",
	path = "#565f89",
}
```

Color scheme for the picker UI:

- `workspace_prefix`: Color for "[Workspace]" label
- `zoxide_prefix`: Color for "[Zoxide]" label
- `current_indicator`: Color for "<- current" indicator
- `text`: Color for main text (workspace/directory names)
- `path`: Color for directory paths in zoxide entries

**Popular Theme Examples:**

```lua
-- Tokyo Night
colors = {
	workspace_prefix = "#9ece6a",
	zoxide_prefix = "#f7768e",
	current_indicator = "#9ece6a",
	text = "#c8d0e0",
	path = "#565f89",
}

-- Catppuccin Mocha
colors = {
	workspace_prefix = "#a6e3a1",
	zoxide_prefix = "#f38ba8",
	current_indicator = "#a6e3a1",
	text = "#cdd6f4",
	path = "#6c7086",
}

-- Gruvbox Dark
colors = {
	workspace_prefix = "#b8bb26",
	zoxide_prefix = "#fb4934",
	current_indicator = "#b8bb26",
	text = "#ebdbb2",
	path = "#928374",
}

-- Nord
colors = {
	workspace_prefix = "#a3be8c",
	zoxide_prefix = "#bf616a",
	current_indicator = "#a3be8c",
	text = "#e5e9f0",
	path = "#4c566a",
}

-- Dracula
colors = {
	workspace_prefix = "#50fa7b",
	zoxide_prefix = "#ff5555",
	current_indicator = "#50fa7b",
	text = "#f8f8f2",
	path = "#6272a4",
}
```

---

### `labels`

**Type:** table
**Default:**
```lua
{
	workspace = "[Workspace]",
	zoxide = "[Zoxide]",
	current = "<- current",
}
```

Controls the labels shown in the picker UI:

- `workspace`: Prefix for live workspace entries
- `zoxide`: Prefix for zoxide directory entries
- `current`: Suffix shown next to the active workspace

**Examples:**

```lua
labels = {
	workspace = "[WS]",
	zoxide = "[DIR]",
	current = "*",
}
```

---

### `activate_keytable`

**Type:** table or boolean
**Default:**
```lua
{
	mods = "LEADER",
	key = "w",
}
```

Controls the key used to open the workspace picker. Set to `false` to disable automatic activation.

**Options:**
- `mods`: Modifier keys for the opener
- `key`: Key to press

**Examples:**

```lua
-- Use CMD instead of LEADER
activate_keytable = { mods = "CMD", key = "p" }

-- Disable automatic activation
activate_keytable = false
```

---

### `restore_on_gui_startup`

**Type:** boolean
**Default:** `true`

Controls whether saved workspaces are restored automatically when WezTerm starts via the `gui-startup` event.

Restore only runs once per GUI startup. Opening a new window later does not trigger another restore, and workspaces that already have live windows are skipped.

**Examples:**

```lua
-- Disable automatic restore on startup
restore_on_gui_startup = false

-- Keep the default startup restore behavior
restore_on_gui_startup = true
```

## Advanced Examples

### Complete WezTerm Config Integration

```lua
local wezterm = require("wezterm")
local workspace_picker = wezterm.plugin.require("https://github.com/yriveiro/workspace-picker.wezterm")

local config = wezterm.config_builder()

-- Basic WezTerm settings
config.color_scheme = "Tokyo Night"
config.font = wezterm.font("JetBrains Mono")
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }

-- Setup workspace picker with Tokyo Night colors
workspace_picker.setup({
	zoxide_path = "/opt/homebrew/bin/zoxide",
	restore_on_gui_startup = true,
	colors = {
		workspace_prefix = "#9ece6a",
		zoxide_prefix = "#f7768e",
		current_indicator = "#9ece6a",
		text = "#c8d0e0",
		path = "#565f89",
	},
	activate_keytable = { mods = "LEADER", key = "w" },
})

-- Apply plugin keybindings
workspace_picker.apply_to_config(config)

-- Add your other keybindings
table.insert(config.keys, {
	key = "c",
	mods = "LEADER",
	action = wezterm.action.SpawnTab("CurrentPaneDomain"),
})

return config
```

### Manual Keybinding Setup

```lua
local wezterm = require("wezterm")
local workspace_picker = wezterm.plugin.require("https://github.com/yriveiro/workspace-picker.wezterm")

local config = wezterm.config_builder()

-- Setup without automatic keybindings
workspace_picker.setup({
	activate_keytable = false,
	restore_on_gui_startup = false,
	colors = { workspace_prefix = "#a6e3a1" },
})

-- Define custom keybindings
config.keys = {
	-- Use CMD+P for picker (macOS style)
	{
		key = "p",
		mods = "CMD",
		action = wezterm.action_callback(function(win, pane)
			workspace_picker.show_workspace_selector(win, pane)
		end),
	},
	-- Use CTRL+ALT+W for manual creation
	{
		key = "w",
		mods = "CTRL|ALT",
		action = workspace_picker.create_workspace_manually(),
	},
	-- No rename keybinding
}

return config
```

### Multi-Platform Configuration

```lua
local wezterm = require("wezterm")
local workspace_picker = wezterm.plugin.require("https://github.com/yriveiro/workspace-picker.wezterm")

local config = wezterm.config_builder()

-- Detect platform and set zoxide path
local zoxide_path
if wezterm.target_triple:find("darwin") then
	-- macOS
	if wezterm.target_triple:find("aarch64") then
		zoxide_path = "/opt/homebrew/bin/zoxide" -- Apple Silicon
	else
		zoxide_path = "/usr/local/bin/zoxide" -- Intel
	end
elseif wezterm.target_triple:find("linux") then
	-- Linux
	zoxide_path = "/usr/bin/zoxide"
elseif wezterm.target_triple:find("windows") then
	-- Windows
	zoxide_path = "zoxide.exe" -- Assumes it's in PATH
end

workspace_picker.setup({
	zoxide_path = zoxide_path,
	restore_on_gui_startup = true,
})

workspace_picker.apply_to_config(config)

return config
```

### Custom Workspace Labels

For advanced customization, you can fork the plugin and modify the label format in `show_workspace_selector()`:

```lua
-- In plugin/workspace_picker/init.lua, modify the workspace label format:
local label = wezterm.format({
	{ Foreground = { Color = colors.workspace_prefix } },
	{ Text = "🚀 " }, -- Add emoji
	{ Foreground = { Color = colors.text } },
	{ Text = name },
	{ Foreground = { Color = colors.path } },
	{ Text = " (" .. #panes .. " panes)" }, -- Add pane count
})
```

Saved workspace labels for the restore/delete menus are formatted in `plugin/workspace_picker/ui.lua`.

### Conditional Zoxide Integration

If you want to use the plugin without zoxide:

```lua
workspace_picker.setup({
	zoxide_path = "/nonexistent/zoxide", -- Invalid path
})
```

The plugin will gracefully handle missing zoxide and only show workspace list.

## Tips and Tricks

### Quick Workspace Switching

Set a short timeout for LEADER key for faster access:

```lua
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 500 }
```

### Combining with WezTerm Status Bar

Show current workspace in status bar:

```lua
wezterm.on("update-right-status", function(window, pane)
	local workspace = window:active_workspace()
	window:set_right_status(wezterm.format({
		{ Foreground = { Color = "#9ece6a" } },
		{ Text = "  " .. workspace .. "  " },
	}))
end)
```

### Auto-Initialize Zoxide

Ensure zoxide tracks directory changes in your shell:

```bash
# ~/.zshrc or ~/.bashrc
eval "$(zoxide init zsh)" # or bash
```
