@tool
extends EditorPlugin

## Roster Core Plugin.
## This plugin provides shared scripts for Tower and Enemy Roster plugins.
## It does not need to be enabled separately if the dependent plugins are active.

const _PRELOAD_SHARED := preload("res://addons/roster_core/shared_config.gd")
const _PRELOAD_SCHEMA := preload("res://addons/roster_core/roster_schema.gd")
const _PRELOAD_PROP := preload("res://addons/roster_core/roster_property.gd")
const _PRELOAD_MGR := preload("res://addons/roster_core/roster_data_manager.gd")
const _PRELOAD_BASE := preload("res://addons/roster_core/base_roster_plugin.gd")

func _notification(what: int) -> void:
	pass
