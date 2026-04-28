---@meta

local wezterm = require("wezterm")

local separator = wezterm.target_triple:match("windows") and "\\" or "/"
local source = debug.getinfo(1, "S").source
local script_path = source:gsub("^@", "")
local root_path = script_path:match("^(.*" .. separator .. ")")

package.path = package.path
	.. ";"
	.. root_path
	.. "?.lua"
	.. ";"
	.. root_path
	.. "?/init.lua"

return require("workspace_picker")
