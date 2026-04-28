---@class WorkspacePickerColors
---@field current_indicator? string
---@field path? string
---@field text? string
---@field workspace_prefix? string
---@field zoxide_prefix? string

---@class (exact) WorkspacePickerResolvedColors
---@field current_indicator string
---@field path string
---@field text string
---@field workspace_prefix string
---@field zoxide_prefix string

---@class WorkspacePickerLabels
---@field current? string
---@field workspace? string
---@field zoxide? string

---@class (exact) WorkspacePickerResolvedLabels
---@field current string
---@field workspace string
---@field zoxide string

---@class WorkspacePickerKeybind
---@field key string
---@field mods string

---@class WorkspacePickerConfig
---@field activate_keytable? WorkspacePickerKeybind|false
---@field colors? WorkspacePickerColors
---@field labels? WorkspacePickerLabels
---@field restore_on_gui_startup? boolean
---@field zoxide_path? string

---@class (exact) WorkspacePickerResolvedConfig
---@field activate_keytable WorkspacePickerKeybind|false
---@field colors WorkspacePickerResolvedColors
---@field labels WorkspacePickerResolvedLabels
---@field restore_on_gui_startup boolean
---@field zoxide_path string

---@class WorkspacePickerChoice
---@field id string
---@field label string

---@class WorkspacePickerSavedState
---@field cwd? string
---@field timestamp? integer

---@alias WorkspacePickerSavedWorkspaceIndex table<string, WorkspacePickerSavedState>

---@class WorkspacePickerRestoreResult
---@field failed string[]
---@field first_restored_workspace string|nil
---@field found integer
---@field restored integer
---@field skipped integer

---@class WorkspacePickerRestoreOptions
---@field cmd? SpawnCommand

---@class WorkspacePickerSpawnWindowArgs: SpawnCommand
---@field height? integer
---@field width? integer
---@field workspace string

---@class WorkspacePickerGlobalState
---@field restore_attempted_on_gui_startup? boolean

---@class WorkspacePickerInputSelectorOpts
---@field choices WorkspacePickerChoice[]
---@field description string
---@field fuzzy_description string
---@field on_select CallbackInputSelector
---@field title string

---@class WorkspacePicker
---@field apply_to_config fun(config: Config, opts?: WorkspacePickerConfig): Config
---@field create_workspace_manually fun(): Action
---@field get_data_dir fun(): string
---@field rename_workspace fun(): Action
---@field restore_all_workspaces fun(): Action
---@field restore_workspaces_on_gui_startup fun(cmd?: SpawnCommand)
---@field save_all_workspaces fun(): Action
---@field save_workspace fun(): Action
---@field setup fun(opts?: WorkspacePickerConfig): WorkspacePicker
---@field show_delete_menu fun(window: Window, pane: Pane)
---@field show_restore_menu fun(window: Window, pane: Pane)
---@field show_workspace_selector fun(window: Window, pane: Pane)

return {}
