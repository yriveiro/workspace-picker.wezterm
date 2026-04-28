# workspace-picker.wezterm

WezTerm workspace switcher with [zoxide](https://github.com/ajeetdsouza/zoxide) integration.

## Features

- 🚀 **Quick workspace switching** - Fuzzy search through existing workspaces
- 📂 **Zoxide integration** - Create workspaces from your frequently accessed directories
- 🎨 **Customizable colors** - Match your terminal theme
- 🏷️ **Customizable labels** - Personalize workspace and directory labels
- ⌨️ **Flexible keybindings** - Configure or disable default shortcuts
- 🔍 **Fuzzy search** - Type `/` to search workspaces and directories

## Requirements

- [WezTerm](https://wezfurlong.org/wezterm/) (latest version recommended)
- [zoxide](https://github.com/ajeetdsouza/zoxide) (optional, for directory integration)

## Installation

Add this to your `wezterm.lua`:

```lua
local wezterm = require("wezterm")
local workspace_picker = wezterm.plugin.require("https://github.com/isseii10/workspace-picker.wezterm")

local config = wezterm.config_builder()

-- Apply default keybindings
workspace_picker.apply_to_config(config)

return config
```

## Usage

### Default Keybindings

| Key | Action |
|-----|--------|
| `LEADER` + `w` | Open workspace picker |

### In the Picker

- `w`: Show workspace selector
- `s`: Save all workspaces
- `r`: Restore all saved workspaces
- `c`: Create new workspace manually
- `e`: Rename current workspace
- `q` or `Esc`: Close the picker
- Use `↑`/`↓` or `j`/`k` to navigate
- Press `/` to start fuzzy search
- Press `Enter` to select

> **Note**: `LEADER` key must be configured in your WezTerm config. See [WezTerm Leader Key docs](https://wezfurlong.org/wezterm/config/keys.html#leader-key).

### Screenshots

**Normal Mode:**
<br>
<img src="images/picker-norm.png" alt="Normal Mode" width="600">

**Fuzzy Search Mode:**
<br>
<img src="images/picker-search.png" alt="Fuzzy Mode" width="600">

## Configuration

### Custom Setup

```lua
local workspace_picker = wezterm.plugin.require("https://github.com/isseii10/workspace-picker.wezterm")

-- Initialize with custom settings
workspace_picker.setup({
	-- Path to zoxide executable
	zoxide_path = "/opt/homebrew/bin/zoxide",

	-- Custom colors (Tokyo Night theme)
	colors = {
		workspace_prefix = "#9ece6a", -- Green for workspace label
		zoxide_prefix = "#f7768e",    -- Red for zoxide label
		current_indicator = "#9ece6a", -- Green for current workspace
		text = "#c8d0e0",             -- Light gray for text
		path = "#565f89",             -- Dark gray for paths
	},

	-- Custom labels
	labels = {
		workspace = "[Workspace]", -- Label for workspace entries
		zoxide = "[Zoxide]", -- Label for zoxide entries
		current = "<- current", -- Indicator for current workspace
	},
	activate_keytable = { mods = "LEADER", key = "w" },

})

-- Apply to config
workspace_picker.apply_to_config(config)
```

### Disable Default Keybindings

If you want to set up keybindings manually:

```lua
local workspace_picker = wezterm.plugin.require("https://github.com/isseii10/workspace-picker.wezterm")

workspace_picker.setup({
	activate_keytable = false,
})

-- Set up your own keybindings
config.keys = {
	{
		mods = "CMD",
		key = "p",
		action = wezterm.action_callback(function(win, pane)
			workspace_picker.show_workspace_selector(win, pane)
		end),
	},
}
```

### Using Individual Functions

You can also use the plugin's functions directly:

```lua
local workspace_picker = wezterm.plugin.require("https://github.com/isseii10/workspace-picker.wezterm")

workspace_picker.setup({
	activate_keytable = false,
})

config.keys = {
	{
		key = "p",
		mods = "LEADER",
		action = wezterm.action_callback(function(win, pane)
			workspace_picker.show_workspace_selector(win, pane)
		end),
	},
	{
		key = "c",
		mods = "LEADER",
		action = workspace_picker.create_workspace_manually(),
	},
	{
		key = "e",
		mods = "LEADER",
		action = workspace_picker.rename_workspace(),
	},
}
```

## Configuration Examples

### Different Color Schemes

**Catppuccin Mocha:**
```lua
workspace_picker.setup({
	colors = {
		workspace_prefix = "#a6e3a1",
		zoxide_prefix = "#f38ba8",
		current_indicator = "#a6e3a1",
		text = "#cdd6f4",
		path = "#6c7086",
	},
})
```

**Gruvbox:**
```lua
workspace_picker.setup({
	colors = {
		workspace_prefix = "#b8bb26",
		zoxide_prefix = "#fb4934",
		current_indicator = "#b8bb26",
		text = "#ebdbb2",
		path = "#928374",
	},
})
```

### Custom Labels

**Using Emojis:**
```lua
workspace_picker.setup({
	labels = {
		workspace = "🏢",
		zoxide = "📁",
		current = "👈",
	},
})
```

**Shorter Labels:**
```lua
workspace_picker.setup({
	labels = {
		workspace = "[WS]",
		zoxide = "[DIR]",
		current = "●",
	},
})
```

### Custom Zoxide Path

If zoxide is installed in a non-standard location:

```lua
workspace_picker.setup({
	zoxide_path = "/usr/local/bin/zoxide",
})
```

## How It Works

1. **Workspace List**: Shows all existing WezTerm workspaces (current workspace is highlighted)
2. **Zoxide Integration**: Lists frequently accessed directories from zoxide
3. **Workspace Creation**: Selecting a zoxide directory creates a new workspace with that directory as the working directory
4. **Fuzzy Search**: Type `/` in the picker to filter workspaces and directories

## Troubleshooting

### Zoxide directories not showing

Make sure zoxide is:
1. Installed: `brew install zoxide` (macOS) or follow [installation guide](https://github.com/ajeetdsouza/zoxide#installation)
2. Initialized in your shell: Add `eval "$(zoxide init zsh)"` to `.zshrc` (or equivalent for your shell)
3. Path is correct in the config (default: `/opt/homebrew/bin/zoxide`)

### Colors not working

Ensure your WezTerm version supports color customization in InputSelector. Try updating to the latest version.

## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests

## License

MIT License - see LICENSE file for details

## Acknowledgments

- [WezTerm](https://wezfurlong.org/wezterm/) - The amazing terminal emulator
- [zoxide](https://github.com/ajeetdsouza/zoxide) - Smart directory jumper
- Inspired by [smart_workspace_switcher.wezterm](https://github.com/MLFlexer/smart_workspace_switcher.wezterm)
